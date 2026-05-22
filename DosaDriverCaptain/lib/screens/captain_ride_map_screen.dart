import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../core/config.dart';
import '../core/ride/ride_status.dart';
import '../core/theme/app_colors.dart';
import '../services/backend_api.dart';
import '../services/captain_ride_api.dart';
import 'captain_home_screen.dart';

class CaptainRideMapScreen extends StatefulWidget {
  final String rideId;
  const CaptainRideMapScreen({super.key, required this.rideId});
  @override
  State<CaptainRideMapScreen> createState() => _CaptainRideMapScreenState();
}

class _CaptainRideMapScreenState extends State<CaptainRideMapScreen> {
  // ─── Services ───────────────────────────────────────────────────────────────
  final _rideApi = CaptainRideApi(BackendApi());

  // ─── Subscriptions ──────────────────────────────────────────────────────────
  StreamSubscription<DocumentSnapshot>? _rideSub;
  StreamSubscription<Position>? _locationSub;
  Timer? _liveTimer;

  // ─── Map ───────────────────────────────────────────────────────────────────
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  // ─── State ─────────────────────────────────────────────────────────────────
  Map<String, dynamic>? _rideData;
  RideStatus _status = RideStatus.accepted;
  LatLng? _captainLatLng;
  LatLng? _pickupLatLng;
  LatLng? _dropoffLatLng;
  bool _routeDrawn = false;
  bool _cameraFitted = false;
  bool _actionLoading = false;

  // FIX: Transfer payment state
  bool _needsTransferConfirm = false;
  bool _transferConfirmed = false;

  // FIX: captain location subscription leak guard
  bool _locationStarted = false;

  // Route-redraw throttle: only re-request Directions API when captain has
  // moved ≥ 150 m from the position used for the last route draw.
  LatLng? _lastRouteOrigin;
  static const double _routeRedrawThresholdM = 150;

  // Turn-by-turn directions
  List<Map<String, dynamic>> _turnSteps = [];
  bool _showTurnList = false;
  int  _currentStepIdx = 0;  // active turn step
  double _captainHeading = 0; // GPS bearing for heading-up camera

  // Using AppConfig.mapsApiKey for Google Maps

  @override
  void initState() {
    super.initState();
    _listenRide();
    _startLocationTracking();
  }

