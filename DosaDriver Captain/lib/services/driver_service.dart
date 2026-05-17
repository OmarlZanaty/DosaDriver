import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class DriverService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // =========================
  // LOCATION STREAM
  // =========================
  Stream<Position> locationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // meters
      ),
    );
  }

  Future<void> updateLocation(Position position) async {
    final uid = _auth.currentUser!.uid;

    await _firestore.collection('drivers').doc(uid).set({
      'lat': position.latitude,
      'lng': position.longitude,
      'lastLocationAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Also write to captains_live for rider location tracking
    await _firestore.collection('captains_live').doc(uid).set({
      'lat': position.latitude,
      'lng': position.longitude,
      'lastLocationAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // =========================
  // ONLINE STATUS (SOURCE OF TRUTH)
  // =========================
  Future<void> setOnline(bool online) async {
    final uid = _auth.currentUser!.uid;

    await _firestore.collection('drivers').doc(uid).set({
      'online': online,
      'isOnline': online,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

  }

  // =========================
  // READ ONLINE STATE
  // =========================
  Future<bool> getOnlineState() async {
    final uid = _auth.currentUser!.uid;

    final doc =
    await _firestore.collection('drivers').doc(uid).get();

    if (!doc.exists) return false;

    final data = doc.data() ?? {};
    return (data['isOnline'] ?? data['online'] ?? false) == true;
  }
}
