import '../models/pricing_model.dart';

class FareCalculator {
  static double calculate({
    required Pricing pricing,
    required double distanceKm,
    required double multiplier,
  }) {
    final basePrice = pricing.baseFare + (distanceKm * pricing.perKm);
    final finalPrice = basePrice * multiplier;

    // Always round UP (ride-hailing standard)
    return finalPrice.ceilToDouble();
  }
}
