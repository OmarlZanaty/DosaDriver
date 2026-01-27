import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pricing_model.dart';

class PricingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch pricing for selected ride type
  Future<Pricing> getPricing(String rideType) async {
    final doc = await _firestore
        .collection('pricing')      // ✅ CORRECT
        .doc(rideType)              // premium / economic / scooter
        .get();

    if (!doc.exists || doc.data() == null) {
      throw Exception('Pricing not found for $rideType');
    }

    return Pricing.fromMap(doc.data()!);
  }

  /// Fetch surge multiplier (admin controlled)
  Future<double> getSurgeMultiplier() async {
    final doc = await _firestore
        .collection('app_config')   // ✅ CORRECT
        .doc('surge')
        .get();

    final data = doc.data();
    if (data == null || data['enabled'] != true) {
      return 1.0;
    }

    return (data['multiplier'] as num).toDouble();
  }
}
