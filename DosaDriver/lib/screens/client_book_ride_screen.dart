import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
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

class _ClientBookRideScreenState extends State<ClientBookRideScreen> {
  final _pickupCtrl = TextEditingController();
  final _destCtrl   = TextEditingController();
  GoogleMapController? _mapController;

  LatLng? _pickupLatLng;
  LatLng? _destLatLng;
  String _selectedType   = 'FAIR_VALUE';
  String _paymentMethod  = 'CASH';
  bool   _loading        = false;
  bool   _submitting     = false; // FIX: prevents double-submit
  Set<Marker>   _markers   = {};
  Set<Polyline> _polylines = {};

  // FIX: Server-side fare from backend /v1/fare-estimate
  double? _estimatedFare;
  double? _distanceKm;
  int?    _durationMin;

  final _rideApi = ClientRideApi(BackendApi());

  final Map<String, Map<String, String>> _rideTypes = {
    'FAIR_VALUE': {'label': 'قيمة عادلة', 'emoji': '🚖'},
    'PREMIUM':    {'label': 'بريميوم',    'emoji': '🏆'},
    'CUTE_CAR':   {'label': 'كيوت كار',   'emoji': '🚙'},
    'SCOOTER':    {'label': 'سكوتر',      'emoji': '🛵'},
  };

  @override
  void initState() {
    super.initState();
    _selectedType = widget.preselectedType ?? 'FAIR_VALUE';
    if (widget.initialPickup != null) {
      _pickupLatLng = widget.initialPickup;
      _pickupCtrl.text = 'موقعي الحالي';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryGetLocation());
  }

