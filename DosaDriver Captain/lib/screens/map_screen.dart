import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
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
        ],
      ),
    );
  }
}
