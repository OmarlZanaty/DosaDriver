import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BackendApi {
  static const String baseUrl =
      'http://35.222.75.137:8080';

  static const Duration _timeout = Duration(seconds: 20);

  /// FIX: null-safe currentUser — retries with forceRefresh before failing
  Future<String> _getToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('انتهت الجلسة. يرجى تسجيل الدخول مجدداً.');
    // Try cached token first (fast path, works offline).
    try {
      final t = await user.getIdToken(false);
      if (t != null && t.isNotEmpty) return t;
    } catch (_) {
      // fall through to force-refresh
    }
    // Force refresh — handles expired tokens / clock skew.
    try {
      final t = await user.getIdToken(true);
      if (t != null && t.isNotEmpty) return t;
      throw Exception('empty token');
    } catch (e) {
      if (kDebugMode) debugPrint('getIdToken failed: $e');
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
    } catch (e) {
      debugPrint('[BackendApi] JSON parse error: $e');
      debugPrint('[BackendApi] Status ${res.statusCode}, body: ${res.body.length > 500 ? res.body.substring(0, 500) : res.body}');
      throw Exception('خطأ في تحليل الاستجابة (${res.statusCode})');
    }
    if (res.statusCode >= 400) {
      final msg = json['message'] ?? json['error'] ?? 'خطأ ${res.statusCode}';
      throw Exception(msg is List ? (msg as List).join(', ') : msg.toString());
    }
    return json;
  }
}
