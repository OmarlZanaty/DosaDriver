import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import '../core/theme/app_colors.dart';
import '../services/backend_api.dart';
import '../services/client_ride_api.dart';
import '../widgets/custom_widgets.dart';
import 'client_active_ride_screen.dart';

class ClientBookRideScreen extends StatefulWidget {
  final LatLng? initialPickup;
  final String? preselectedType;
  const ClientBookRideScreen({super.key, this.initialPickup, this.preselectedType});
  @override
  State<ClientBookRideScreen> createState() => _ClientBookRideScreenState();
}

class _ClientBookRideScreenState extends State<ClientBookRideScreen>
    with TickerProviderStateMixin {
  // Controllers
  final _pickupCtrl = TextEditingController();
  final _destCtrl   = TextEditingController();
  final _pickupFocus = FocusNode();
  final _destFocus   = FocusNode();
  GoogleMapController? _mapController;

  // State
  LatLng? _pickupLatLng;
  LatLng? _destLatLng;
  String _selectedType   = 'FAIR_VALUE';
  String _paymentMethod  = 'CASH';
  bool   _loading        = false;
  bool   _submitting     = false;
  bool   _isSearching    = false; // full-screen search mode
  bool   _searchingPickup = true; // which field is active
  Set<Marker>   _markers   = {};
  Set<Polyline> _polylines = {};
  double? _estimatedFare;
  double? _distanceKm;
  int?    _durationMin;

  // Pricing (min/max/average per ride type from Firestore/defaults)
  Map<String, Map<String, double>> _rideTypePricing = {};
  double _offeredPrice = 0; // client's custom offer

  // Autocomplete
  List<Map<String, String>> _suggestions = [];
  Timer? _debounce;
  bool _fetchingSuggestions = false;

  // Animation
  late AnimationController _sheetAnimCtrl;
  late Animation<double> _sheetAnim;
  bool _sheetExpanded = false;

  final _rideApi = ClientRideApi(BackendApi());

  final Map<String, Map<String, dynamic>> _rideTypes = {
    'FAIR_VALUE': {'label': 'اقتصادي',  'emoji': '🚗', 'desc': 'سعر مناسب للجميع', 'color': Color(0xFF43A047)},
    'PREMIUM':    {'label': 'بريميوم',  'emoji': '🚘', 'desc': 'راحة فائقة وأناقة', 'color': Color(0xFF1976D2)},
    'CUTE_CAR':   {'label': 'كيوت كار', 'emoji': '🚙', 'desc': 'أنيق وعملي',        'color': Color(0xFFE91E63)},
    'SCOOTER':    {'label': 'موتوسيكل', 'emoji': '🛵', 'desc': 'سريع وخفيف',        'color': Color(0xFFFF9800)},
  };

  @override
  void initState() {
    super.initState();
    _selectedType = widget.preselectedType ?? 'FAIR_VALUE';

    _sheetAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _sheetAnim = CurvedAnimation(parent: _sheetAnimCtrl, curve: Curves.easeInOut);

    _loadPricing();

    if (widget.initialPickup != null) {
      _pickupLatLng = widget.initialPickup;
      // 🔴 FIX: Reverse geocode the coordinates to get real address
      _reverseGeocode(widget.initialPickup!).then((addr) {
        if (mounted) setState(() => _pickupCtrl.text = addr);
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryGetLocation());
  }

  @override
  void dispose() {
    _pickupCtrl.dispose();
    _destCtrl.dispose();
    _pickupFocus.dispose();
    _destFocus.dispose();
    _mapController?.dispose();
    _sheetAnimCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ─── Pricing ──────────────────────────────────────────────────────────────
  Future<void> _loadPricing() async {
    final defaults = <String, Map<String, double>>{
      'FAIR_VALUE': {'min': 25, 'max': 120, 'average': 60},
      'PREMIUM':    {'min': 50, 'max': 250, 'average': 130},
      'CUTE_CAR':   {'min': 30, 'max': 150, 'average': 80},
      'SCOOTER':    {'min': 15, 'max':  80, 'average': 40},
    };
    try {
      final snap = await FirebaseFirestore.instance
          .collection('rideTypePricing').get();
      if (snap.docs.isEmpty) { if (mounted) setState(() => _rideTypePricing = defaults); return; }
      final pricing = <String, Map<String, double>>{};
      for (final d in snap.docs) {
        final data = d.data();
        pricing[d.id] = {
          'min':     (data['minPrice']     as num?)?.toDouble() ?? 25,
          'max':     (data['maxPrice']     as num?)?.toDouble() ?? 200,
          'average': (data['averagePrice'] as num?)?.toDouble() ?? 80,
        };
      }
      if (mounted) setState(() => _rideTypePricing = pricing);
    } catch (_) {
      if (mounted) setState(() => _rideTypePricing = defaults);
    }
  }

  Map<String, double>? get _selectedTypePricing => _rideTypePricing[_selectedType];

  // ─── Location ────────────────────────────────────────────────────────────
  Future<void> _tryGetLocation() async {
    if (_pickupLatLng != null) return;
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      final addr = await _reverseGeocode(LatLng(pos.latitude, pos.longitude));
      setState(() {
        _pickupLatLng = LatLng(pos.latitude, pos.longitude);
        _pickupCtrl.text = addr;
      });
      _rebuild();
    } catch (_) {}
  }

  Future<String> _reverseGeocode(LatLng pos) async {
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
            '?latlng=${pos.latitude},${pos.longitude}'
            '&key=${AppConfig.placesApiKey}&language=ar',
      );
      final res  = await http.get(uri);
      final data = jsonDecode(res.body);
      if (data['status'] == 'OK') {
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          return results[0]['formatted_address'] as String;
        }
      }
    } catch (_) {}
    return '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
  }

  // ─── Autocomplete ─────────────────────────────────────────────────────────
  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _fetchSuggestions(query));
  }

  Future<void> _fetchSuggestions(String query) async {
    if (_fetchingSuggestions) return;
    _fetchingSuggestions = true;
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
            '?input=${Uri.encodeComponent(query)}'
            '&key=${AppConfig.placesApiKey}&language=ar&components=country:eg',
      );
      final res  = await http.get(uri);
      debugPrint('[Places] status=${res.statusCode} body=${res.body.substring(0, res.body.length.clamp(0, 300))}'); // ADD THIS
      final data = jsonDecode(res.body);
      if (data['status'] == 'OK' && mounted) {
        final preds = data['predictions'] as List;
        setState(() {
          _suggestions = preds.map<Map<String, String>>((p) => {
            'placeId':     p['place_id'] as String,
            'main':        p['structured_formatting']?['main_text'] as String? ?? '',
            'secondary':   p['structured_formatting']?['secondary_text'] as String? ?? '',
            'description': p['description'] as String,
          }).toList();
        });
      }
    } catch (_) {} finally {
      _fetchingSuggestions = false;
    }
  }

  Future<LatLng?> _getPlaceLatLng(String placeId) async {
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
            '?place_id=$placeId&fields=geometry&key=${AppConfig.placesApiKey }',
      );
      final res  = await http.get(uri);
      final data = jsonDecode(res.body);
      if (data['status'] == 'OK') {
        final loc = data['result']['geometry']['location'];
        return LatLng((loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble());
      }
    } catch (_) {}
    return null;
  }

  Future<void> _selectSuggestion(Map<String, String> s) async {
    setState(() { _suggestions = []; _loading = true; });
    final latLng = await _getPlaceLatLng(s['placeId']!);
    if (!mounted) return;
    if (latLng != null) {
      setState(() {
        if (_searchingPickup) {
          _pickupLatLng = latLng;
          _pickupCtrl.text = s['description']!;
        } else {
          _destLatLng = latLng;
          _destCtrl.text = s['description']!;
        }
        _isSearching = false;
        _loading = false;
      });
      _rebuild();
      // Auto-focus dest if pickup was just set
      if (_searchingPickup && _destLatLng == null) {
        Future.delayed(const Duration(milliseconds: 300), _openDestSearch);
      }
    } else {
      setState(() => _loading = false);
    }
  }

  // ─── Search UI ────────────────────────────────────────────────────────────
  void _openSearch(bool isPickup) {
    setState(() {
      _isSearching    = true;
      _searchingPickup = isPickup;
      _suggestions    = [];
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (isPickup) _pickupFocus.requestFocus();
      else          _destFocus.requestFocus();
    });
  }

  void _openDestSearch() => _openSearch(false);

  void _closeSearch() {
    FocusScope.of(context).unfocus();
    setState(() { _isSearching = false; _suggestions = []; });
  }

  // ─── Map ──────────────────────────────────────────────────────────────────
  void _rebuild() {
    final m = <Marker>{};
    if (_pickupLatLng != null) m.add(Marker(
      markerId: const MarkerId('p'),
      position: _pickupLatLng!,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    ));
    if (_destLatLng != null) m.add(Marker(
      markerId: const MarkerId('d'),
      position: _destLatLng!,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    ));
    setState(() => _markers = m);

    if (_pickupLatLng != null && _destLatLng != null) {
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(LatLngBounds(
        southwest: LatLng(
          [_pickupLatLng!.latitude,  _destLatLng!.latitude ].reduce((a,b) => a<b?a:b),
          [_pickupLatLng!.longitude, _destLatLng!.longitude].reduce((a,b) => a<b?a:b),
        ),
        northeast: LatLng(
          [_pickupLatLng!.latitude,  _destLatLng!.latitude ].reduce((a,b) => a>b?a:b),
          [_pickupLatLng!.longitude, _destLatLng!.longitude].reduce((a,b) => a>b?a:b),
        ),
      ), 80));
      _fetchRouteAndFare();
    } else if (_pickupLatLng != null) {
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_pickupLatLng!, 15));
    }
  }

  Future<void> _fetchRouteAndFare() async {
    if (_pickupLatLng == null || _destLatLng == null) return;
    setState(() => _loading = true);
    try {
      final dirUri = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
            '?origin=${_pickupLatLng!.latitude},${_pickupLatLng!.longitude}'
            '&destination=${_destLatLng!.latitude},${_destLatLng!.longitude}'
            '&mode=driving&key=${AppConfig.placesApiKey}',
      );
      final dirRes  = await http.get(dirUri);
      final dirData = jsonDecode(dirRes.body);
      if (dirData['status'] == 'OK') {
        final routes = dirData['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final leg    = routes[0]['legs'][0];
          final distKm = (leg['distance']['value'] as int) / 1000.0;
          final durMin = ((leg['duration']['value'] as int) / 60).ceil();
          final points = _decode(routes[0]['overview_polyline']['points'] as String);
          setState(() {
            _distanceKm  = distKm;
            _durationMin = durMin;
            _polylines   = {Polyline(
              polylineId: const PolylineId('r'),
              color: AppColors.primary,
              width: 5,
              points: points,
            )};
          });
          final fareData = await _rideApi.getFareEstimate(
            type: _selectedType, distanceKm: distKm, durationMin: durMin.toDouble(),
          );
          if (mounted) {
            final fare = (fareData['fare'] as num?)?.toDouble() ?? 0.0;
            final pricing = _rideTypePricing[_selectedType];
            double offered = fare;
            if (pricing != null && fare > 0) {
              offered = offered.clamp(pricing['min']!, pricing['max']!);
            } else if (pricing != null) {
              offered = pricing['average'] ?? 60.0;
            }
            setState(() { _estimatedFare = fare; _offeredPrice = offered; });
          }
        }
      }
    } catch (_) {
      if (mounted) setState(() => _estimatedFare = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<LatLng> _decode(String enc) {
    List<LatLng> p = []; int i = 0, lat = 0, lng = 0;
    while (i < enc.length) {
      int b, s = 0, r = 0;
      do { b = enc.codeUnitAt(i++) - 63; r |= (b & 0x1f) << s; s += 5; } while (b >= 0x20);
      lat += (r & 1) != 0 ? ~(r >> 1) : r >> 1; s = 0; r = 0;
      do { b = enc.codeUnitAt(i++) - 63; r |= (b & 0x1f) << s; s += 5; } while (b >= 0x20);
      lng += (r & 1) != 0 ? ~(r >> 1) : r >> 1;
      p.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return p;
  }

  Future<void> _confirmBooking() async {
    if (_submitting) return;
    if (_pickupLatLng == null || _destLatLng == null) return;
    _submitting = true;
    setState(() => _loading = true);
    try {
      final ride = await _rideApi.createRide(
        pickupLat: _pickupLatLng!.latitude,  pickupLng: _pickupLatLng!.longitude,
        dropLat:   _destLatLng!.latitude,    dropLng:   _destLatLng!.longitude,
        pickupAddr: _pickupCtrl.text,        dropAddr:   _destCtrl.text,
        rideType:   _selectedType,
        distanceKm:  _distanceKm ?? 5.0,
        durationMin: (_durationMin ?? 10).toDouble(),
        paymentMethod: _paymentMethod,
        offeredPrice: _offeredPrice > 0 ? _offeredPrice : null,
      );
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => ClientActiveRideScreen(rideId: ride['id'].toString()),
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
    } finally {
      _submitting = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        // Full-screen map
        GoogleMap(
          initialCameraPosition: CameraPosition(
              target: _pickupLatLng ?? const LatLng(30.0444, 31.2357), zoom: 14),
          markers: _markers,
          polylines: _polylines,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          onMapCreated: (c) { _mapController = c; _rebuild(); },
          onTap: (latlng) async {
            if (_isSearching) { _closeSearch(); return; }
            final addr = await _reverseGeocode(latlng);
            if (!mounted) return;
            setState(() { _destLatLng = latlng; _destCtrl.text = addr; });
            _rebuild();
          },
        ),

        // Top bar with back button + search fields (collapsed)
        if (!_isSearching) _buildTopBar(),

        // Full-screen search overlay
        if (_isSearching) _buildSearchOverlay(),

        // Bottom sheet
        if (!_isSearching) _buildBottomSheet(),

        // Loading overlay
        if (_loading && !_isSearching)
          const Positioned(top: 0, left: 0, right: 0, bottom: 0,
              child: Center(child: CircularProgressIndicator(color: AppColors.primary))),
      ]),
    );
  }

  // ─── Top Bar ──────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16, right: 16,
      child: Column(children: [
        // Search card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0,4))],
          ),
          child: Column(children: [
            // Pickup row
            _SearchFieldTile(
              icon: Icons.circle, iconColor: Colors.green, iconSize: 12,
              text: _pickupCtrl.text.isEmpty ? 'نقطة الانطلاق' : _pickupCtrl.text,
              placeholder: _pickupCtrl.text.isEmpty,
              onTap: () => _openSearch(true),
              trailing: IconButton(
                icon: const Icon(Icons.my_location, size: 18, color: AppColors.primary),
                onPressed: _tryGetLocation,
                padding: EdgeInsets.zero, constraints: const BoxConstraints(),
              ),
            ),
            // Divider with swap button
            Row(children: [
              const SizedBox(width: 48),
              Expanded(child: Divider(height: 1, color: Colors.grey.shade200)),
              GestureDetector(
                onTap: () {
                  setState(() {
                    final tmpLatLng = _pickupLatLng; _pickupLatLng = _destLatLng; _destLatLng = tmpLatLng;
                    final tmpText = _pickupCtrl.text; _pickupCtrl.text = _destCtrl.text; _destCtrl.text = tmpText;
                  });
                  _rebuild();
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                  child: const Icon(Icons.swap_vert, size: 16, color: Colors.grey),
                ),
              ),
              Expanded(child: Divider(height: 1, color: Colors.grey.shade200)),
              const SizedBox(width: 16),
            ]),
            // Destination row
            _SearchFieldTile(
              icon: Icons.location_on, iconColor: AppColors.primary, iconSize: 16,
              text: _destCtrl.text.isEmpty ? 'إلى أين؟' : _destCtrl.text,
              placeholder: _destCtrl.text.isEmpty,
              onTap: () => _openSearch(false),
            ),
          ]),
        ),
      ]),
    );
  }

  // ─── Search Overlay ───────────────────────────────────────────────────────
  Widget _buildSearchOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.white,
        child: SafeArea(
          child: Column(children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _closeSearch,
                ),
                const SizedBox(width: 4),
                Expanded(child: Text(
                  _searchingPickup ? 'نقطة الانطلاق' : 'الوجهة',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                )),
              ]),
            ),
            // Input fields
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(children: [
                  // Pickup
                  _InlineSearchField(
                    controller: _pickupCtrl,
                    focusNode: _pickupFocus,
                    hint: 'نقطة الانطلاق',
                    icon: Icons.circle,
                    iconColor: Colors.green,
                    iconSize: 10,
                    autofocus: _searchingPickup,
                    onChanged: _searchingPickup ? _onSearchChanged : null,
                    onTap: () { setState(() => _searchingPickup = true); },
                    active: _searchingPickup,
                  ),
                  Divider(height: 1, indent: 48, color: Colors.grey.shade200),
                  // Destination
                  _InlineSearchField(
                    controller: _destCtrl,
                    focusNode: _destFocus,
                    hint: 'إلى أين؟',
                    icon: Icons.location_on,
                    iconColor: AppColors.primary,
                    iconSize: 18,
                    autofocus: !_searchingPickup,
                    onChanged: !_searchingPickup ? _onSearchChanged : null,
                    onTap: () { setState(() => _searchingPickup = false); },
                    active: !_searchingPickup,
                  ),
                ]),
              ),
            ),

            // Suggestions list
            if (_suggestions.isNotEmpty)
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, __) => Divider(height: 1, indent: 56, color: Colors.grey.shade100),
                  itemBuilder: (_, i) {
                    final s = _suggestions[i];
                    return ListTile(
                      leading: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                        child: const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
                      ),
                      title: Text(s['main']!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: s['secondary']!.isNotEmpty
                          ? Text(s['secondary']!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))
                          : null,
                      onTap: () => _selectSuggestion(s),
                    );
                  },
                ),
              )
            else
              Expanded(
                child: Column(children: [
                  const SizedBox(height: 16),
                  // Quick suggestions
                  if (_pickupCtrl.text.isEmpty || _destCtrl.text.isEmpty)
                    _buildQuickSuggestions(),
                ]),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _buildQuickSuggestions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('الأماكن الشائعة', style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _QuickItem(icon: Icons.home_outlined, label: 'المنزل', onTap: () {
          if (_searchingPickup) _pickupCtrl.text = 'المنزل';
          else _destCtrl.text = 'المنزل';
          setState(() {});
        }),
        _QuickItem(icon: Icons.work_outline, label: 'العمل', onTap: () {
          if (_searchingPickup) _pickupCtrl.text = 'العمل';
          else _destCtrl.text = 'العمل';
          setState(() {});
        }),
        _QuickItem(icon: Icons.my_location, label: 'موقعي الحالي', onTap: () async {
          await _tryGetLocation();
          if (_searchingPickup && _pickupLatLng != null) _closeSearch();
        }),
      ]),
    );
  }

  // ─── Price offer panel ────────────────────────────────────────────────────
  Widget _buildPriceOfferPanel() {
    final pricing = _selectedTypePricing!;
    final minP    = pricing['min']!;
    final maxP    = pricing['max']!;
    final avgP    = pricing['average'] ?? ((minP + maxP) / 2);
    final offered = _offeredPrice.clamp(minP, maxP);
    final ratio   = avgP > 0 ? offered / avgP : 1.0;

    Color indicatorColor; String indicatorLabel;
    if (ratio < 0.90)       { indicatorColor = Colors.red;    indicatorLabel = 'أقل من المتوسط'; }
    else if (ratio > 1.10)  { indicatorColor = Colors.green;  indicatorLabel = 'أعلى من المتوسط'; }
    else                    { indicatorColor = Colors.orange;  indicatorLabel = 'في المتوسط'; }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(children: [
          const Text('اقترح سعرك',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black54)),
          const SizedBox(height: 10),
          // Large price + +/- buttons
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _PriceStepBtn(
              icon: Icons.remove,
              onTap: () => setState(() =>
                  _offeredPrice = (_offeredPrice - 5).clamp(minP, maxP)),
            ),
            const SizedBox(width: 16),
            Column(children: [
              Text(
                '${offered.toStringAsFixed(0)} ج',
                style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: AppColors.primary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: indicatorColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Text(indicatorLabel, style: TextStyle(fontSize: 11, color: indicatorColor, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(width: 16),
            _PriceStepBtn(
              icon: Icons.add,
              onTap: () => setState(() =>
                  _offeredPrice = (_offeredPrice + 5).clamp(minP, maxP)),
            ),
          ]),
          const SizedBox(height: 8),
          // Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: Colors.grey.shade200,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withOpacity(0.12),
            ),
            child: Slider(
              value: offered,
              min: minP,
              max: maxP,
              divisions: ((maxP - minP) / 5).round().clamp(1, 100),
              onChanged: (v) => setState(() => _offeredPrice = v),
            ),
          ),
          // Min / avg / max labels
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${minP.toStringAsFixed(0)} ج', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Row(children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text('متوسط ${avgP.toStringAsFixed(0)} ج',
                  style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600)),
            ]),
            Text('${maxP.toStringAsFixed(0)} ج', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
        ]),
      ),
    );
  }

  // ─── Bottom Sheet ─────────────────────────────────────────────────────────
  Widget _buildBottomSheet() {
    final hasRoute = _pickupLatLng != null && _destLatLng != null;
    return DraggableScrollableSheet(
      initialChildSize: hasRoute ? 0.45 : 0.18,
      minChildSize: 0.12,
      maxChildSize: 0.75,
      snap: true,
      snapSizes: const [0.12, 0.45, 0.75],
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -4))],
        ),
        child: ListView(controller: scrollCtrl, padding: EdgeInsets.zero, children: [
          // Handle
          Center(child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          )),

          if (!hasRoute) ...[
            // Compact state — just a prompt
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: GestureDetector(
                onTap: () => _openSearch(false),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(children: [
                    const Icon(Icons.search, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Text('إلى أين تريد الذهاب؟',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
                  ]),
                ),
              ),
            ),
          ] else ...[
            // Route summary
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(children: [
                if (_distanceKm != null) ...[
                  _StatChip(icon: Icons.straighten, label: '${_distanceKm!.toStringAsFixed(1)} كم'),
                  const SizedBox(width: 8),
                ],
                if (_durationMin != null)
                  _StatChip(icon: Icons.timer_outlined, label: '$_durationMin دقيقة'),
                const Spacer(),
                if (_estimatedFare != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_estimatedFare!.toStringAsFixed(0)} جنيه',
                      style: const TextStyle(
                          color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ),
              ]),
            ),

            // ── Big ride-type cards ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('نوع الرحلة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black54)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 136,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(bottom: 4),
                    children: _rideTypes.entries.map((e) {
                      final sel     = _selectedType == e.key;
                      final accent  = e.value['color'] as Color;
                      final pricing = _rideTypePricing[e.key];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedType = e.key;
                            // Reset offered price to estimated fare (or average) for new type
                            final p = _rideTypePricing[e.key];
                            if (_estimatedFare != null && p != null) {
                              _offeredPrice = _estimatedFare!.clamp(p['min']!, p['max']!);
                            } else if (p != null) {
                              _offeredPrice = p['average'] ?? 60;
                            }
                          });
                          if (_pickupLatLng != null && _destLatLng != null) _fetchRouteAndFare();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 12),
                          width: 110,
                          decoration: BoxDecoration(
                            color: sel ? accent : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: sel ? accent : Colors.grey.shade200, width: sel ? 0 : 1),
                            boxShadow: [
                              BoxShadow(
                                color: sel ? accent.withOpacity(0.35) : Colors.black.withOpacity(0.06),
                                blurRadius: sel ? 14 : 6,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(e.value['emoji']!, style: const TextStyle(fontSize: 34)),
                              const SizedBox(height: 6),
                              Text(e.value['label']!, style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w800,
                                  color: sel ? Colors.white : Colors.black87)),
                              const SizedBox(height: 3),
                              Text(e.value['desc']!, style: TextStyle(
                                  fontSize: 10, color: sel ? Colors.white70 : Colors.grey)),
                              if (pricing != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '${pricing['min']!.toStringAsFixed(0)}-${pricing['max']!.toStringAsFixed(0)} ج',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                                      color: sel ? Colors.white70 : Colors.black45),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ]),
            ),

            // ── Price-offer slider (shown once fare is estimated) ─────
            if (_estimatedFare != null && _selectedTypePricing != null)
              _buildPriceOfferPanel(),

            // Payment method
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('طريقة الدفع', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black54)),
                const SizedBox(height: 8),
                Row(children: [
                  _PayChip(label: '💵 كاش',       value: 'CASH',          selected: _paymentMethod == 'CASH',          onTap: () => setState(() => _paymentMethod = 'CASH')),
                  const SizedBox(width: 8),
                  _PayChip(label: '📱 InstaPay',  value: 'INSTAPAY',      selected: _paymentMethod == 'INSTAPAY',      onTap: () => setState(() => _paymentMethod = 'INSTAPAY')),
                  const SizedBox(width: 8),
                  _PayChip(label: '📲 Vodafone',  value: 'VODAFONE_CASH', selected: _paymentMethod == 'VODAFONE_CASH', onTap: () => setState(() => _paymentMethod = 'VODAFONE_CASH')),
                ]),
              ]),
            ),

            // Confirm button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: PrimaryButton(
                text: 'تأكيد الحجز',
                onPressed: _submitting ? null : _confirmBooking,
                loading: _loading,
                icon: Icons.check_circle_outline,
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

