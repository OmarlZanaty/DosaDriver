/*
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import '../core/ride/ride_status.dart';

class RideService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // ======================
  // WAITING RIDES (CAPTAIN)
  // ======================
  Stream<QuerySnapshot<Map<String, dynamic>>> waitingRides() {
    return _firestore
        .collection('rides')
        .where('status', whereIn: ['requested', 'REQUESTED'])
        .snapshots();
  }


  // ======================
  // ACTIVE RIDE RECONNECT
  // ======================
  Future<String?> getActiveRideIdForCaptain(String uid) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('rides')
          .where('driverId', isEqualTo: uid)
          .where('status', whereIn: [
        'accepted', 'on_the_way', 'arrived',
        'ACCEPTED', 'ON_THE_WAY', 'ARRIVED',
        'started', 'STARTED', // in case some docs use started
      ])
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return null;
      return snap.docs.first.id;
    } catch (e) {
      // 🔥 IMPORTANT: do NOT crash home screen
      debugPrint('Reconnect skipped: $e');
      return null;
    }
  }

}
*/
