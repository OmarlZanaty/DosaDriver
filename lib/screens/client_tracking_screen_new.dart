import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:DosaDriver/core/localization/localization_helper.dart';
import '../services/api_client.dart';
import '../services/ride_api.dart';
import '../services/session_store.dart';
import '../core/ride/ride_status.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../widgets/captain_info_card.dart';
import 'client_ride_complete_screen.dart';
import 'client_home_new.dart';


class ClientTrackingScreenNew extends StatefulWidget {
  final String rideId;

  const ClientTrackingScreenNew({super.key, required this.rideId});

  @override
  State<ClientTrackingScreenNew> createState() =>
      _ClientTrackingScreenNewState();
}

class _ClientTrackingScreenNewState extends State<ClientTrackingScreenNew>
    with WidgetsBindingObserver {
  GoogleMapController? _mapController;

  final RideApi _rideApi = RideApi(ApiClient());
  final SessionStore _session = SessionStore();

  bool get _canCancelRide {
    final st = rideStatusFromAny(_rideStatus);
    return st == RideStatus.requested || st == RideStatus.accepted;
  }

  LatLng? _pickupLatLng;
  LatLng? _destinationLatLng;
  LatLng? _captainLatLng;

  bool _didFitPickup = false;
  bool _didFitDestination = false;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  String _carType = '';
  String _carNumber = '';
  String _carColor = '';
  String? _captainPhotoUrl;

  String _rideStatus = 'accepted';
  String _captainName = '';
  String _captainPhone = '';
  String _captainVehicle = '';
  String _captainPlate = '';
  double _captainRating = 0.0;
  double _estimatedFare = 0.0;
  String _eta = '--';

  Timer? _activePollTimer;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _rideMirrorSub;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _captainLiveSub;
  Map<String, dynamic>? _captainLive;
  String? _captainUid;


  String? _activeRideId;
  Map<String, dynamic>? _mirrorRideData;

  int _noActiveStreak = 0;
  bool _exiting = false;

  bool _loading = true;
  String? _error;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startActiveRideLoop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Force a backend truth check immediately when coming back to app
      _refreshActiveRide();
    }
  }


  // ===================== RIDE LISTENER =====================
  Future<void> _subscribeCaptainLive(String captainUid) async {
    if (_captainUid == captainUid && _captainLiveSub != null) return;

    await _captainLiveSub?.cancel();
    _captainUid = captainUid;

    _captainLiveSub = FirebaseFirestore.instance
        .collection('captains_live')
        .doc(captainUid)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;

      final data = snap.data();
      setState(() {
        _captainLive = data;

        final lat = (data?['lat'] as num?)?.toDouble();
        final lng = (data?['lng'] as num?)?.toDouble();

        if (lat != null && lng != null) {
          _captainLatLng = LatLng(lat, lng);
        }
      });

      // update map overlays outside setState is fine too
      _updateMarkers();
      _updateEta();
    });
  }

  void _startActiveRideLoop() {
    // run immediately
    _refreshActiveRide();

    // then poll every 3s (not 2s) - lighter + still fast
    _activePollTimer?.cancel();
    _activePollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _refreshActiveRide();
    });
  }

  Future<void> _refreshActiveRide() async {
    try {
      final ride = await _rideApi.getActiveRide();

      // if no active ride
      // if no active ride (backend is authoritative)
      if (ride == null) {
        _noActiveStreak++;

        // First miss: keep screen for 1 cycle (network / cold start)
        if (_noActiveStreak < 2) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _error = 'Reconnecting...';
          });
          return;
        }

        // Second miss: considered truly no active ride -> exit
        await _exitBecauseNoActiveRide();
        return;
      }

      // backend has active ride -> reset miss counter
      _noActiveStreak = 0;


      final newRideId = ride.id.toString(); // your backend id is numeric -> doc uses same id
      if (_activeRideId != newRideId) {
        _activeRideId = newRideId;
        await _subscribeRideMirror(newRideId);
      }

      if (mounted) {
        setState(() {
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _subscribeRideMirror(String rideId) async {
    await _unsubscribeRideMirror();

    _rideMirrorSub = FirebaseFirestore.instance
        .collection('rides')
        .doc(rideId)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;

      final data = snap.data();
      if (data == null) return;

      setState(() {
        _mirrorRideData = data;

        // status (uppercase in mirror)
        _rideStatus = (data['status'] ?? '').toString();

        // pickup: {lat,lng} (mirror)
        final pickup = data['pickup'];
        if (pickup is Map) {
          final lat = (pickup['lat'] as num?)?.toDouble();
          final lng = (pickup['lng'] as num?)?.toDouble();
          if (lat != null && lng != null) _pickupLatLng = LatLng(lat, lng);
        }

        // drop: {lat,lng} (mirror)
        final drop = data['drop'];
        if (drop is Map) {
          final lat = (drop['lat'] as num?)?.toDouble();
          final lng = (drop['lng'] as num?)?.toDouble();
          if (lat != null && lng != null) _destinationLatLng = LatLng(lat, lng);
        }

        // captain uid -> subscribe live
        final captainUid = data['captainUid'] as String?;
        if (captainUid != null && captainUid.isNotEmpty) {
          _subscribeCaptainLive(captainUid);
        } else {
          _captainLiveSub?.cancel();
          _captainLiveSub = null;
          _captainLive = null;
          _captainUid = null;
          _captainLatLng = null;
        }
      });

      _updateMarkers();
      _updateEta();

      // end ride navigation (mirror is source of truth)
      final st = rideStatusFromAny(_rideStatus);
      if (st == RideStatus.completed) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ClientRideCompleteScreen(
              rideId: rideId, // String
              captainName: _captainName,
              fare: _estimatedFare,
            ),
          ),
        );
      } else if (st == RideStatus.canceled) {
        _showCancelledDialog();
      }
    });
  }


  Future<void> _unsubscribeRideMirror() async {
    await _rideMirrorSub?.cancel();
    _rideMirrorSub = null;
  }

  Future<void> _exitBecauseNoActiveRide() async {
    if (_exiting) return;
    _exiting = true;

    // stop everything
    _activePollTimer?.cancel();
    _activePollTimer = null;

    await _unsubscribeRideMirror();

    await _captainLiveSub?.cancel();
    _captainLiveSub = null;

    if (!mounted) return;

    // clear UI state
    setState(() {
      _activeRideId = null;
      _mirrorRideData = null;
      _loading = false;
      _error = null;
    });

    // Navigate back to Home (remove tracking screen from stack)
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const ClientHomeNew()),
          (route) => false,
    );
  }

  // ===================== MAP HELPERS =====================

  void _fitBounds(LatLng a, LatLng b) {
    final bounds = LatLngBounds(
      southwest: LatLng(
        math.min(a.latitude, b.latitude),
        math.min(a.longitude, b.longitude),
      ),
      northeast: LatLng(
        math.max(a.latitude, b.latitude),
        math.max(a.longitude, b.longitude),
      ),
    );

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80),
    );
  }

  void _updateMarkers() {
    final markers = <Marker>{};

    if (_pickupLatLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: _pickupLatLng!,
          icon:
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }



    if (_destinationLatLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destinationLatLng!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    if (_captainLatLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('captain'),
          position: _captainLatLng!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(
            title: _captainName.isEmpty
                ? context.tr('captain')
                : _captainName,
          ),
        ),
      );
    }

    setState(() => _markers = markers);
  }

  void _updateEta() {
    if (_captainLatLng != null &&
        _pickupLatLng != null &&
        _rideStatus == 'accepted') {
      final distance =
      _calculateDistance(_captainLatLng!, _pickupLatLng!);

      const speedKmH = 30; // average city speed
      final etaMinutes =
      (distance / speedKmH * 60).clamp(1, 99).round();

      _eta = '$etaMinutes min';
    }
  }
  double _calculateDistance(LatLng from, LatLng to) {
    const earthRadius = 6371;
    final dLat = _degToRad(to.latitude - from.latitude);
    final dLng = _degToRad(to.longitude - from.longitude);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(from.latitude)) *
            math.cos(_degToRad(to.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _degToRad(double deg) => deg * (math.pi / 180);

  // ===================== CANCEL =====================



  Future<void> _cancelRide() async {
    try {
      await _rideApi.cancelRide(widget.rideId);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ClientHomeNew()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }



  void _showCancelledDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(context.tr('ride_cancelled')),
        content: Text(context.tr('ride_cancelled_message')),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const ClientHomeNew()),
              );
            },
            child: Text(context.tr('ok')),
          ),
        ],
      ),
    );
  }

  // ===================== UI =====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _pickupLatLng ?? const LatLng(31.2001, 29.9187),
              zoom: 14,
            ),
            onMapCreated: (c) => _mapController = c,
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            zoomControlsEnabled: false,
          ),

          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: _buildTopCard(),
          ),

          // 🔴 CANCEL RIDE BUTTON (TOP RIGHT)
          if (_canCancelRide)
            Positioned(
              top: 16,
              right: 16,
              child: SafeArea(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _cancelRide,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.close, color: Colors.white, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            context.tr('cancel'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            const SizedBox.shrink(),



          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomSheet(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('ride_status'), style: AppTextStyles.bodyMedium),
          const SizedBox(height: 4),
          Text(
            '${context.tr('eta')}: $_eta',
            style: AppTextStyles.headline3,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheet() {
    if (rideStatusFromAny(_rideStatus) == RideStatus.requested) return const SizedBox();

    return CaptainInfoCard(
      name: _captainName,
      phone: _captainPhone,
      carType: _carType,
      carNumber: _carNumber,
      photoUrl: _captainPhotoUrl ??
          'https://ui-avatars.com/api/?name=${Uri.encodeComponent(_captainName)}',
      etaText: _eta,
    );


  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _activePollTimer?.cancel();
    _activePollTimer = null;

    _captainLiveSub?.cancel();
    _rideMirrorSub?.cancel();

    _mapController?.dispose();
    super.dispose();
  }

}
