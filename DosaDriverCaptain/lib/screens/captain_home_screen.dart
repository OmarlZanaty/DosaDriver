import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/localization/app_strings.dart';
import '../core/localization/language_controller.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../services/driver_service.dart';
import '../utils/native_notification_settings.dart';
import '../widgets/custom_button.dart';
import '../widgets/BottomSheetContent.dart';
import 'captain_earnings_screen.dart';
import 'captain_profile_screen.dart';
import 'captain_ride_map_screen.dart';
import 'captain_trips_screen.dart';
import '../services/backend_api.dart';
import '../services/captain_ride_api.dart';
import '../services/notification_service.dart';
import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class CaptainHomeScreen extends StatefulWidget {
  const CaptainHomeScreen({super.key});

  @override
  State<CaptainHomeScreen> createState() => _CaptainHomeScreenState();
}

class _CaptainHomeScreenState extends State<CaptainHomeScreen>
    with WidgetsBindingObserver {

  // ======================
  // SERVICES
  // ======================
  final DriverService _driverService = DriverService();
  final CaptainRideApi _captainRideApi = CaptainRideApi(BackendApi());


  Timer? _openPollingTimer;
  List<Map<String, dynamic>> _openRides = [];
  bool _loadingOpen = false;
  String? _uid;
  String? _captainType;
  GoogleMapController? _mapController;
  Timer? _pulseTimer;
  bool _pulseOn = false;
  Set<Polygon> _heatPolygons = {};
  Set<Circle> _hotspotCircles = {};

  LatLngBounds? _lastBounds;

  late final AnimationController _pulseCtrl;
  double _pulseT = 0.0;

  // ======================
  // STATE
  // ======================
  bool isOnline = false;

  // Bottom sheet height (used to lift button above it)
  double _sheetHeight = 140.0;

  String? _driverPhotoUrl;

  // Per-ride 20s visibility timers
  final Map<String, DateTime> _firstSeenAt = {};
  final Map<String, Timer> _expireTimers = {};


  Future<void> _loadCaptainType() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('drivers')
        .doc(uid)
        .get();

    if (!doc.exists) return;

    final raw = (doc.data()?['captainType'] ?? 'ECONOMIC').toString();

    // Map to backend's RideType enum values (uppercase)
    switch (raw.toUpperCase()) {
      case 'ECONOMIC':
      case 'CUTE_CAR':
        _captainType = 'CUTE_CAR';
        break;
      case 'PREMIUM':
        _captainType = 'PREMIUM';
        break;
      case 'FAIR_VALUE':
        _captainType = 'FAIR_VALUE';
        break;
      case 'SCOOTER':
        _captainType = 'SCOOTER';
        break;
      default:
        _captainType = 'CUTE_CAR';
    }
  }

  void _startSlowPulse() {
    _pulseTimer?.cancel();
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (!mounted) return;
      // Only pulse if online and map already exists
      if (!isOnline || _mapController == null) return;

      _pulseOn = !_pulseOn;
      _rebuildHotspotCircles(); // updates circles only (not polygons)
    });
  }

  void _stopSlowPulse() {
    _pulseTimer?.cancel();
    _pulseTimer = null;
  }


  void _startOpenPolling() {
    _openPollingTimer?.cancel();

    _fetchOpenRides();

    _openPollingTimer =
        Timer.periodic(const Duration(seconds: 6), (_) async {
          if (!isOnline) return;
          await _fetchOpenRides();
        });
  }

  void _stopOpenPolling() {
    _openPollingTimer?.cancel();
    _openPollingTimer = null;
    setState(() => _openRides = []);
  }

  Future<void> _goToMyLocation() async {
    if (_mapController == null) return;

    try {
      // 🔴 FIX: Check and request permission first
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission required')),
        );
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable GPS/Location service')),
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(pos.latitude, pos.longitude),
            zoom: 16,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Go to my location failed: $e');
    }
  }

  Future<void> _ensureNotificationsEnabled(BuildContext context) async {
    final granted =
    await NotificationService().debugRequestAndroidPermission();

    if (!mounted) return;

    if (!granted) {
      // 🔁 Auto redirect to settings
      await NativeNotificationSettings.open();
    }
  }

  LatLng? _pickupFromRide(Map<String, dynamic> r) {
    final a = r['pickupLat'];
    final b = r['pickupLng'];
    if (a is num && b is num) return LatLng(a.toDouble(), b.toDouble());

    final pickup = r['pickup'];
    if (pickup is Map) {
      final lat = pickup['lat'];
      final lng = pickup['lng'];
      if (lat is num && lng is num) return LatLng(lat.toDouble(), lng.toDouble());
    }
    return null;
  }

  void _clearHeat() {
    if (!mounted) return;
    setState(() {
      _heatPolygons = {};
      _hotspotCircles = {};
    });
  }

  Future<void> _rebuildHeatFromVisibleRegion() async {
    if (!mounted) return;
    if (_mapController == null) return;

    try {
      final b = await _mapController!.getVisibleRegion();
      _lastBounds = b;
      _rebuildHeatPolygons(b);
      _rebuildHotspotCircles();
    } catch (_) {}
  }

  double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

  void _rebuildHeatPolygons(LatLngBounds bounds) {
    final pts = <LatLng>[];
    for (final r in _openRides) {
      final p = _pickupFromRide(r);
      if (p != null) pts.add(p);
    }

    if (pts.isEmpty) {
      setState(() => _heatPolygons = {});
      return;
    }

    final latSpan = (bounds.northeast.latitude - bounds.southwest.latitude).abs();
    final lngSpan = (bounds.northeast.longitude - bounds.southwest.longitude).abs();

    final base = (math.max(latSpan, lngSpan) / 8).clamp(0.002, 0.03);
    final cellLat = base;
    final cellLng = base;

    final counts = <String, int>{};

    bool inside(LatLng p) {
      final latOk = p.latitude >= bounds.southwest.latitude &&
          p.latitude <= bounds.northeast.latitude;
      final lngOk = p.longitude >= bounds.southwest.longitude &&
          p.longitude <= bounds.northeast.longitude;
      return latOk && lngOk;
    }

    for (final p in pts) {
      if (!inside(p)) continue;
      final i = ((p.latitude - bounds.southwest.latitude) / cellLat).floor();
      final j = ((p.longitude - bounds.southwest.longitude) / cellLng).floor();
      final key = '$i:$j';
      counts[key] = (counts[key] ?? 0) + 1;
    }

    if (counts.isEmpty) {
      setState(() => _heatPolygons = {});
      return;
    }

    final maxCount = counts.values.fold<int>(0, (m, v) => v > m ? v : m);

    final polys = <Polygon>{};

    counts.forEach((key, c) {
      final parts = key.split(':');
      final i = int.parse(parts[0]);
      final j = int.parse(parts[1]);

      final lat0 = bounds.southwest.latitude + i * cellLat;
      final lng0 = bounds.southwest.longitude + j * cellLng;
      final lat1 = lat0 + cellLat;
      final lng1 = lng0 + cellLng;

      final t = maxCount == 0 ? 0.0 : (c / maxCount);
      final opacity = (0.10 + 0.35 * _clamp01(t));

      polys.add(
        Polygon(
          polygonId: PolygonId('cell_$key'),
          points: [
            LatLng(lat0, lng0),
            LatLng(lat0, lng1),
            LatLng(lat1, lng1),
            LatLng(lat1, lng0),
          ],
          fillColor: Colors.red.withOpacity(opacity),
          strokeColor: Colors.red.withOpacity((opacity + 0.16).clamp(0.0, 1.0)),
          strokeWidth: 1,
        ),
      );
    });

    setState(() => _heatPolygons = polys);
  }

  // ===== 20s UI countdown per ride =====
  static const int _expireSeconds = 20;

  final Map<String, DateTime> _rideShownAt = {};      // first time we saw ride on screen
  final Map<String, Timer> _rideUiTimers = {};        // timer per ride to update UI

  void _ensureUiCountdownStarted(String rideId) {
    if (_rideShownAt.containsKey(rideId)) return;

    _rideShownAt[rideId] = DateTime.now();

    _rideUiTimers[rideId]?.cancel();
    _rideUiTimers[rideId] = Timer.periodic(const Duration(milliseconds: 200), (t) {
      if (!mounted) return;

      final start = _rideShownAt[rideId];
      if (start == null) {
        t.cancel();
        return;
      }

      final elapsed = DateTime.now().difference(start).inMilliseconds;
      final total = _expireSeconds * 1000;

      if (elapsed >= total) {
        // stop UI timer (actual hide happens by your Firestore "expired" logic)
        t.cancel();
        _rideUiTimers.remove(rideId);
      }

      setState(() {}); // light repaint (you can optimize later)
    });
  }

  double _progressValue(String rideId) {
    final start = _rideShownAt[rideId];
    if (start == null) return 1.0;
    final elapsed = DateTime.now().difference(start).inMilliseconds;
    final total = _expireSeconds * 1000;
    final v = 1.0 - (elapsed / total);
    if (v < 0) return 0;
    if (v > 1) return 1;
    return v;
  }

  int _secondsLeft(String rideId) {
    final start = _rideShownAt[rideId];
    if (start == null) return _expireSeconds;
    final elapsedSec = DateTime.now().difference(start).inSeconds;
    final left = _expireSeconds - elapsedSec;
    return left < 0 ? 0 : left;
  }



  void _rebuildHotspotCircles() {
    final bounds = _lastBounds;
    if (bounds == null) return;

    final pts = <LatLng>[];
    for (final r in _openRides) {
      final p = _pickupFromRide(r);
      if (p != null) pts.add(p);
    }
    if (pts.isEmpty) {
      setState(() => _hotspotCircles = {});
      return;
    }

    final latSpan = (bounds.northeast.latitude - bounds.southwest.latitude).abs();
    final lngSpan = (bounds.northeast.longitude - bounds.southwest.longitude).abs();

    final base = (math.max(latSpan, lngSpan) / 8).clamp(0.002, 0.03);
    final cellLat = base;
    final cellLng = base;

    final counts = <String, int>{};
    final centers = <String, LatLng>{};

    bool inside(LatLng p) {
      final latOk = p.latitude >= bounds.southwest.latitude &&
          p.latitude <= bounds.northeast.latitude;
      final lngOk = p.longitude >= bounds.southwest.longitude &&
          p.longitude <= bounds.northeast.longitude;
      return latOk && lngOk;
    }

    for (final p in pts) {
      if (!inside(p)) continue;

      final i = ((p.latitude - bounds.southwest.latitude) / cellLat).floor();
      final j = ((p.longitude - bounds.southwest.longitude) / cellLng).floor();
      final key = '$i:$j';
      counts[key] = (counts[key] ?? 0) + 1;

      final lat0 = bounds.southwest.latitude + i * cellLat;
      final lng0 = bounds.southwest.longitude + j * cellLng;
      centers[key] = LatLng(lat0 + cellLat / 2, lng0 + cellLng / 2);
    }

    if (counts.isEmpty) return;

    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top = entries.take(6).toList();
    final maxCount = top.first.value;

    final pulse = _pulseOn ? 1.0 : 0.78;

    final circles = <Circle>{};
    for (final e in top) {
      final key = e.key;
      final count = e.value;
      final center = centers[key];
      if (center == null) continue;

      final t = maxCount == 0 ? 0.0 : (count / maxCount);
      final baseRadius = 220.0 + 480.0 * t;
      final radius = baseRadius * pulse;

      circles.add(
        Circle(
          circleId: CircleId('hot_$key'),
          center: center,
          radius: radius,
          fillColor: Colors.red.withOpacity((0.08 + 0.18 * t).clamp(0.0, 0.35)),
          strokeColor: Colors.red.withOpacity((0.22 + 0.35 * t).clamp(0.0, 0.8)),
          strokeWidth: 2,
        ),
      );
    }

    if (mounted) setState(() => _hotspotCircles = circles);

  }


  int _openRidesFailureStreak = 0;
  DateTime? _openRidesBackoffUntil;

  Future<void> _fetchOpenRides() async {
    // Skip if not signed in (avoid spamming auth errors).
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    // Honor exponential backoff after consecutive failures.
    final now = DateTime.now();
    if (_openRidesBackoffUntil != null && now.isBefore(_openRidesBackoffUntil!)) {
      return;
    }
    try {
      final rides = await _captainRideApi.getOpenRides(_captainType);

      final hiddenSnap = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(uid)
          .collection('rideVisibility')
          .get();

      final hiddenIds = hiddenSnap.docs.map((doc) => doc.id).toSet();

      setState(() {
        _openRides = rides.where((r) {

          final rideType = (r['rideType'] ?? '').toString().toLowerCase();

          if (_captainType != null &&
              rideType != _captainType!.toLowerCase().trim()) {
            return false;
          }

          return !hiddenIds.contains(r['id']);
        }).toList();
      });
      debugPrint("CAPTAIN TYPE = $_captainType");
      debugPrint("RIDES RECEIVED = ${rides.length}");
      _openRidesFailureStreak = 0;
      _openRidesBackoffUntil = null;
      await _rebuildHeatFromVisibleRegion();
    } catch (e) {
      _openRidesFailureStreak++;
      // 6s, 12s, 24s, 48s, capped at 60s
      final delay = (6 * (1 << (_openRidesFailureStreak - 1))).clamp(6, 60);
      _openRidesBackoffUntil = DateTime.now().add(Duration(seconds: delay));
      if (_openRidesFailureStreak <= 2 || _openRidesFailureStreak % 10 == 0) {
        debugPrint('Failed to fetch open rides (streak=$_openRidesFailureStreak, backoff=${delay}s): $e');
      }
    }
  }


  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('userRole'); // Get the saved role from SharedPreferences

    if (role == 'captain') {
      // Logic for captain role
      debugPrint("User is a captain.");
    } else {
      // Logic for other roles
      debugPrint("User is not a captain.");
    }
  }


  Future<void> _loadDriverPhoto() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final snap = await FirebaseFirestore.instance
        .collection('drivers') // ✅ FIX
        .doc(uid)
        .get();

    if (!snap.exists || !mounted) return;

    final data = snap.data();
    final photo = data?['documents']?['profileImage'] ?? data?['photoUrl'];

    if (photo is String && photo.isNotEmpty) {
      setState(() => _driverPhotoUrl = photo);
    }
  }

  // 🔴 FIX: Request location permission before going online
  Future<bool> _ensureLocationPermission() async {
    var status = await Permission.location.status;
    if (status.isDenied) {
      status = await Permission.location.request();
    }
    if (status.isPermanentlyDenied) {
      debugPrint('Location permanently denied - opening settings');
      await openAppSettings();
      return false;
    }
    return status.isGranted;
  }

  Future<void> _debugTokenClaims() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint("❌ No Firebase user logged in");
        return;
      }

      final res = await user.getIdTokenResult(true); // force refresh
      debugPrint("✅ CAPTAIN UID = ${user.uid}");
      debugPrint("✅ TOKEN CLAIMS = ${res.claims}");
    } catch (e) {
      debugPrint("❌ Token claims debug failed: $e");
    }
  }


  // ======================
  // LIFECYCLE
  // ======================
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserRole();  // Call the method to load the role

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initCaptain();
    });
  }

  Future<void> _initCaptain() async {

    // 🔴 FIX: Request location permission on startup
    await _ensureLocationPermission();

    await _debugTokenClaims();
    await _loadCaptainType();
    await _loadOnlineState();
    await _checkReconnect();
    await _loadDriverPhoto();
  }

  Future<void> sendRideNotification() async {
    final granted =
    await NotificationService().debugRequestAndroidPermission();

    if (!granted) {
      await NativeNotificationSettings.open();
      return;
    }

    await NotificationService().show(
      'New Ride 🚕',
      'You have a new ride request',
      {'rideId': '123'},
    );
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ensureNotificationsEnabled(context);
      _loadOnlineState();
    }
  }

  @override
  void dispose() {
    for (final t in _expireTimers.values) {
      t.cancel();
    }
    for (final t in _rideUiTimers.values) {
      t.cancel();
    }
    _rideUiTimers.clear();

    _expireTimers.clear();
    _openPollingTimer?.cancel();
    _openPollingTimer = null;

    WidgetsBinding.instance.removeObserver(this);
    _mapController?.dispose();
    _pulseTimer?.cancel();

    super.dispose();
  }

  // ======================
  // ONLINE STATE
  // ======================
  Future<void> _loadOnlineState() async {
    final online = await _driverService.getOnlineState();
    if (!mounted) return;

    setState(() => isOnline = online);

    // ✅ make polling follow the online state
    if (online) {
      _startOpenPolling();
    } else {
      _stopOpenPolling();
    }
    if (online) {
      _startSlowPulse();
    } else {
      _stopSlowPulse();
    }

  }


  // ======================
  // RECONNECT ACTIVE RIDE
  // ======================
  Future<void> _checkReconnect() async {
    try {
      final ride = await _captainRideApi.getActiveRide();
      if (!mounted) return;

      if (ride != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CaptainRideMapScreen(rideId: ride['id'].toString()),
          ),
        );
      }
    } catch (e) {
      // ✅ Don't crash app if endpoint missing or role rejected
      debugPrint("⚠️ getActiveRide skipped: $e");
    }
  }



  Future<void> _refuseRide(String id) async {
    _expireTimers[id]?.cancel();
    _expireTimers.remove(id);
    final rideId = int.tryParse(id);
    if (rideId == null) return;
    await _captainRideApi.refuseRide(rideId);
  }

  // ======================
  // PER-CAPTAIN OFFER WINDOW (20s)
  // ======================
  void _startExpireTimerIfNeeded(String rideId, String uid) {
    if (_firstSeenAt.containsKey(rideId)) return;

    _firstSeenAt[rideId] = DateTime.now();

    _expireTimers[rideId] = Timer(const Duration(seconds: 20), () async {
      if (!mounted) return;

      // ✅ Hide only for this captain via backend API
      final rideIdInt = int.tryParse(rideId);
      if (rideIdInt != null) {
        await _captainRideApi.expireRide(rideIdInt).catchError((_) {});
      }
    });
  }




  // ======================
  // ACCEPT RIDE
  // ======================
  Future<void> _acceptRide(int rideId) async {
    try {

      final uid = FirebaseAuth.instance.currentUser!.uid;

      /// accept ride via backend (backed mirrors captainUid to Firestore)
      await _captainRideApi.acceptRide(rideId);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CaptainRideMapScreen(
            rideId: rideId.toString(),
          ),
        ),
      );

    } catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Accept failed: $e')),
      );
    }
  }

  String _fmtPrice(String raw) {
    final v = double.tryParse(raw);
    if (v == null) return raw;
    return v.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Stack(
                children: [
                  // Map
                  GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(30.0444, 31.2357),
                      zoom: 12,
                    ),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: false,
                    onMapCreated: (c) async {
                      _mapController = c;
                      await _goToMyLocation();            // auto-center on captain's GPS
                      await _rebuildHeatFromVisibleRegion();
                    },
                    onCameraIdle: () async {
                      await _rebuildHeatFromVisibleRegion();
                    },
                    polygons: _heatPolygons,
                    circles: _hotspotCircles,
                  ),

                  // Online/Offline pill
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 12,
                    child: _OnlineTogglePill(
                      isOnline: isOnline,
                      onGoOnline: () async {
                        if (isOnline) return;

                        // 🔴 FIX: Request location permission first
                        final hasPermission = await _ensureLocationPermission();
                        if (!hasPermission) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Location permission required to go online')),
                          );
                          return;
                        }

                        await _driverService.setOnline(true);
                        if (!mounted) return;
                        setState(() => isOnline = true);
                        _startOpenPolling();
                        _startSlowPulse();
                      },
                      onGoOffline: () async {
                        if (!isOnline) return;
                        await _driverService.setOnline(false);
                        if (!mounted) return;
                        setState(() => isOnline = false);
                        _stopOpenPolling();
                        _stopSlowPulse();
                        _clearHeat();
                      },
                    ),
                  ),

                  // My location button
                  Positioned(
                    right: 14,
                    bottom: _sheetHeight + 14,
                    child: _AnimatedIconButton(
                      icon: Icons.my_location,
                      onTap: _goToMyLocation,
                    ),
                  ),

                  // Draggable sheet
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Builder(
                        builder: (context) {
                          final uid = FirebaseAuth.instance.currentUser!.uid;

                          final hideStream = FirebaseFirestore.instance
                              .collection('drivers')
                              .doc(uid)
                              .collection('rideVisibility')
                              .snapshots();

                          // helpers (avoid long numbers / overflow)
                          String fmtPrice(dynamic v) {
                            final d = (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '');
                            if (d == null) return (v ?? 0).toString();
                            return d.toStringAsFixed(2);
                          }

                          String addrOf(Map<String, dynamic> r, String key) {
                            final direct = r['${key}Addr'];
                            if (direct is String && direct.isNotEmpty) return direct;

                            final obj = r[key];
                            if (obj is Map) {
                              final a = obj['addr'];
                              if (a is String && a.isNotEmpty) return a;
                            }
                            return '---';
                          }

                          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: isOnline ? hideStream : null,
                            builder: (context, hideSnap) {
                              final hiddenIds = <String>{};

                              if (hideSnap.hasData) {
                                for (final d in hideSnap.data!.docs) {
                                  final state = (d.data()['state'] ?? '') as String;
                                  if (state == 'expired' || state == 'refused') {
                                    hiddenIds.add(d.id);
                                  }
                                }
                              }

                              final visibleRides = _openRides.where((r) {
                                final id = (r['id'] ?? '').toString();
                                return id.isNotEmpty && !hiddenIds.contains(id);
                              }).toList();

                              // Start expire timers
                              for (final r in visibleRides) {
                                final id = (r['id'] ?? '').toString();
                                if (id.isNotEmpty) _startExpireTimerIfNeeded(id, uid);
                              }

                              // Start UI countdown timers
                              for (final r in visibleRides) {
                                final id = (r['id'] ?? '').toString();
                                if (id.isNotEmpty) _ensureUiCountdownStarted(id);
                              }

                              final hasRides = isOnline && visibleRides.isNotEmpty;

                              return NotificationListener<DraggableScrollableNotification>(
                                onNotification: (n) {
                                  if (!mounted) return false;
                                  final screenH = MediaQuery.of(context).size.height;
                                  final newHeight = screenH * n.extent;
                                  if ((_sheetHeight - newHeight).abs() > 2) {
                                    setState(() => _sheetHeight = newHeight);
                                  }
                                  return false;
                                },
                                child: DraggableScrollableSheet(
                                  minChildSize: 0.20,
                                  maxChildSize: 0.92,
                                  initialChildSize: hasRides ? 0.42 : 0.28,
                                  snap: true,
                                  snapSizes: const [0.20, 0.42, 0.92],
                                  builder: (context, scrollController) {
                                    return Container(
                                      decoration: const BoxDecoration(
                                        color: AppColors.white,
                                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                        boxShadow: [
                                          BoxShadow(
                                            blurRadius: 16,
                                            offset: Offset(0, -6),
                                            color: Color(0x22000000),
                                          ),
                                        ],
                                      ),

                                      // ✅ One scrollable only
                                      child: CustomScrollView(
                                        controller: scrollController,
                                        slivers: [
                                          SliverToBoxAdapter(
                                            child: Column(
                                              children: [
                                                const SizedBox(height: 10),
                                                Center(
                                                  child: Container(
                                                    width: 44,
                                                    height: 5,
                                                    decoration: BoxDecoration(
                                                      color: Colors.black12,
                                                      borderRadius: BorderRadius.circular(999),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 10),

                                                Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          !isOnline
                                                              ? 'أنت غير متصل'
                                                              : hasRides
                                                              ? 'رحلات متاحة (${visibleRides.length})'
                                                              : 'لا توجد رحلات الآن',
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.w800,
                                                            fontSize: 15,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      if (hasRides)
                                                        _AnimatedTextButton(
                                                          text: 'تحديث',
                                                          onTap: () {
                                                            DraggableScrollableActuator.reset(context);
                                                          },
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                              ],
                                            ),
                                          ),

                                          if (!isOnline || !hasRides)
                                            SliverToBoxAdapter(
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                                child: Text(
                                                  !isOnline
                                                      ? 'قم بتفعيل Online لاستقبال الرحلات.'
                                                      : 'انتظر… سيتم ظهور الرحلات هنا.',
                                                  style: const TextStyle(color: Colors.black54),
                                                ),
                                              ),
                                            )
                                          else ...[
                                            // ✅ Horizontal list ONLY (no duplicated full list)
                                            SliverToBoxAdapter(
                                              child: SizedBox(
                                                height: 176,
                                                child: ListView.separated(
                                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                                  scrollDirection: Axis.horizontal,
                                                  itemCount: visibleRides.length,
                                                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                                                  itemBuilder: (context, i) {
                                                    final r = visibleRides[i];
                                                    final idStr = (r['id'] ?? '').toString();

                                                    final pickup = addrOf(r, 'pickup');
                                                    final drop = addrOf(r, 'drop');
                                                    final price = fmtPrice(r['price'] ?? r['suggestedFare'] ?? 0);

                                                    return _RideHorizontalCard(
                                                      idStr: idStr,
                                                      pickup: pickup,
                                                      drop: drop,
                                                      price: price,
                                                      progress: _progressValue(idStr),
                                                      secondsLeft: _secondsLeft(idStr),
                                                      onAccept: () {
                                                        final rideId = int.tryParse(idStr);
                                                        if (rideId != null) _acceptRide(rideId);
                                                      },
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                            const SliverToBoxAdapter(child: SizedBox(height: 12)),
                                          ],

                                          const SliverToBoxAdapter(child: SizedBox(height: 18)),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }




  // ======================
  // HEADER
  // ======================
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.white,
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CaptainProfileScreen(),
                ),
              );
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isOnline ? AppColors.success : AppColors.divider,
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                backgroundColor: AppColors.lightGray,
                backgroundImage: _driverPhotoUrl != null
                    ? NetworkImage(_driverPhotoUrl!)
                    : null,
                onBackgroundImageError: _driverPhotoUrl != null
                    ? (_, __) {/* swallow: offline or 404 */}
                    : null,
                child: _driverPhotoUrl == null
                    ? const Icon(Icons.person, color: AppColors.mediumGray)
                    : null,
              ),

            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.welcomeCaptain(context),
                  style: AppTextStyles.headline3,
                ),
                Text(
                  isOnline
                      ? AppStrings.readyForRides(context)
                      : AppStrings.goOnlineToStart(context),
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'earnings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CaptainEarningsScreen(),
                  ),
                );
              } else if (value == 'trips') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CaptainTripsScreen(),
                  ),
                );
              } else if (value == 'language') {
                LanguageController.instance.toggleLanguage();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'earnings',
                child: Text(AppStrings.earnings(context)),
              ),
              PopupMenuItem(
                value: 'trips',
                child: Text(AppStrings.trips(context)),
              ),
              PopupMenuItem(
                value: 'language',
                child: Row(
                  children: [
                    const Icon(Icons.language, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      LanguageController.instance.isArabic
                          ? 'English'
                          : 'العربية',
                    ),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.lightGray,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.settings_outlined),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnlineTogglePill extends StatelessWidget {
  final bool isOnline;
  final VoidCallback onGoOnline;
  final VoidCallback onGoOffline;

  const _OnlineTogglePill({
    required this.isOnline,
    required this.onGoOnline,
    required this.onGoOffline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 4),
            color: Color(0x22000000),
          )
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onGoOnline,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isOnline ? Colors.green : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    'ONLINE',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isOnline ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onTap: onGoOffline,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !isOnline ? Colors.red : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    'OFFLINE',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: !isOnline ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _AnimatedIconButton({required this.icon, required this.onTap});

  @override
  State<_AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<_AnimatedIconButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        scale: _down ? 0.92 : 1.0,
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center, // ✅ center icon
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                blurRadius: 10,
                offset: Offset(0, 4),
                color: Color(0x22000000),
              ),
            ],
          ),
          child: Icon(widget.icon, size: 22, color: Colors.black87),
        ),
      ),
    );
  }
}

class _AnimatedTextButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  const _AnimatedTextButton({required this.text, required this.onTap});

  @override
  State<_AnimatedTextButton> createState() => _AnimatedTextButtonState();
}

