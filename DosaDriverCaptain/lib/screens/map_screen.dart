import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/theme/app_colors.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionStream;

  LatLng _currentLatLng = const LatLng(31.2001, 29.9187);
  bool _isOnline = false;
  bool _verifiedCaptain = false;

  @override
  void initState() {
    super.initState();
    _verifyCaptain();
  }

  /// 1️⃣ Verify this account is a CAPTAIN
  Future<void> _verifyCaptain() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = FirebaseFirestore.instance
        .collection('drivers')
        .doc(uid);

    if (!doc.exists) {
      await ref.set({
        'uid': uid,
        'email': FirebaseAuth.instance.currentUser?.email ?? '',
        'approved': false,
        'documentsUploaded': false,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // ✅ IMPORTANT
      // DO NOT sign out
      // Just return and let CaptainStatusGate handle the state
      return;
    }

    if (!mounted) return;
    setState(() => _verifiedCaptain = true);
  }

  /// 2️⃣ Toggle ONLINE / OFFLINE
  Future<void> _toggleOnline(bool value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isOnline = value);

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'online': value});

    if (value) {
      _startLocationTracking();
    } else {
      await _stopLocationTracking();
    }
  }

  /// Animate map camera to the captain's current GPS position.
  Future<void> _goToMyLocation() async {
    if (_mapController == null) return;
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) { return; }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentLatLng = LatLng(pos.latitude, pos.longitude);
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentLatLng, zoom: 16),
        ),
      );
    } catch (e) {
      debugPrint('GoToMyLocation error: $e');
    }
  }

  /// 3️⃣ Start live location ONLY when online
  Future<void> _startLocationTracking() async {
    await Geolocator.requestPermission();

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 10,
      ),
    ).listen((position) async {
      _currentLatLng = LatLng(position.latitude, position.longitude);

      _mapController?.animateCamera(
        CameraUpdate.newLatLng(_currentLatLng),
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null && _isOnline) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'lat': position.latitude,
          'lng': position.longitude,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> _stopLocationTracking() async {
    await _positionStream?.cancel();
    _positionStream = null;
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_verifiedCaptain) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentLatLng,
              zoom: 15,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // replaced by custom button below
            zoomControlsEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
              // Auto-center on the captain's real GPS position at startup
              _goToMyLocation();
            },
          ),

          /// ONLINE / OFFLINE SWITCH
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Card(
              elevation: 6,
              child: SwitchListTile(
                title: Text(
                  _isOnline ? 'ONLINE' : 'OFFLINE',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _isOnline ? Colors.green : Colors.red,
                  ),
                ),
                value: _isOnline,
                onChanged: _toggleOnline,
              ),
            ),
          ),

          /// CURRENT LOCATION BUTTON (bottom-right)
          Positioned(
            right: 16,
            bottom: 32,
            child: FloatingActionButton.small(
              heroTag: 'map_screen_location',
              onPressed: _goToMyLocation,
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              tooltip: 'موقعي الحالي',
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}