// ─── Helper Widgets ──────────────────────────────────────────────────────────

class _SearchFieldTile extends StatelessWidget {
  final IconData icon; final Color iconColor; final double iconSize;
  final String text; final bool placeholder;
  final VoidCallback onTap; final Widget? trailing;

  const _SearchFieldTile({
    required this.icon, required this.iconColor, required this.iconSize,
    required this.text, required this.placeholder, required this.onTap, this.trailing,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Icon(icon, color: iconColor, size: iconSize),
        const SizedBox(width: 14),
        Expanded(child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: placeholder ? Colors.grey.shade400 : Colors.black87,
            fontWeight: placeholder ? FontWeight.normal : FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        )),
        if (trailing != null) trailing!,
      ]),
    ),
  );
}

class _InlineSearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final IconData icon; final Color iconColor; final double iconSize;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool active;

  const _InlineSearchField({
    required this.controller, required this.focusNode,
    required this.hint, required this.icon,
    required this.iconColor, required this.iconSize,
    this.autofocus = false, this.onChanged, this.onTap, this.active = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    child: Row(children: [
      Icon(icon, color: iconColor, size: iconSize),
      const SizedBox(width: 12),
      Expanded(child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        onTap: onTap,
        onChanged: onChanged,
        textAlign: TextAlign.right,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      )),
      if (controller.text.isNotEmpty)
        GestureDetector(
          onTap: () { controller.clear(); if (onChanged != null) onChanged!(''); },
          child: Icon(Icons.close, size: 16, color: Colors.grey.shade400),
        ),
    ]),
  );
}

class _StatChip extends StatelessWidget {
  final IconData icon; final String label;
  const _StatChip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: Colors.grey.shade600),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _PayChip extends StatelessWidget {
  final String label, value; final bool selected; final VoidCallback onTap;
  const _PayChip({required this.label, required this.value, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: selected ? AppColors.primary : Colors.grey.shade200),
      ),
      child: Text(label, textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              color: selected ? Colors.white : Colors.black87)),
    ),
  ));
}

/// +/- step button for the price-offer panel
class _PriceStepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _PriceStepBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.10),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: AppColors.primary, size: 22),
    ),
  );
}

class _QuickItem extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _QuickItem({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
      child: Icon(icon, size: 18, color: Colors.grey.shade600),
    ),
    title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
    onTap: onTap,
    dense: true,
  );
}