class _AnimatedTextButtonState extends State<_AnimatedTextButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        scale: _down ? 0.96 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(widget.text, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}
class _RideHorizontalCard extends StatelessWidget {
  final String idStr;
  final String pickup;
  final String drop;
  final String price;
  final double progress;
  final int secondsLeft;
  final VoidCallback onAccept;

  const _RideHorizontalCard({
    super.key,
    required this.idStr,
    required this.pickup,
    required this.drop,
    required this.price,
    required this.progress,
    required this.secondsLeft,
    required this.onAccept,
  });

  double _clamp(double v, double min, double max) {
    if (v < min) return min;
    if (v > max) return max;
    return v;
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    // ✅ responsive card width
    final cardW = _clamp(w * 0.92, 280, 420);

    return SizedBox(
      width: cardW,
      child: LayoutBuilder(
        builder: (context, c) {
          return SizedBox(
            height: c.maxHeight, // ✅ fill list height
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              elevation: 2,
              child: Container(
                width: double.infinity, // ✅ full width inside
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.black12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'رحلة #$idStr',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0x11000000),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$secondsLeft ث',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: const Color(0x11000000),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ✅ flexible area grows/shrinks
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'من: $pickup',
                            maxLines: 2, // ✅ allow 2 lines on small phones
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'إلى: $drop',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'السعر: $price',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 38,
                          child: ElevatedButton(
                            onPressed: onAccept,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFB3261E),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              minimumSize: const Size(0, 38),
                            ),
                            child: const Text('قبول', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

