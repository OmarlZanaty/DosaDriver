import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/ride/ride_status.dart';

class CancellationService {
  final _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> getSettings() async {
    final doc = await _firestore
        .collection('settings')
        .doc('cancellation')
        .get();

    return doc.data() ?? {};
  }


  Future<double> getPendingPenalty(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    if (!doc.exists) return 0.0;

    return (doc.data()?['pendingPenalty'] ?? 0).toDouble();
  }

  double calculateFee({
    required DateTime createdAt,
    required String status,
    required Map<String, dynamic> settings,
  }) {
    final now = DateTime.now();
    final diffMinutes = now.difference(createdAt).inMinutes;

    final freeMinutesRaw = settings['freeMinutes'];
    final freeCancelSecondsRaw = settings['freeCancelSeconds'];

    final int freeMinutes = freeMinutesRaw is num
        ? freeMinutesRaw.toInt()
        : (freeCancelSecondsRaw is num ? (freeCancelSecondsRaw.toInt() ~/ 60) : 3);


    final double beforeAcceptFee =
        (settings['beforeAcceptFee'] as num?)?.toDouble() ?? 0.0;

    final double afterAcceptFee =
        (settings['afterAcceptFee'] as num?)?.toDouble() ?? 0.0;

    final double afterArrivalFee =
        (settings['afterArrivalFee'] as num?)?.toDouble() ?? 0.0;

    // ⏱ Free cancellation window
    if (diffMinutes <= freeMinutes) return 0.0;

    final st = rideStatusFromAny(status);

// 🟡 Client cancels before captain accepts
    if (st == RideStatus.requested) {
      return beforeAcceptFee;
    }

// 🔵 Captain accepted
    if (st == RideStatus.accepted) {
      return afterAcceptFee;
    }

// 🔴 Captain arrived
    if (st == RideStatus.arrived) {
      return afterArrivalFee;
    }

    return 0.0;

    return 0.0;
  }

}