  @override
  void dispose() {
    _pickupCtrl.dispose();
    _destCtrl.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _tryGetLocation() async {
    if (_pickupLatLng != null) return;
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() { _pickupLatLng = LatLng(pos.latitude, pos.longitude); _pickupCtrl.text = 'موقعي الحالي'; });
      _rebuild();
    } catch (_) {}
  }

  Future<String> _reverseGeocode(LatLng pos) async {
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${pos.latitude},${pos.longitude}&key=${AppConfig.mapsApiKey}&language=ar',
      );
      final res = await http.get(uri);
      final data = jsonDecode(res.body);
      // FIX: null/empty check before indexing
      if (data['status'] == 'OK') {
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          return results[0]['formatted_address'] as String;
        }
      }
    } catch (_) {}
    return '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
  }

  Future<LatLng?> _geocode(String address) async {
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=${AppConfig.mapsApiKey}&language=ar',
      );
      final res = await http.get(uri);
      final data = jsonDecode(res.body);
      if (data['status'] == 'OK') {
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          final loc = results[0]['geometry']['location'];
          return LatLng((loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble());
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _fetchRouteAndFare() async {
    if (_pickupLatLng == null || _destLatLng == null) return;
    setState(() => _loading = true);
    try {
      final dirUri = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${_pickupLatLng!.latitude},${_pickupLatLng!.longitude}'
        '&destination=${_destLatLng!.latitude},${_destLatLng!.longitude}'
        '&mode=driving&key=${AppConfig.mapsApiKey}',
      );
      final dirRes  = await http.get(dirUri);
      final dirData = jsonDecode(dirRes.body);

      if (dirData['status'] == 'OK') {
        final routes = dirData['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final leg     = routes[0]['legs'][0];
          final distM   = leg['distance']['value'] as int;
          final durS    = leg['duration']['value'] as int;
          final distKm  = distM / 1000.0;
          final durMin  = (durS / 60).ceil();

          final encoded = routes[0]['overview_polyline']['points'] as String;
          final points  = _decode(encoded);

          setState(() {
            _distanceKm  = distKm;
            _durationMin = durMin;
            _polylines   = {Polyline(polylineId: const PolylineId('r'), color: AppColors.primary, width: 5, points: points)};
          });

          // FIX: Fetch fare from backend — no hardcoded formula
          final fareData = await _rideApi.getFareEstimate(
            type: _selectedType, distanceKm: distKm, durationMin: durMin.toDouble(),
          );
          if (mounted) setState(() => _estimatedFare = (fareData['fare'] as num?)?.toDouble());
        }
      }
    } catch (_) {
      if (mounted) setState(() => _estimatedFare = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<LatLng> _decode(String enc) {
    List<LatLng> p = [];
    int i = 0, lat = 0, lng = 0;
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

  void _rebuild() {
    final m = <Marker>{};
    if (_pickupLatLng != null) m.add(Marker(
      markerId: const MarkerId('p'), position: _pickupLatLng!,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: const InfoWindow(title: 'نقطة الانطلاق')));
    if (_destLatLng != null) m.add(Marker(
      markerId: const MarkerId('d'), position: _destLatLng!,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: const InfoWindow(title: 'الوجهة')));
    setState(() => _markers = m);

    if (_pickupLatLng != null && _destLatLng != null) {
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(LatLngBounds(
        southwest: LatLng(
          [_pickupLatLng!.latitude, _destLatLng!.latitude].reduce((a,b) => a<b?a:b),
          [_pickupLatLng!.longitude,_destLatLng!.longitude].reduce((a,b) => a<b?a:b),
        ),
        northeast: LatLng(
          [_pickupLatLng!.latitude, _destLatLng!.latitude].reduce((a,b) => a>b?a:b),
          [_pickupLatLng!.longitude,_destLatLng!.longitude].reduce((a,b) => a>b?a:b),
        ),
      ), 100));
      _fetchRouteAndFare();
    } else if (_pickupLatLng != null) {
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_pickupLatLng!, 15));
    }
  }

  Future<void> _searchPlace(bool isPickup) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(isPickup ? 'نقطة الانطلاق' : 'الوجهة',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        content: TextField(controller: ctrl, autofocus: true,
          decoration: InputDecoration(hintText: 'أدخل العنوان...',
            prefixIcon: const Icon(Icons.search), filled: true, fillColor: const Color(0xFFF5F5F5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('بحث', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    setState(() => _loading = true);
    try {
      final latLng = await _geocode(result);
      if (latLng == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لم يتم العثور على العنوان')));
        return;
      }
      final addr = await _reverseGeocode(latLng);
      setState(() {
        if (isPickup) { _pickupLatLng = latLng; _pickupCtrl.text = addr; }
        else          { _destLatLng   = latLng; _destCtrl.text   = addr; }
      });
      _rebuild();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmBooking() async {
    // FIX: Synchronous flag prevents double-submit
    if (_submitting) return;
    if (_pickupLatLng == null || _destLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى تحديد نقطة الانطلاق والوجهة')));
      return;
    }
    _submitting = true;
    setState(() => _loading = true);
    try {
      // FIX: No Firestore write — backend creates ride and mirrors to Firestore
      final ride = await _rideApi.createRide(
        pickupLat: _pickupLatLng!.latitude, pickupLng: _pickupLatLng!.longitude,
        dropLat:   _destLatLng!.latitude,   dropLng:   _destLatLng!.longitude,
        pickupAddr: _pickupCtrl.text,
        dropAddr:   _destCtrl.text,
        rideType:   _selectedType,
        distanceKm:  _distanceKm ?? 5.0,
        durationMin: (_durationMin ?? 10).toDouble(),
        paymentMethod: _paymentMethod,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('احجز رحلة', style: TextStyle(fontWeight: FontWeight.w800)),
          backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0),
      body: Column(children: [
        // Map
        SizedBox(height: 240, child: Stack(children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _pickupLatLng ?? const LatLng(30.0444, 31.2357), zoom: 14),
            markers: _markers, polylines: _polylines,
            myLocationEnabled: true, myLocationButtonEnabled: false, zoomControlsEnabled: false,
            onMapCreated: (c) { _mapController = c; _rebuild(); },
            onTap: (latlng) async {
              final addr = await _reverseGeocode(latlng);
              setState(() { _destLatLng = latlng; _destCtrl.text = addr; });
              _rebuild();
            },
          ),
          if (_loading) const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ])),

        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Pickup
          _LocationField(controller: _pickupCtrl, label: 'نقطة الانطلاق',
              icon: Icons.circle, iconColor: Colors.green, onTap: () => _searchPlace(true),
              onCurrentLoc: _tryGetLocation),
          const SizedBox(height: 10),
          // Destination
          _LocationField(controller: _destCtrl, label: 'الوجهة',
              icon: Icons.location_on, iconColor: AppColors.primary, onTap: () => _searchPlace(false)),
          const SizedBox(height: 8),
          const Row(children: [Icon(Icons.info_outline, size: 13, color: Colors.grey), SizedBox(width: 6),
            Text('يمكنك الضغط على الخريطة لتحديد الوجهة', style: TextStyle(fontSize: 11, color: Colors.grey))]),
          const SizedBox(height: 18),

          // Ride types
          const Text('نوع الرحلة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.6,
            children: _rideTypes.entries.map((e) {
              final sel = _selectedType == e.key;
              return GestureDetector(
                onTap: () { setState(() => _selectedType = e.key); if (_pickupLatLng != null && _destLatLng != null) _fetchRouteAndFare(); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: sel ? AppColors.primary : const Color(0xFFE0E0E0), width: sel ? 2 : 1),
                    boxShadow: sel ? [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 8)] : [],
                  ),
                  child: Row(children: [
                    Text(e.value['emoji']!, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(e.value['label']!, style: TextStyle(fontWeight: FontWeight.w700,
                        color: sel ? Colors.white : const Color(0xFF212121), fontSize: 13)),
                  ]),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),

          // Payment method
          const Text('طريقة الدفع', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(children: [
            _PayChip(label: '💵 كاش', value: 'CASH', selected: _paymentMethod == 'CASH',
                onTap: () => setState(() => _paymentMethod = 'CASH')),
            const SizedBox(width: 10),
            _PayChip(label: '📱 InstaPay', value: 'INSTAPAY', selected: _paymentMethod == 'INSTAPAY',
                onTap: () => setState(() => _paymentMethod = 'INSTAPAY')),
            const SizedBox(width: 10),
            _PayChip(label: '📲 Vodafone', value: 'VODAFONE_CASH', selected: _paymentMethod == 'VODAFONE_CASH',
                onTap: () => setState(() => _paymentMethod = 'VODAFONE_CASH')),
          ]),

          // Transfer payment info banner
          if (_paymentMethod == 'INSTAPAY' || _paymentMethod == 'VODAFONE_CASH') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(12)),
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Icon(Icons.info, color: Colors.orange, size: 18), SizedBox(width: 6),
                  Text('تعليمات الدفع بالتحويل', style: TextStyle(fontWeight: FontWeight.w700))]),
                SizedBox(height: 6),
                Text('ستحتاج لإرسال المبلغ على الرقم المحدد من الإدارة، ثم رفع لقطة شاشة التحويل داخل التطبيق.',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
            ),
          ],

          // Fare card
          if (_estimatedFare != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2))),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('السعر التقديري', style: TextStyle(fontWeight: FontWeight.w700)),
                  Text('${_estimatedFare!.toStringAsFixed(2)} جنيه',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary)),
                ]),
                if (_distanceKm != null && _durationMin != null) ...[
                  const Divider(height: 14),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _FareDetail(icon: Icons.straighten, label: '${_distanceKm!.toStringAsFixed(1)} كم'),
                    _FareDetail(icon: Icons.timer, label: '$_durationMin دقيقة'),
                  ]),
                ],
              ]),
            ),
          ],

          const SizedBox(height: 24),
          PrimaryButton(
            text: (_pickupLatLng != null && _destLatLng != null) ? 'تأكيد الحجز' : 'حدد الوجهة أولاً',
            onPressed: (_pickupLatLng != null && _destLatLng != null && !_submitting) ? _confirmBooking : null,
            loading: _loading, icon: Icons.check_circle_outline,
          ),
          const SizedBox(height: 16),
        ]))),
      ]),
    );
  }
}

