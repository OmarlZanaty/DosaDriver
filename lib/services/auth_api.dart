import 'dart:convert';

import '../models/db_user.dart';
import 'api_client.dart';

class AuthApi {
  AuthApi(this._client);

  final ApiClient _client;

  /// GET /v1/auth/me
  /// Backend guard verifies Firebase token, upserts user, returns dbUser.
  Future<DbUser> me() async {
    final res = await _client.request('GET', '/auth/me');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('GET /auth/me failed: ${res.statusCode} ${res.body}');
    }

    final decoded = json.decode(res.body);

    // Backend might return:
    // 1) { user: {...} }
    // 2) { data: {...} }
    // 3) {...} user directly
    Map<String, dynamic>? userJson;

    if (decoded is Map<String, dynamic>) {
      if (decoded['user'] is Map<String, dynamic>) {
        userJson = decoded['user'] as Map<String, dynamic>;
      } else if (decoded['data'] is Map<String, dynamic>) {
        userJson = decoded['data'] as Map<String, dynamic>;
      } else {
        userJson = decoded;
      }
    }

    if (userJson == null) {
      throw Exception('GET /auth/me unexpected response: ${res.body}');
    }

    return DbUser.fromJson(userJson);
  }

  /// PATCH /v1/users/me
  /// body: { phone: "..." }
  ///
  /// Use this to persist phone number in Postgres backend user record.
  Future<void> updateMyPhone(String phone) async {
    final res = await _client.request(
      'PATCH',
      '/users/me',
      jsonBody: {'phone': phone},
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('PATCH /users/me failed: ${res.statusCode} ${res.body}');
    }
  }
}
