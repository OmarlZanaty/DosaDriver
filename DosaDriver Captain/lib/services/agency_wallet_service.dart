import 'package:cloud_firestore/cloud_firestore.dart';

class AgencyWalletService {

  static Future<void> addCommission({
    required String agencyId,
    required String rideId,
    required double price,
    required int percent,
  }) async {

    final commission = price * percent / 100;

    final db = FirebaseFirestore.instance;

    final agencyRef = db.collection('agencies').doc(agencyId);

    await db.runTransaction((tx) async {

      final agencySnap = await tx.get(agencyRef);

      final currentBalance =
      (agencySnap.data()?['walletBalance'] ?? 0).toDouble();

      tx.update(agencyRef, {
        "walletBalance": currentBalance + commission
      });

      final transactionRef =
      db.collection('agency_wallet_transactions').doc();

      tx.set(transactionRef, {
        "agencyId": agencyId,
        "rideId": rideId,
        "amount": commission,
        "type": "commission",
        "createdAt": FieldValue.serverTimestamp()
      });

    });
  }
}