  @override
  void dispose() {
    // FIX: All subscriptions and timers cancelled in dispose — no memory leaks
    _rideSub?.cancel();
    _locationSub?.cancel();
    _liveTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _listenRide() {
    _rideSub = FirebaseFirestore.instance
        .collection('rides')
        .doc(widget.rideId)
        .snapshots()
        .listen((doc) {
      // FIX: Always check mounted at top of stream callback
      if (!mounted) return;
      if (!doc.exists) return;

      final data = doc.data()!;
      _rideData = data;

      final st = RideStatus.fromString(data['status']?.toString());
      final prevStatus = _status;
      _status = st;

      // 🔴 FIX 1: Reset route when status changes so map redraws to new destination
      if (prevStatus != _status) {
        _routeDrawn = false;
        _cameraFitted = false;
        _lastRouteOrigin = null; // force immediate redraw at new status
      }

      _pickupLatLng  = _latLng(data, 'pickup');
      _dropoffLatLng = _latLng(data, 'drop');

      // Detect transfer payment needing confirmation
      final payMethod = (data['paymentMethod'] ?? '').toString().toUpperCase();
      final isTransfer = payMethod == 'INSTAPAY' || payMethod == 'VODAFONE_CASH';
      _needsTransferConfirm = isTransfer && _status == RideStatus.started && data['transferConfirmedAt'] == null;
      _transferConfirmed    = data['transferConfirmedAt'] != null;

      _rebuildMarkers();
      _maybeDrawRoute();

      if (_status == RideStatus.completed && prevStatus != RideStatus.completed) {
        _goToHome();
      }
      if (_status == RideStatus.canceled && prevStatus != RideStatus.canceled) {
        _showCancelledDialog();
      }

      setState(() {});
    });
  }

  LatLng? _latLng(Map<String, dynamic> data, String key) {
    final m = data[key];
    if (m is Map) {
      final lat = (m['lat'] ?? m['latitude'])?.toDouble();
      final lng = (m['lng'] ?? m['longitude'])?.toDouble();
      if (lat != null && lng != null) return LatLng(lat, lng);
    }
    return null;
  }

  void _startLocationTracking() {
    if (_locationStarted) return;
    _locationStarted = true;

    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) {
      if (!mounted) return;
      final newLatLng = LatLng(pos.latitude, pos.longitude);
      _captainHeading = pos.heading;
      setState(() => _captainLatLng = newLatLng);

      // Always rebuild markers so the captain's own pin moves on the map.
      _rebuildMarkers();

      _updateFirestoreLive(pos.latitude, pos.longitude, pos.heading);
      _maybeDrawRoute();
      _advanceStepIfNeeded();

      // Navigation-mode camera: heading-up tilt while driving to pickup OR
      // destination.  Stays still at 'arrived' so the captain isn't fighting
      // the camera while waiting for the client.
      if ((_status == RideStatus.accepted || _status == RideStatus.started) &&
          _mapController != null) {
        _mapController!.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(
            target: newLatLng,
            bearing: _captainHeading,
            tilt: 30,
            zoom: 17,
          ),
        ));
      }
    });
  }

  Future<void> _updateFirestoreLive(double lat, double lng, [double? heading]) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('captains_live').doc(uid).set({
        'lat': lat,
        'lng': lng,
        'heading': heading ?? 0,
        // 🔴 FIX 4: Use same field name as DriverService so client app sees updates
        'lastLocationAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  void _rebuildMarkers() {
    final markers = <Marker>{};

    // 🔴 FIX 6: Explicit captain marker (in addition to myLocation blue dot)
    if (_captainLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('captain'),
        position: _captainLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'موقعك'),
      ));
    }

    // Pickup marker: visible during ACCEPTED and ARRIVED
    if (_pickupLatLng != null &&
        (_status == RideStatus.accepted || _status == RideStatus.arrived)) {
      markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: _pickupLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'نقطة الالتقاء'),
      ));
    }

    // Dropoff marker: always visible once ride has destination
    if (_dropoffLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('drop'),
        position: _dropoffLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'الوجهة'),
      ));
    }

    if (mounted) setState(() => _markers = markers);
  }

  Future<void> _maybeDrawRoute() async {
    final dest = _status == RideStatus.started ? _dropoffLatLng : _pickupLatLng;
    if (_captainLatLng == null || dest == null) return;

    // Throttle: only re-call Directions API when captain moves ≥ threshold
    // from the position used for the last draw.  _lastRouteOrigin is reset
    // to null on every status change, so the first draw after each transition
    // always fires immediately regardless of distance.
    if (_routeDrawn && _lastRouteOrigin != null) {
      final moved = Geolocator.distanceBetween(
        _captainLatLng!.latitude, _captainLatLng!.longitude,
        _lastRouteOrigin!.latitude, _lastRouteOrigin!.longitude,
      );
      if (moved < _routeRedrawThresholdM) return;
    }

    _lastRouteOrigin = _captainLatLng;

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
        final encoded = route['overview_polyline']['points'];
        final points  = _decodePolyline(encoded);
        final steps = (route['legs'] as List?)?.isNotEmpty == true
            ? ((route['legs'][0]['steps'] as List?) ?? [])
            : <dynamic>[];
        if (mounted) setState(() {
          _polylines = { Polyline(polylineId: const PolylineId('r'), color: AppColors.primary, width: 4, points: points) };
          _turnSteps = steps.map((s) => Map<String, dynamic>.from(s)).toList();
          _currentStepIdx = 0; // reset to first step when route redraws
          _routeDrawn = true;
        });

        // On first draw for this status, briefly show an overview so the
        // captain can orient (both their position and the destination are
        // visible).  The navigation-mode camera in the location stream will
        // then take over as soon as the next GPS tick fires.
        if (_mapController != null && !_cameraFitted) {
          final southLat = _captainLatLng!.latitude < dest.latitude
              ? _captainLatLng!.latitude : dest.latitude;
          final northLat = _captainLatLng!.latitude > dest.latitude
              ? _captainLatLng!.latitude : dest.latitude;
          final westLng = _captainLatLng!.longitude < dest.longitude
              ? _captainLatLng!.longitude : dest.longitude;
          final eastLng = _captainLatLng!.longitude > dest.longitude
              ? _captainLatLng!.longitude : dest.longitude;

          _mapController!.animateCamera(
            CameraUpdate.newLatLngBounds(
              LatLngBounds(
                southwest: LatLng(southLat - 0.002, westLng - 0.002),
                northeast: LatLng(northLat + 0.002, eastLng + 0.002),
              ),
              80,
            ),
          );
          _cameraFitted = true;
        }
      }
    } catch (_) {}
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int i = 0, lat = 0, lng = 0;
    while (i < encoded.length) {
      int b, shift = 0, result = 0;
      do { b = encoded.codeUnitAt(i++) - 63; result |= (b & 0x1f) << shift; shift += 5; } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : result >> 1;
      shift = 0; result = 0;
      do { b = encoded.codeUnitAt(i++) - 63; result |= (b & 0x1f) << shift; shift += 5; } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : result >> 1;
      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return poly;
  }

  // ─── STEP NAVIGATION ──────────────────────────────────────────────────────────

  /// Advance to the next turn step when within 30 m of the current step's end.
  void _advanceStepIfNeeded() {
    if (_captainLatLng == null || _turnSteps.isEmpty) return;
    if (_currentStepIdx >= _turnSteps.length - 1) return;
    final step = _turnSteps[_currentStepIdx];
    final endLoc = step['end_location'];
    if (endLoc == null) return;
    final stepEnd = LatLng(
      (endLoc['lat'] as num).toDouble(),
      (endLoc['lng'] as num).toDouble(),
    );
    final dist = Geolocator.distanceBetween(
      _captainLatLng!.latitude, _captainLatLng!.longitude,
      stepEnd.latitude, stepEnd.longitude,
    );
    if (dist < 30) {
      if (mounted) setState(() => _currentStepIdx++);
    }
  }

  String _cleanHtml(String html) => html.replaceAll(RegExp(r'<[^>]*>'), '').trim();

  IconData _turnIcon(String? maneuver) {
    if (maneuver == null) return Icons.straight;
    if (maneuver.contains('left'))  return Icons.turn_left;
    if (maneuver.contains('right')) return Icons.turn_right;
    if (maneuver.contains('uturn')) return Icons.u_turn_left;
    return Icons.straight;
  }

  // ─── ACTIONS ─────────────────────────────────────────────────────────────────
  Future<void> _doAction(Future<void> Function() action) async {
    if (_actionLoading) return;
    setState(() { _actionLoading = true; });
    try {
      await action();
      _routeDrawn = false; // redraw route after status change
    } catch (e) {
      if (mounted) _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() { _actionLoading = false; });
    }
  }

  Future<void> _arrive()   => _doAction(() async { await _rideApi.arrive(int.parse(widget.rideId)); });
  Future<void> _start()    => _doAction(() async { await _rideApi.start(int.parse(widget.rideId)); });
  Future<void> _complete() => _doAction(() async {
    // FIX: If transfer payment, require captain to confirm first
    if (_needsTransferConfirm && !_transferConfirmed) {
      _showTransferConfirmDialog();
      return;
    }
    await _rideApi.complete(int.parse(widget.rideId));
  });

  Future<void> _cancel() => _doAction(() async {
    await _rideApi.cancelCaptain(int.parse(widget.rideId));
  });

  Future<void> _confirmTransfer() => _doAction(() async {
    await _rideApi.confirmTransfer(int.parse(widget.rideId));
    if (mounted) setState(() => _transferConfirmed = true);
  });

  void _showTransferConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(children: [Icon(Icons.payment, color: Colors.orange), SizedBox(width: 8), Text('تأكيد التحويل')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('العميل يدفع عبر InstaPay / فودافون كاش.'),
            SizedBox(height: 8),
            Text('يرجى مطالبة العميل بإراءتك رسالة التحويل على هاتفه، ثم اضغط تأكيد.', style: TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _confirmTransfer(); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('تأكيد الاستلام', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _goToHome() {
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const CaptainHomeScreen()),
        (r) => false,
      );
    });
  }

  void _showCancelledDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('تم إلغاء الرحلة'),
        content: const Text('تم إلغاء الرحلة من قِبل العميل.'),
        actions: [
          ElevatedButton(
            onPressed: () { Navigator.of(ctx).pop(); _goToHome(); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('العودة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  // ─── ACTION BUTTON ────────────────────────────────────────────────────────────
  Widget _actionButton() {
    String label; Color color; VoidCallback onTap;
    switch (_status) {
      case RideStatus.accepted:
        label = 'وصلت إلى العميل'; color = Colors.blue;    onTap = _arrive;   break;
      case RideStatus.arrived:
        label = 'ابدأ الرحلة';      color = Colors.green;   onTap = _start;    break;
      case RideStatus.started:
        label = 'أنهِ الرحلة';      color = AppColors.primary; onTap = _complete; break;
      default:
        return const SizedBox();
    }

    return SizedBox(
      width: double.infinity, height: 52,
      child: ElevatedButton(
        onPressed: _actionLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _actionLoading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final riderPhone = _rideData?['clientPhone']?.toString() ?? '';
    final price      = ((_rideData?['price'] ?? _rideData?['suggestedFare'] ?? 0) as num).toStringAsFixed(2);
    final pickupAddr = _rideData?['pickup']?['addr']?.toString() ?? _rideData?['pickupAddr']?.toString() ?? '';
    final dropAddr   = _rideData?['drop']?['addr']?.toString()   ?? _rideData?['dropAddr']?.toString()   ?? '';

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: Stack(
          children: [
            // Map
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _pickupLatLng ?? const LatLng(30.0444, 31.2357), zoom: 14,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              markers: _markers,
              polylines: _polylines,
              onMapCreated: (c) { _mapController = c; },
            ),

            // Turn-by-turn banner (only when riding — status==started)
            if (_status == RideStatus.started && _turnSteps.isNotEmpty)
              SafeArea(
                child: _TurnBanner(
                  step: _turnSteps[_currentStepIdx.clamp(0, _turnSteps.length - 1)],
                  stepIdx: _currentStepIdx,
                  totalSteps: _turnSteps.length,
                  cleanHtml: _cleanHtml,
                  turnIcon: _turnIcon,
                ),
              ),

            // Status banner (shown when NOT in turn-by-turn mode)
            if (_status != RideStatus.started)
              SafeArea(
                child: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _statusColor(),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 10)],
                  ),
                  child: Row(
                    children: [
                      Icon(_statusIcon(), color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_status.labelAr,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
                      Text('رحلة #${widget.rideId}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
              ),

            // Bottom sheet
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                  boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 16, offset: Offset(0, -4))],
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(99))),

                    // Addresses
                    _AddressRow(icon: Icons.circle,     color: Colors.green,           label: 'من', addr: pickupAddr),
                    const SizedBox(height: 6),
                    _AddressRow(icon: Icons.location_on, color: AppColors.primary,     label: 'إلى', addr: dropAddr),
                    const SizedBox(height: 12),

                    // Price + payment
                    Row(children: [
                      Expanded(child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('الأجرة', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          Text('$price جنيه', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary)),
                        ]),
                      )),
                      const SizedBox(width: 10),
                      // Call client
                      if (riderPhone.isNotEmpty)
                        _CircleAction(icon: Icons.phone, color: Colors.green,
                            onTap: () => launchUrl(Uri.parse('tel:$riderPhone'))),
                      const SizedBox(width: 8),
                      // Cancel
                      if (_status == RideStatus.accepted || _status == RideStatus.arrived)
                        _CircleAction(icon: Icons.close, color: Colors.red, onTap: () async {
                          final ok = await _confirmCancel();
                          if (ok == true) _cancel();
                        }),
                    ]),

                    // Transfer confirm banner
                    if (_needsTransferConfirm && !_transferConfirmed) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(10)),
                        child: Row(children: [
                          const Icon(Icons.warning_amber, color: Colors.orange),
                          const SizedBox(width: 8),
                          const Expanded(child: Text('يدفع العميل عبر InstaPay/Vodafone Cash — يجب تأكيد الاستلام أولاً',
                              style: TextStyle(fontSize: 12))),
                          TextButton(onPressed: _showTransferConfirmDialog, child: const Text('تأكيد')),
                        ]),
                      ),
                    ],

                    if (_transferConfirmed) ...[
                      const SizedBox(height: 8),
                      const Row(children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 18),
                        SizedBox(width: 6),
                        Text('تم تأكيد استلام التحويل ✓', style: TextStyle(color: Colors.green, fontSize: 13)),
                      ]),
                    ],

                    const SizedBox(height: 14),
                    _actionButton(),
                    if (_status == RideStatus.started && _turnSteps.isNotEmpty)
                      _buildTurnList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmCancel() => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('إلغاء الرحلة؟'),
      content: const Text('هل أنت متأكد من رغبتك في إلغاء هذه الرحلة؟'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لا')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('نعم', style: TextStyle(color: Colors.white))),
      ],
    ),
  );

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
          constraints: const BoxConstraints(maxHeight: 160),
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

  Color _statusColor() {
    switch (_status) {
      case RideStatus.accepted: return Colors.blue;
      case RideStatus.arrived:  return Colors.purple;
      case RideStatus.started:  return Colors.green;
      default: return Colors.grey;
    }
  }

  IconData _statusIcon() {
    switch (_status) {
      case RideStatus.accepted: return Icons.directions_car;
      case RideStatus.arrived:  return Icons.location_on;
      case RideStatus.started:  return Icons.navigation;
      default: return Icons.info;
    }
  }
}

