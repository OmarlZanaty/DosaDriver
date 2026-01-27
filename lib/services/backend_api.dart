import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class BackendApi {
  // TODO: put your Cloud Run URL here
  static const String baseUrl =
      'https://dosadriver-api-1056710019958.me-central1.run.app';

  Future<Map<String, dynamic>> _get(String path) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    final res = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> _post(String path, [Map<String, dynamic>? body]) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(res);
  }

  Map<String, dynamic> _decode(http.Response res) {
    final dynamic j = jsonDecode(res.body.isEmpty ? '{}' : res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return (j is Map<String, dynamic>) ? j : {'ok': true, 'data': j};
    }
    final msg = (j is Map && j['message'] != null) ? j['message'].toString() : res.body;
    throw Exception('HTTP ${res.statusCode}: $msg');
  }

  // -------- RIDES --------

  /// FIX for your log bug: backend returns { ok:true, ride:null }
  Future<int?> getActiveRideId() async {
    final j = await _get('/rides/active');
    final ride = j['ride'];
    if (ride == null) return null;
    if (ride is Map && ride['id'] != null) return (ride['id'] as num).toInt();
    return null;
  }

  Future<int> createRide({
    required double pickupLat,
    required double pickupLng,
    required double dropLat,
    required double dropLng,
    String? pickupAddr,
    String? dropAddr,
  }) async {
    final j = await _post('/rides', {
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'pickupAddr': pickupAddr,
      'dropLat': dropLat,
      'dropLng': dropLng,
      'dropAddr': dropAddr,
    });
    final ride = j['ride'] as Map<String, dynamic>;
    return (ride['id'] as num).toInt();
  }

  Future<void> cancelRide(int rideId) async {
    await _post('/rides/$rideId/cancel');
  }
}
