import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import '../core/config.dart';
import '../core/theme/app_colors.dart';
import '../services/backend_api.dart';
import '../services/client_ride_api.dart';
import '../widgets/custom_widgets.dart';
import 'client_home_screen.dart';
import 'client_rate_ride_screen.dart';

class ClientActiveRideScreen extends StatefulWidget {
  final String rideId;
  const ClientActiveRideScreen({super.key, required this.rideId});
  @override
  State<ClientActiveRideScreen> createState() => _ClientActiveRideScreenState();
}

class _ClientActiveRideScreenState extends State<ClientActiveRideScreen> {
  StreamSubscription<DocumentSnapshot>? _rideSub;
  StreamSubscription<DocumentSnapshot>? _captainSub;

  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  Map<String, dynamic>? _rideData;
  String _status = 'requested';
  LatLng? _pickupLatLng;
  LatLng? _destLatLng;
  LatLng? _captainLatLng;

  String? _captainName;
  String? _captainPhone;
  String? _captainPhotoUrl;
  String? _carModel;
  String? _plateNumber;
  double _captainRating = 0;

  // FIX: Transfer payment upload state
  bool _isTransferPayment = false;
  bool _uploadingProof = false;
  String? _proofUrl;

  bool _cancelLoading = false;
  bool _captainSubStarted = false;
  bool _cameraFitted = false;

  // Stores turn-by-turn steps when ride is started
  List<Map<String, dynamic>> _turnSteps = [];
  bool _showTurnList = false;

  Timer? _searchTimer;
  int _searchDots = 1;

  final _rideApi = ClientRideApi(BackendApi());

  @override
  void initState() {
    super.initState();
    _listenRide();
    _startSearchAnim();
  }

