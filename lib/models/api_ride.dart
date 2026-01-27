class ApiRide {
  final String id;
  final String status; // REQUESTED / ACCEPTED / ARRIVED / STARTED / COMPLETED / CANCELED etc.
  final String riderId;
  final String? captainId;

  final String pickupAddress;
  final String destinationAddress;

  final double pickupLat;
  final double pickupLng;
  final double destinationLat;
  final double destinationLng;

  final String rideType; // economy / premium / etc (whatever your backend uses)
  final double distanceKm;
  final int durationMin;
  final double? price;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ApiRide({
    required this.id,
    required this.status,
    required this.riderId,
    this.captainId,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.destinationLat,
    required this.destinationLng,
    required this.rideType,
    required this.distanceKm,
    required this.durationMin,
    this.price,
    this.createdAt,
    this.updatedAt,
  });

  factory ApiRide.fromJson(Map<String, dynamic> json) {
    double _toDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    int _toInt(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    DateTime? _parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      final s = v.toString();
      try {
        return DateTime.parse(s);
      } catch (_) {
        return null;
      }
    }

    return ApiRide(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      status: (json['status'] ?? 'REQUESTED').toString(),
      riderId: (json['riderId'] ?? json['rider_id'] ?? '').toString(),
      captainId: (json['captainId'] ?? json['captain_id'])?.toString(),
      pickupAddress: (json['pickupAddress'] ?? json['pickup_address'] ?? '').toString(),
      destinationAddress:
      (json['destinationAddress'] ?? json['destination_address'] ?? '').toString(),
      pickupLat: _toDouble(json['pickupLat'] ?? json['pickup_lat']),
      pickupLng: _toDouble(json['pickupLng'] ?? json['pickup_lng']),
      destinationLat: _toDouble(json['destinationLat'] ?? json['destination_lat']),
      destinationLng: _toDouble(json['destinationLng'] ?? json['destination_lng']),
      rideType: (json['rideType'] ?? json['ride_type'] ?? 'economy').toString(),
      distanceKm: _toDouble(json['distanceKm'] ?? json['distance_km']),
      durationMin: _toInt(json['durationMin'] ?? json['duration_min']),
      price: json['price'] == null ? null : _toDouble(json['price']),
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: _parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'riderId': riderId,
      if (captainId != null) 'captainId': captainId,
      'pickupAddress': pickupAddress,
      'destinationAddress': destinationAddress,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'destinationLat': destinationLat,
      'destinationLng': destinationLng,
      'rideType': rideType,
      'distanceKm': distanceKm,
      'durationMin': durationMin,
      if (price != null) 'price': price,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }
}
