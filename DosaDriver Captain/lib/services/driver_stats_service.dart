import 'package:cloud_firestore/cloud_firestore.dart';

class DriverStatsService {

  static Future<Map<String, dynamic>> getDriverStats(String captainId) async {

    final rides = await FirebaseFirestore.instance
        .collection('rides')
        .where('captainId', isEqualTo: captainId)
        .get();

    double totalEarnings = 0;
    int tripsToday = 0;
    int tripsWeek = 0;
    int accepted = 0;
    int cancelled = 0;

    final now = DateTime.now();

    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    for (var doc in rides.docs) {

      final data = doc.data();

      final status = (data['status'] ?? '').toString().toLowerCase();

      final price = (data['price'] ?? 0).toDouble();

      // Backend mirror doesn't write completedAt; fall back to updatedAt or createdAt
      final completedAt = (data['completedAt'] as Timestamp?)?.toDate()
          ?? (data['updatedAt'] as Timestamp?)?.toDate()
          ?? (data['createdAt'] as Timestamp?)?.toDate();

      if (status == "completed") {

        totalEarnings += price;

        if (completedAt != null && completedAt.isAfter(startOfDay)) {
          tripsToday++;
        }

        if (completedAt != null && completedAt.isAfter(startOfWeek)) {
          tripsWeek++;
        }

        accepted++;
      }

      if (status.contains("cancel")) {
        cancelled++;
      }
    }

    final totalRequests = accepted + cancelled;

    double acceptanceRate =
    totalRequests == 0 ? 0 : (accepted / totalRequests) * 100;

    double cancelRate =
    totalRequests == 0 ? 0 : (cancelled / totalRequests) * 100;

    return {
      "earnings": totalEarnings,
      "todayTrips": tripsToday,
      "weekTrips": tripsWeek,
      "acceptRate": acceptanceRate,
      "cancelRate": cancelRate,
    };
  }
}