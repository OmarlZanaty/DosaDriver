import 'backend_api.dart';

class ClientRideApi {
  final BackendApi _api;
  ClientRideApi(this._api);

  /// FIX: Fare calculated server-side — client sends distance/duration, receives fare
  Future<Map<String, dynamic>> getFareEstimate({
    required String type,
    required double distanceKm,
    required double durationMin,
  }) async {
    final res = await _api.get(
      '/v1/fare-estimate?type=$type&distanceKm=$distanceKm&durationMin=$durationMin',
    );
    return res;
  }

  /// FIX: No Firestore write from client — backend is sole writer
  Future<Map<String, dynamic>> createRide({
    required double pickupLat, required double pickupLng,
    required double dropLat,   required double dropLng,
    required String pickupAddr, required String dropAddr,
    required String rideType,
    required double distanceKm, required double durationMin,
    String paymentMethod = 'CASH',
  }) async {
    final res = await _api.post('/v1/rides', body: {
      'pickupLat': pickupLat, 'pickupLng': pickupLng, 'pickupAddr': pickupAddr,
      'dropLat':   dropLat,   'dropLng':   dropLng,   'dropAddr':   dropAddr,
      'type':           rideType,
      'distanceKm':     distanceKm,
      'durationMin':    durationMin,
      'paymentMethod':  paymentMethod,
    });
    return (res['ride'] as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>?> getActiveRide() async {
    final res = await _api.get('/v1/rides/active');
    final ride = res['ride'];
    return ride is Map<String, dynamic> ? ride : null;
  }

  Future<void> cancelRide(int rideId) async {
    await _api.post('/v1/rides/$rideId/cancel');
  }

  Future<Map<String, dynamic>> getHistory({int page = 1, int limit = 20}) async {
    return _api.get('/v1/rides/history?page=$page&limit=$limit');
  }

  Future<void> rateRide(int rideId, {required int rating, String? comment}) async {
    await _api.post('/v1/rides/$rideId/rate', body: {
      'rating': rating,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
  }

  Future<void> submitTransferProof(int rideId, String proofUrl) async {
    await _api.post('/v1/rides/$rideId/transfer-proof', body: {'proofUrl': proofUrl});
  }
}
