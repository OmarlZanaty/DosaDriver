import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';
//import '../models/ride_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/ride_state_guard.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ==================== CLIENT METHODS ====================

  /// Create ride request - NEW VERSION with address strings
  /// This is the new method that sends address strings to captain
  Future<String> createRideRequestNew({
    required String clientId,
    required String pickupAddress,
    required String destinationAddress,
    required LatLng pickupLatLng,
    required LatLng destinationLatLng,
    required double estimatedFare,
    required String rideType,
    required double appliedMultiplier,

    // 🔥 REQUIRED BY CAPTAIN APP
    required double distanceKm,
    required int durationMin,
  }) async {

    final DocumentReference docRef = _db.collection('rides').doc();

    await docRef.set({
      // 👤 CLIENT
      'clientId': clientId,

      'clientName': FirebaseAuth.instance.currentUser?.displayName ?? 'Client',
      'clientPhone': FirebaseAuth.instance.currentUser?.phoneNumber,
      // 📍 ADDRESSES
      'pickupAddress': pickupAddress,
      'destinationAddress': destinationAddress,

      // 🌍 COORDINATES
      'pickupLat': pickupLatLng.latitude,
      'pickupLng': pickupLatLng.longitude,
      'destinationLat': destinationLatLng.latitude,
      'destinationLng': destinationLatLng.longitude,

      // 🚗 RIDE INFO (🔥 THIS IS WHAT CAPTAIN NEEDS)
      'rideType': rideType,
      'price': estimatedFare,
      'distanceKm': double.parse(distanceKm.toStringAsFixed(2)),
      'duration': durationMin,

      // 🚦 IMPORTANT
      'status': 'requested',

      // ⏱️ TIMESTAMPS
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }




  /// Stream single ride by ID
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamRideNew(String rideId) {
    return _db.collection('rides').doc(rideId).snapshots();
  }



  /// Cancel ride by client
  Future<void> cancelRideByClient(String rideId) async {
    await _db.collection('rides').doc(rideId).update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }

  // ==================== CAPTAIN METHODS ====================

  /// Toggle captain online status
  Future<void> toggleOnline(String uid, bool isOnline) async {
    await _db.collection('users').doc(uid).set({
      'online': isOnline,
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Stream waiting rides for captains (NEW)
  Stream<QuerySnapshot<Map<String, dynamic>>> waitingRides() {
    return _db
        .collection('rides')
        .where('status', isEqualTo: 'requested')
        .snapshots();
  }



  /// Accept ride - NEW VERSION with transaction safety
  Future<void> acceptRideNew({
    required String rideId,
    required String captainId,
  }) async {
    await _db.runTransaction((transaction) async {
      DocumentReference rideRef = _db.collection('rides').doc(rideId);
      DocumentSnapshot snapshot = await transaction.get(rideRef);

      if (!snapshot.exists) {
        throw Exception('Ride not found');
      }

      final data = snapshot.data() as Map<String, dynamic>;
      final currentStatus = data['status'];

      if (currentStatus != 'requested') {
        throw Exception(
          'Ride is no longer available (Status: $currentStatus)',
        );
      }

      transaction.update(rideRef, {
        'captainId': captainId,
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // Update captain's active ride
      transaction.update(_db.collection('users').doc(captainId), {
        'activeRideId': rideId, // or null for cancel
        'updatedAt': FieldValue.serverTimestamp(),
      });

    });
  }

  /// Update ride status
  Future<void> updateRideStatus(String rideId, String newStatus) async {
    final rideRef = _db.collection('rides').doc(rideId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(rideRef);
      if (!snap.exists) {
        throw StateError('Ride not found');
      }

      final data = snap.data() as Map<String, dynamic>;
      final currentStatus = (data['status'] ?? 'requested').toString();

      RideStateGuard.assertCanTransition(currentStatus, newStatus);

      tx.update(rideRef, {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Mark ride as on the way
  Future<void> markRideOnTheWay(String rideId) async {
    await updateRideStatus(rideId, 'on_the_way');
  }

  /// Mark ride as arrived
  Future<void> markRideArrived(String rideId) async {
    await updateRideStatus(rideId, 'arrived');
  }

  /// Complete ride
  Future<void> completeRide(String rideId) async {
    final rideRef = _db.collection('rides').doc(rideId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(rideRef);
      if (!snap.exists) throw StateError('Ride not found');

      final data = snap.data() as Map<String, dynamic>;
      final currentStatus = (data['status'] ?? 'requested').toString();

      RideStateGuard.assertCanTransition(currentStatus, 'completed');

      tx.update(rideRef, {
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }


  /// Cancel ride by captain
  Future<void> cancelRideByCaptain(String rideId, String captainId) async {
    await _db.runTransaction((transaction) async {
      DocumentReference rideRef = _db.collection('rides').doc(rideId);

      transaction.update(rideRef, {
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      // Clear captain's active ride
      transaction.update(_db.collection('users').doc(captainId), {
        'activeRideId': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

    });
  }

  // ==================== SHARED METHODS ====================

  /// Get ride details
  Future<Map<String, dynamic>?> getRideDetails(String rideId) async {
    try {
      final doc = await _db.collection('rides').doc(rideId).get();
      return doc.data();
    } catch (e) {
      print('❌ Error getting ride details: $e');
      return null;
    }
  }

  /// Get captain details
  Future<Map<String, dynamic>?> getCaptainDetails(String captainId) async {
    try {
      final doc = await _db.collection('users').doc(captainId).get();
      return doc.data();
    } catch (e) {
      print('❌ Error getting captain details: $e');
      return null;
    }
  }

  /// Stream captain location
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamCaptainLocation(
      String captainId,
      ) {
    return _db.collection('users').doc(captainId).snapshots();
  }

  /// Update captain location
  Future<void> updateCaptainLocation(String captainId, LatLng location) async {
    await _db.collection('users').doc(captainId).update({
      'lat': location.latitude,
      'lng': location.longitude,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Calculate distance between two coordinates using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadiusKm = 6371.0;

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  /// Convert degrees to radians
  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }
}
