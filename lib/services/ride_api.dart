import 'dart:convert';

import '../models/api_ride.dart';
import 'api_client.dart';

class RideApi {
  RideApi(this._client);

  final ApiClient _client;

  /// GET /v1/rides/active
  /// returns active ride or 404 / null if none.
  Future<ApiRide?> getActiveRide() async {
    final res = await _client.request('GET', '/rides/active');

    if (res.statusCode == 404) return null;

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('GET /rides/active failed: ${res.statusCode} ${res.body}');
    }

    final decoded = json.decode(res.body);
    if (decoded == null) return null;

    Map<String, dynamic>? rideJson;

    if (decoded is Map<String, dynamic>) {
      // ✅ handle { ok: true, ride: null }
      if (decoded.containsKey('ride') && decoded['ride'] == null) {
        return null;
      }
      if (decoded.containsKey('data') && decoded['data'] == null) {
        return null;
      }

      if (decoded['ride'] is Map<String, dynamic>) {
        rideJson = decoded['ride'] as Map<String, dynamic>;
      } else if (decoded['data'] is Map<String, dynamic>) {
        rideJson = decoded['data'] as Map<String, dynamic>;
      } else {
        // ⚠️ only accept direct object if it looks like a ride
        if (decoded.containsKey('id') || decoded.containsKey('status')) {
          rideJson = decoded;
        } else {
          return null; // ✅ don't treat {ok:true,...} as a ride
        }
      }
    }


    // Backend might return { ride: {...} } or { data: {...} } or direct object
    if (decoded is Map<String, dynamic>) {
      if (decoded['ride'] is Map<String, dynamic>) {
        rideJson = decoded['ride'] as Map<String, dynamic>;
      } else if (decoded['data'] is Map<String, dynamic>) {
        rideJson = decoded['data'] as Map<String, dynamic>;
      } else {
        rideJson = decoded;
      }
    }

    if (rideJson == null) return null;
    // Defensive: backend sometimes returns object with empty id
    final id = (rideJson['id'] ?? '').toString().trim();
    if (id.isEmpty) {
      // keep returning a ride object (UI will ignore), but log it for debugging
      // ignore: avoid_print
      print('⚠️ getActiveRide returned ride with empty id: $rideJson');
    }

    return ApiRide.fromJson(rideJson);
  }

  /// POST /v1/rides
  Future<ApiRide> createRide({
    required String pickupAddress,
    required String destinationAddress,
    required double pickupLat,
    required double pickupLng,
    required double destinationLat,
    required double destinationLng,
    required String rideType,
    required double distanceKm,
    required int durationMin,
    double? price,
    String? riderPhone,
  }) async {
    final body = <String, dynamic>{
      'pickupAddress': pickupAddress,
      'destinationAddress': destinationAddress,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,

      // ✅ Option A (flat) — backend expects these:
      'dropLat': destinationLat,
      'dropLng': destinationLng,
      'destinationLat': destinationLat,
      'destinationLng': destinationLng,

      ''rideType': rideType,
    'distanceKm': distanceKm,
    'durationMin': durationMin,
    if (riderPhone != null && riderPhone.trim().isNotEmpty)
      '  'riderPhone': riderPhone.trim(),
    }
    
        // Set price or suggested fare based on ride type
    if (price != null) {
      if (rideType == 'fair_value') {
        body['suggestedFare'] = price;
      } else {
        body['price'] = price;
      
    
;

    final res = await _client.request('POST', '/rides', jsonBody: body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('POST /rides failed: ${res.statusCode} ${res.body}');
    }

    final decoded = json.decode(res.body);

    Map<String, dynamic>? rideJson;
    if (decoded is Map<String, dynamic>) {
      if (decoded['ride'] is Map<String, dynamic>) {
        rideJson = decoded['ride'] as Map<String, dynamic>;
      } else if (decoded['data'] is Map<String, dynamic>) {
        rideJson = decoded['data'] as Map<String, dynamic>;
      } else {
        rideJson = decoded;
      }
    }

    if (rideJson == null) {
      throw Exception('POST /rides unexpected response: ${res.body}');
    }

    return ApiRide.fromJson(rideJson);
  }

  /// POST /v1/rides/:id/cancel
  /// POST /v1/rides/:id/cancel
  Future<void> cancelRide(String rideId) async {
    final id = rideId.trim();
    if (id.isEmpty) {
      throw ArgumentError('cancelRide: rideId is empty');
    }

    final res = await _client.request('POST', '/rides/$id/cancel');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'POST /rides/$id/cancel failed: ${res.statusCode} ${res.body}',
      );
    }
  }

}
