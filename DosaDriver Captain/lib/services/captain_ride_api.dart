import 'backend_api.dart';

/// All captain ride endpoints — mirrors backend rides.controller.ts exactly
class CaptainRideApi {
  final BackendApi _api;
  CaptainRideApi(this._api);

  Future<List<Map<String, dynamic>>> getOpenRides([String? rideType]) async {
    final query = rideType != null && rideType.isNotEmpty ? '?rideType=$rideType' : '';
    final res = await _api.get('/v1/captain/rides/open$query');
    return ((res['rides'] as List?) ?? []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> acceptRide(int rideId) async {
    final res = await _api.post('/v1/rides/$rideId/accept');
    return (res['ride'] as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>?> getActiveRide() async {
    final res = await _api.get('/v1/captain/rides/active');
    final ride = res['ride'];
    return ride is Map<String, dynamic> ? ride : null;
  }

  Future<Map<String, dynamic>> arrive(int rideId) async {
    final res = await _api.post('/v1/rides/$rideId/arrive');
    return (res['ride'] as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> start(int rideId) async {
    final res = await _api.post('/v1/rides/$rideId/start');
    return (res['ride'] as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> complete(int rideId) async {
    final res = await _api.post('/v1/rides/$rideId/complete');
    return (res['ride'] as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> confirmTransfer(int rideId) async {
    final res = await _api.post('/v1/rides/$rideId/confirm-transfer');
    return (res['ride'] as Map<String, dynamic>?) ?? {};
  }

  Future<void> cancelCaptain(int rideId) async {
    await _api.post('/v1/rides/$rideId/cancel/captain');
  }

  Future<void> refuseRide(int rideId) async {
    await _api.post('/v1/rides/$rideId/refuse');
  }

  Future<void> expireRide(int rideId) async {
    await _api.post('/v1/rides/$rideId/expire');
  }

  Future<Map<String, dynamic>> getHistory({int page = 1, int limit = 20}) async {
    final res = await _api.get('/v1/captain/rides/history?page=$page&limit=$limit');
    return res;
  }

  Future<Map<String, dynamic>> getEarnings() async {
    return _api.get('/v1/captain/earnings');
  }
}
