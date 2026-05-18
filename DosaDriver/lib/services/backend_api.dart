import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class BackendApi {
  static const String baseUrl =
      'https://dosadriver-api-1056710019958.me-central1.run.app';

  static const Duration _timeout = Duration(seconds: 20);

  /// FIX: null-safe currentUser — throws readable error instead of crashing
  Future<String> _getToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('انتهت الجلسة. يرجى تسجيل الدخول مجدداً.');
    try {
      return await user.getIdToken() ?? '';
    } catch (e) {
      throw Exception('فشل التحقق من الهوية. يرجى المحاولة مرة أخرى.');
    }
  }

  Future<Map<String, dynamic>> get(String path) async {
    final token = await _getToken();
    final res = await http
        .get(
          Uri.parse('$baseUrl$path'),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        )
        .timeout(_timeout);
    return _parse(res);
  }

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body}) async {
    final token = await _getToken();
    final res = await http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          body: jsonEncode(body ?? {}),
        )
        .timeout(_timeout);
    return _parse(res);
  }

  Future<Map<String, dynamic>> patch(String path, {Map<String, dynamic>? body}) async {
    final token = await _getToken();
    final res = await http
        .patch(
          Uri.parse('$baseUrl$path'),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          body: jsonEncode(body ?? {}),
        )
        .timeout(_timeout);
    return _parse(res);
  }

  Future<void> registerPushToken(String token) async {
    if (token.isEmpty) return;
    await post('/v1/notifications/register', body: {'token': token});
  }

  Map<String, dynamic> _parse(http.Response res) {
    final text = res.body.isEmpty ? '{}' : res.body;
    Map<String, dynamic> json;
    try {
      json = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('خطأ في تحليل الاستجابة');
    }
    if (res.statusCode >= 400) {
      final msg = json['message'] ?? json['error'] ?? 'خطأ ${res.statusCode}';
      throw Exception(msg is List ? (msg as List).join(', ') : msg.toString());
    }
    return json;
  }
}
