import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/theme/app_colors.dart';
import '../core/localization/language_controller.dart';
import '../services/backend_api.dart';
import '../services/client_ride_api.dart';
import 'client_book_ride_screen.dart';
import 'client_active_ride_screen.dart';
import 'client_trips_screen.dart';
import 'client_profile_screen.dart';

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});
  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  GoogleMapController? _mapController;
  LatLng _center = const LatLng(30.0444, 31.2357);
  LatLng? _myLocation;
  bool _locationInitialized = false;
  bool _locationDenied = false;   // shown after user denies permission
  bool _locationPermanentlyDenied = false;
  int _currentIndex = 0;
  final _rideApi = ClientRideApi(BackendApi());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLocation();
      _checkActiveRide();
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        if (mounted) setState(() { _locationDenied = true; _locationPermanentlyDenied = true; });
        return;
      }
      if (perm == LocationPermission.denied) {
        if (mounted) setState(() => _locationDenied = true);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      final loc = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _myLocation = loc;
        _center = loc;
        _locationInitialized = true;
        _locationDenied = false;
        _locationPermanentlyDenied = false;
      });
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(loc, 15));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحديد الموقع: $e')),
        );
      }
    }
  }

  Future<void> _checkActiveRide() async {
    try {
      final ride = await _rideApi.getActiveRide();
      if (ride != null && mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => ClientActiveRideScreen(rideId: ride['id'].toString()),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر التحقق من الرحلة النشطة: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: IndexedStack(index: _currentIndex, children: [
        _buildHomeTab(),
        const ClientTripsScreen(),
        const ClientProfileScreen(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primaryLight,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: AppColors.primary), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history, color: AppColors.primary), label: 'رحلاتي'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person, color: AppColors.primary), label: 'حسابي'),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    return Stack(children: [
      // ── Location permission denied banner ──
      if (_locationDenied)
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            bottom: false,
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.warning),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_off_outlined, color: AppColors.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _locationPermanentlyDenied
                          ? 'الموقع محظور نهائيًا. افتح إعدادات التطبيق للسماح به.'
                          : 'يحتاج التطبيق إذن الوصول للموقع لعرض رحلات قريبة منك.',
                      style: const TextStyle(fontSize: 12, color: AppColors.darkGray),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      if (_locationPermanentlyDenied) {
                        await Geolocator.openAppSettings();
                      } else {
                        await _initLocation();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _locationPermanentlyDenied ? 'الإعدادات' : 'السماح',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

      GoogleMap(
        initialCameraPosition: CameraPosition(target: _center, zoom: 14),
        myLocationEnabled: true, myLocationButtonEnabled: false, zoomControlsEnabled: false,
        onMapCreated: (c) {
          _mapController = c;
          if (_myLocation != null) c.animateCamera(CameraUpdate.newLatLngZoom(_myLocation!, 15));
        },
        onCameraMove: (pos) {
          if (!_locationInitialized) {
            _center = pos.target;
          }
        },
      ),

      // Header
      SafeArea(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(50),
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 10)]),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.directions_car, color: Colors.white, size: 18),
              SizedBox(width: 6),
              Text('DosaDriver', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
            ]),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => LanguageController.instance.toggleLanguage(),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.92), borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8)]),
              child: const Icon(Icons.language, size: 20, color: Color(0xFF212121)),
            ),
          ),
        ]),
      )),

      // My location button
      Positioned(right: 16, bottom: 220, child: GestureDetector(
        onTap: () {
          if (_myLocation != null) _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_myLocation!, 15));
          else _initLocation();
        },
        child: Container(width: 48, height: 48,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))]),
          child: const Icon(Icons.my_location, color: AppColors.primary, size: 22)),
      )),

      // Bottom booking card
      Positioned(left: 0, right: 0, bottom: 0, child: Container(
        decoration: const BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 20, offset: Offset(0, -6))]),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(99))),

          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser?.uid).snapshots(),
            builder: (ctx, snap) {
              final data = snap.hasData && snap.data!.exists
                  ? snap.data!.data() as Map<String, dynamic>?
                  : null;
              final name = data?['name']?.toString() ?? 'مستخدم';
              return Align(alignment: Alignment.centerRight,
                  child: Text('مرحباً $name 👋', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)));
            },
          ),
          const SizedBox(height: 4),
          const Align(alignment: Alignment.centerRight,
              child: Text('إلى أين تريد الذهاب؟', style: TextStyle(color: Colors.grey, fontSize: 13))),
          const SizedBox(height: 14),

          // Search bar
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => ClientBookRideScreen(initialPickup: _myLocation),
            )).then((_) => _checkActiveRide()),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE0E0E0))),
              child: const Row(children: [
                Icon(Icons.search, color: Colors.grey),
                SizedBox(width: 10),
                Text('ابحث عن وجهتك...', style: TextStyle(color: Colors.grey, fontSize: 15)),
              ]),
            ),
          ),
          const SizedBox(height: 14),

          // Quick ride type chips
          Row(children: [
            _RideChip(label: '🚖 عادل',    type: 'FAIR_VALUE', onTap: _openWithType),
            const SizedBox(width: 8),
            _RideChip(label: '🏆 بريميوم', type: 'PREMIUM',    onTap: _openWithType),
            const SizedBox(width: 8),
            _RideChip(label: '🚙 كيوت كار',type: 'CUTE_CAR',  onTap: _openWithType),
            const SizedBox(width: 8),
            _RideChip(label: '🛵 سكوتر',   type: 'SCOOTER',   onTap: _openWithType),
          ]),
        ]),
      )),
    ]);
  }

  void _openWithType(String type) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ClientBookRideScreen(initialPickup: _myLocation, preselectedType: type),
    )).then((_) => _checkActiveRide());
  }
}

class _RideChip extends StatelessWidget {
  final String label, type;
  final void Function(String) onTap;
  const _RideChip({required this.label, required this.type, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: () => onTap(type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0E0E0))),
        child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    ),
  );
}