// ─── Turn Banner ─────────────────────────────────────────────────────────────
class _TurnBanner extends StatelessWidget {
  final Map<String, dynamic> step;
  final int stepIdx;
  final int totalSteps;
  final String Function(String) cleanHtml;
  final IconData Function(String?) turnIcon;

  const _TurnBanner({
    required this.step,
    required this.stepIdx,
    required this.totalSteps,
    required this.cleanHtml,
    required this.turnIcon,
  });

  @override
  Widget build(BuildContext context) {
    final maneuver  = step['maneuver']?.toString();
    final html      = step['html_instructions']?.toString() ?? '';
    final distText  = step['distance']?['text']?.toString() ?? '';
    final icon      = turnIcon(maneuver);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              cleanHtml(html),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (distText.isNotEmpty)
              Text(distText, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ]),
        ),
        const SizedBox(width: 8),
        Text('${stepIdx + 1}/$totalSteps',
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ]),
    );
  }
}

class _AddressRow extends StatelessWidget {
  final IconData icon; final Color color; final String label; final String addr;
  const _AddressRow({required this.icon, required this.color, required this.label, required this.addr});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(addr.isEmpty ? '---' : addr, style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
    ],
  );
}

class _CircleAction extends StatelessWidget {
  final IconData icon; final Color color; final VoidCallback onTap;
  const _CircleAction({required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 46, height: 46,
      decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 22),
    ),
  );
}
