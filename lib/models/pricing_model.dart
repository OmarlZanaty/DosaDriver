class Pricing {
  final double baseFare;
  final double perKm;
  final double perMin;

  Pricing({
    required this.baseFare,
    required this.perKm,
    required this.perMin,
  });

  factory Pricing.fromMap(Map<String, dynamic> data) {
    return Pricing(
      baseFare: (data['baseFare'] as num).toDouble(),
      perKm: (data['perKm'] as num).toDouble(),
      perMin: (data['perMin'] as num).toDouble(),
    );
  }
}