  @override
  void dispose() {
    // FIX: All subscriptions cancelled — no memory leaks
    _rideSub?.cancel();
    _captainSub?.cancel();
    _searchTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _startSearchAnim() {
    _searchTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (!mounted) return;
      setState(() => _searchDots = (_searchDots % 3) + 1);
    });
  }

  void _listenRide() {
    _rideSub = FirebaseFirestore.instance
        .collection('rides')
        .doc(widget.rideId)
        .snapshots()
        .listen((doc) {
      // FIX: Always check mounted first
      if (!mounted) return;
      if (!doc.exists) return;

      final data = doc.data()!;
      _rideData = data;
      final st = (data['status'] ?? '').toString().toLowerCase();
      final prevStatus = _status;
      _status = st;

      if (prevStatus != _status) {
        _cameraFitted = false;
      }

      // Parse locations
      final pm = data['pickup'];
      if (pm is Map) _pickupLatLng = LatLng((pm['lat'] ?? 0.0).toDouble(), (pm['lng'] ?? 0.0).toDouble());
      final dm = data['drop'];
      if (dm is Map) _destLatLng = LatLng((dm['lat'] ?? 0.0).toDouble(), (dm['lng'] ?? 0.0).toDouble());

      // Transfer payment detection
      final payMethod = (data['paymentMethod'] ?? '').toString().toUpperCase();
      _isTransferPayment = payMethod == 'INSTAPAY' || payMethod == 'VODAFONE_CASH';
      _proofUrl = data['transferProofUrl'];

      // FIX: Guard against double-starting captain subscription
      final captainUid = data['captainUid']?.toString();
      if (captainUid != null && captainUid.isNotEmpty && !_captainSubStarted) {
        _captainSubStarted = true;
        _captainName  = data['captainName']?.toString();
        _captainPhone = data['captainPhone']?.toString();
        _listenCaptainLive(captainUid);
        _loadCaptainDetails(captainUid);
      }

      _rebuildMarkers();

      // Animate camera to fit both locations when status transitions
      if (prevStatus != st && st != 'requested') {
        _fitBothLocations();
      }

      // FIX: Use addPostFrameCallback for navigation from stream listener
      if (st == 'completed' && prevStatus != 'completed') {
        _searchTimer?.cancel();
        WidgetsBinding.instance.addPostFrameCallback((_) => _goToRating());
      }
      if (st == 'canceled' && prevStatus != 'canceled') {
        _searchTimer?.cancel();
        WidgetsBinding.instance.addPostFrameCallback((_) => _showCancelled());
      }

      setState(() {});
    });
  }

  Future<void> _loadCaptainDetails(String captainUid) async {
    final doc = await FirebaseFirestore.instance.collection('drivers').doc(captainUid).get();
    if (!doc.exists || !mounted) return;
    final d = doc.data()!;
    setState(() {
      _carModel = d['carModel']?.toString();
      _plateNumber = d['plateNumber']?.toString();
      _captainPhotoUrl = d['photoUrl']?.toString() ?? d['documents']?['profileImage']?.toString();
      _captainRating = (d['rating'] ?? 0).toDouble();
    });
  }

  void _listenCaptainLive(String captainUid) {
    _captainSub = FirebaseFirestore.instance
        .collection('captains_live')
        .doc(captainUid)
        .snapshots()
        .listen((doc) {
      if (!mounted || !doc.exists) return;
      final d = doc.data()!;
      final lat = (d['lat'] ?? 0.0).toDouble();
      final lng = (d['lng'] ?? 0.0).toDouble();
      if (lat == 0.0 && lng == 0.0) return;
      _captainLatLng = LatLng(lat, lng);
      _rebuildMarkers();

      // 🔴 FIX: Always try to draw/update route when captain moves
      _drawRoute();

      if (mounted) setState(() {});
    });
  }

  void _fitBothLocations() {
    if (_cameraFitted) return;
    final from = _captainLatLng ?? _pickupLatLng;
    final to = _status == 'started' ? _destLatLng : _pickupLatLng;
    if (from == null || to == null || _mapController == null) return;
    final swLat = from.latitude < to.latitude ? from.latitude : to.latitude;
    final neLat = from.latitude > to.latitude ? from.latitude : to.latitude;
    final swLng = from.longitude < to.longitude ? from.longitude : to.longitude;
    final neLng = from.longitude > to.longitude ? from.longitude : to.longitude;
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: LatLng(swLat, swLng), northeast: LatLng(neLat, neLng)),
        100,
      ),
    );
    _cameraFitted = true;
  }

  void _rebuildMarkers() {
    final m = <Marker>{};
    if (_pickupLatLng != null && _status != 'started') {
      m.add(Marker(markerId: const MarkerId('p'), position: _pickupLatLng!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'نقطة الانطلاق')));
    }
    if (_destLatLng != null) {
      m.add(Marker(markerId: const MarkerId('d'), position: _destLatLng!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'الوجهة')));
    }
    if (_captainLatLng != null) {
      m.add(Marker(markerId: const MarkerId('c'), position: _captainLatLng!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(title: _captainName ?? 'الكابتن')));
    }
    if (mounted) setState(() => _markers = m);
  }

  Future<void> _drawRoute() async {
    final dest = (_status == 'started' ? _destLatLng : _pickupLatLng);
    if (_captainLatLng == null || dest == null) return;

    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${_captainLatLng!.latitude},${_captainLatLng!.longitude}'
        '&destination=${dest.latitude},${dest.longitude}'
        '&mode=driving&key=${AppConfig.mapsApiKey}',
      );
      final res = await http.get(uri);
      final data = jsonDecode(res.body);
      if (data['status'] == 'OK' && (data['routes'] as List).isNotEmpty) {
        final route = data['routes'][0];
        final pts = _decode(route['overview_polyline']['points']);
        final steps = (route['legs'] as List?)?.isNotEmpty == true
            ? ((route['legs'][0]['steps'] as List?) ?? [])
            : <dynamic>[];
        if (mounted) setState(() {
          _polylines = {Polyline(polylineId: const PolylineId('r'), color: AppColors.primary, width: 4, points: pts)};
          _turnSteps = steps.map((s) => Map<String, dynamic>.from(s)).toList();
        });
        _fitBothLocations();
      }
    } catch (_) {}
  }

  List<LatLng> _decode(String enc) {
    List<LatLng> p = [];
    int i = 0, lat = 0, lng = 0;
    while (i < enc.length) {
      int b, s = 0, r = 0;
      do { b = enc.codeUnitAt(i++) - 63; r |= (b & 0x1f) << s; s += 5; } while (b >= 0x20);
      lat += (r & 1) != 0 ? ~(r >> 1) : r >> 1;
      s = 0; r = 0;
      do { b = enc.codeUnitAt(i++) - 63; r |= (b & 0x1f) << s; s += 5; } while (b >= 0x20);
      lng += (r & 1) != 0 ? ~(r >> 1) : r >> 1;
      p.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return p;
  }

  Future<void> _cancelRide() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('إلغاء الرحلة؟'),
        content: const Text('هل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لا')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('نعم', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _cancelLoading = true);
    try {
      await _rideApi.cancelRide(int.parse(widget.rideId));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الإلغاء: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _cancelLoading = false);
    }
  }

  // Transfer payment proof upload
  Future<void> _uploadTransferProof() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (xfile == null) return;

    setState(() => _uploadingProof = true);
    try {
      final uid = _rideData?['riderId']?.toString() ?? 'unknown';
      final ref = FirebaseStorage.instance.ref('transfer_proofs/${widget.rideId}_$uid.jpg');
      await ref.putFile(File(xfile.path));
      final url = await ref.getDownloadURL();

      await _rideApi.submitTransferProof(int.parse(widget.rideId), url);

      if (!mounted) return;
      setState(() => _proofUrl = url);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رفع إيصال التحويل ✓'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الرفع: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _uploadingProof = false);
    }
  }

  void _showCaptainInfoDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(99))),
          Row(children: [
            CircleAvatar(radius: 32,
                backgroundImage: _captainPhotoUrl != null ? NetworkImage(_captainPhotoUrl!) : null,
                onBackgroundImageError: _captainPhotoUrl != null ? (_, __) {} : null,
                backgroundColor: const Color(0xFFF5F5F5),
                child: _captainPhotoUrl == null ? const Icon(Icons.person, size: 32, color: Colors.grey) : null),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_captainName ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              if (_captainRating > 0)
                Row(children: [
                  ...List.generate(5, (i) => Icon(
                    i < _captainRating.round() ? Icons.star : Icons.star_border,
                    size: 18, color: Colors.amber[700])),
                  const SizedBox(width: 6),
                  Text('${_captainRating.toStringAsFixed(1)}', style: const TextStyle(fontSize: 14)),
                ]),
            ])),
          ]),
          const SizedBox(height: 14),
          if (_carModel != null || _plateNumber != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.directions_car, color: Colors.black54),
                const SizedBox(width: 10),
                Text('${_carModel ?? ''}${_carModel != null && _plateNumber != null ? ' · ' : ''}${_plateNumber ?? ''}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ]),
            ),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: () { Navigator.pop(ctx); if (_captainPhone?.isNotEmpty == true) launchUrl(Uri.parse('tel:$_captainPhone')); },
            icon: const Icon(Icons.phone, color: Colors.green),
            label: const Text('اتصال بالكابتن', style: TextStyle(color: Colors.green)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.green),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          )),
        ]),
      ),
    );
  }

  void _goToRating() {
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => ClientRateRideScreen(rideId: widget.rideId, rideData: _rideData ?? {}),
    ));
  }

  void _showCancelled() {
    if (!mounted) return;
    showDialog(
      context: context, barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [Icon(Icons.cancel, color: Colors.red), SizedBox(width: 8), Text('تم إلغاء الرحلة')]),
        content: const Text('تم إلغاء الرحلة. يمكنك حجز رحلة جديدة.'),
        actions: [ElevatedButton(
          onPressed: () { Navigator.of(ctx).pop(); Navigator.pushAndRemoveUntil(context,
              MaterialPageRoute(builder: (_) => const ClientHomeScreen()), (r) => false); },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('العودة', style: TextStyle(color: Colors.white)),
        )],
      ),
    );
  }

  String _statusTitle() {
    switch (_status) {
      case 'requested': return 'جارٍ البحث عن كابتن${'.' * _searchDots}';
      case 'accepted':  return 'الكابتن في الطريق إليك 🚗';
      case 'arrived':   return 'الكابتن وصل! 📍';
      case 'started':   return 'الرحلة جارية 🚀';
      default: return 'جارٍ التحديث...';
    }
  }

  Color _statusColor() {
    switch (_status) {
      case 'requested': return Colors.orange;
      case 'accepted':  return Colors.blue;
      case 'arrived':   return Colors.purple;
      case 'started':   return Colors.green;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = ((_rideData?['price'] ?? _rideData?['suggestedFare'] ?? 0) as num).toStringAsFixed(2);
    final pickupAddr = _rideData?['pickup']?['addr']?.toString() ?? '';
    final dropAddr   = _rideData?['drop']?['addr']?.toString()   ?? '';

    return WillPopScope(
      onWillPop: () async {
        // Allow back if completed/canceled, block otherwise
        if (_status == 'completed' || _status == 'canceled') return true;
        return false;
      },
      child: Scaffold(
        body: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _pickupLatLng ?? const LatLng(30.0444, 31.2357), zoom: 14),
              markers: _markers, polylines: _polylines,
              myLocationEnabled: true, myLocationButtonEnabled: false, zoomControlsEnabled: false,
              onMapCreated: (c) { _mapController = c; },
            ),

            // Status banner
            SafeArea(child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(color: _statusColor(), borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 10)]),
              child: Row(children: [
                const Icon(Icons.local_taxi, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(_statusTitle(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
                Text('#${widget.rideId}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ]),
            )),

            // Bottom sheet
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                decoration: const BoxDecoration(color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                    boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 16, offset: Offset(0, -4))]),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(99))),

                  // Captain info
                  if (_status != 'requested' && _captainName != null)
                    GestureDetector(
                      onTap: () => _showCaptainInfoDialog(),
                      child: Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [
                        CircleAvatar(radius: 24,
                            backgroundImage: _captainPhotoUrl != null ? NetworkImage(_captainPhotoUrl!) : null,
                            onBackgroundImageError: _captainPhotoUrl != null ? (_, __) {} : null,
                            backgroundColor: const Color(0xFFF5F5F5),
                            child: _captainPhotoUrl == null
                                ? const Icon(Icons.person, color: Colors.grey) : null),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_captainName ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          const SizedBox(height: 2),
                          Row(children: [
                            if (_carModel != null)
                              Text('$_carModel', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                            if (_carModel != null && _plateNumber != null)
                              Text(' · ', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                            if (_plateNumber != null)
                              Text('$_plateNumber', style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
                          ]),
                          if (_captainRating > 0)
                            Row(children: [
                              Icon(Icons.star, size: 14, color: Colors.amber[700]),
                              const SizedBox(width: 3),
                              Text('${_captainRating.toStringAsFixed(1)}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                            ]),
                        ])),
                        if (_captainPhone?.isNotEmpty == true)
                          GestureDetector(
                            onTap: () => launchUrl(Uri.parse('tel:$_captainPhone')),
                            child: Container(padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: Colors.green.withOpacity(0.12), shape: BoxShape.circle),
                                child: const Icon(Icons.phone, color: Colors.green, size: 22)),
                          ),
                      ])),
                    ),

                  if (pickupAddr.isNotEmpty) ...[
                    _AddRow(icon: Icons.circle, color: Colors.green, label: 'من', addr: pickupAddr),
                    const SizedBox(height: 6),
                  ],
                  if (dropAddr.isNotEmpty)
                    _AddRow(icon: Icons.location_on, color: AppColors.primary, label: 'إلى', addr: dropAddr),

                  const SizedBox(height: 12),

                  // Price
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('الأجرة', style: TextStyle(fontWeight: FontWeight.w700)),
                      Text('$price جنيه', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary)),
                    ]),
                  ),

                  // Transfer proof upload
                  if (_isTransferPayment && _status == 'started') ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(10)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('دفع عبر InstaPay / Vodafone Cash', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 4),
                        const Text('يرجى رفع لقطة شاشة التحويل حتى يتمكن الكابتن من تأكيد الاستلام.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 8),
                        if (_proofUrl != null)
                          const Row(children: [Icon(Icons.check_circle, color: Colors.green, size: 16), SizedBox(width: 6),
                            Text('تم رفع الإيصال ✓', style: TextStyle(color: Colors.green, fontSize: 13))])
                        else
                          SizedBox(width: double.infinity, child: OutlinedButton.icon(
                            onPressed: _uploadingProof ? null : _uploadTransferProof,
                            icon: _uploadingProof
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.upload_file),
                            label: Text(_uploadingProof ? 'جارٍ الرفع...' : 'رفع إيصال التحويل'),
                            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.orange)),
                          )),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 14),
                  if (_status == 'requested' || _status == 'accepted')
                    SizedBox(width: double.infinity, child: OutlinedButton.icon(
                      onPressed: _cancelLoading ? null : _cancelRide,
                      icon: _cancelLoading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.close, color: Colors.red),
                      label: const Text('إلغاء الرحلة', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                    )),
                  if (_status == 'started' && _turnSteps.isNotEmpty)
                    _buildTurnList(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTurnList() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(
        onTap: () => setState(() => _showTurnList = !_showTurnList),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.route, size: 18, color: Colors.black54),
            const SizedBox(width: 6),
            const Text('الاتجاهات', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const Spacer(),
            Text('${_turnSteps.length}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
            Icon(_showTurnList ? Icons.expand_less : Icons.expand_more, size: 18),
          ]),
        ),
      ),
      if (_showTurnList)
        Container(
          margin: const EdgeInsets.only(top: 6),
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFEEEEEE)),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.all(10),
            itemCount: _turnSteps.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final step = _turnSteps[i];
              final html = step['html_instructions']?.toString() ?? '';
              final dist = step['distance']?['text']?.toString() ?? '';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${i + 1}. ', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  const SizedBox(width: 4),
                  Expanded(child: Text(html.replaceAll(RegExp(r'<[^>]*>'), ''),
                      style: const TextStyle(fontSize: 12))),
                  if (dist.isNotEmpty)
                    Padding(padding: const EdgeInsets.only(right: 4), child: Text(dist,
                        style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600))),
                ]),
              );
            },
          ),
        ),
    ]);
  }
}

class _AddRow extends StatelessWidget {
  final IconData icon; final Color color; final String label; final String addr;
  const _AddRow({required this.icon, required this.color, required this.label, required this.addr});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: color, size: 13),
    const SizedBox(width: 10),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      Text(addr, style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
    ])),
  ]);
}