class _LocationField extends StatelessWidget {
  final TextEditingController controller;
  final String label; final IconData icon; final Color iconColor;
  final VoidCallback onTap; final VoidCallback? onCurrentLoc;
  const _LocationField({required this.controller, required this.label, required this.icon,
      required this.iconColor, required this.onTap, this.onCurrentLoc});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0E0)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)]),
      child: Row(children: [
        Icon(icon, color: iconColor, size: 16), const SizedBox(width: 12),
        Expanded(child: Text(
          controller.text.isEmpty ? label : controller.text,
          style: TextStyle(color: controller.text.isEmpty ? Colors.grey : const Color(0xFF212121),
              fontSize: 14, fontWeight: controller.text.isEmpty ? FontWeight.normal : FontWeight.w600),
          overflow: TextOverflow.ellipsis)),
        if (onCurrentLoc != null)
          GestureDetector(onTap: onCurrentLoc, child: const Padding(padding: EdgeInsets.all(4),
              child: Icon(Icons.my_location, color: AppColors.primary, size: 18))),
        const Icon(Icons.arrow_forward_ios, size: 13, color: Colors.grey),
      ]),
    ),
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: selected ? AppColors.primary : const Color(0xFFE0E0E0)),
      ),
      child: Text(label, textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              color: selected ? Colors.white : const Color(0xFF212121))),
    ),
  ));
}

class _FareDetail extends StatelessWidget {
  final IconData icon; final String label;
  const _FareDetail({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 16, color: AppColors.primary), const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
  ]);
}
