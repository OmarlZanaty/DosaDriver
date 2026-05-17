import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/api_client.dart';
import '../../core/api_config.dart';

class DashboardUsersApi {
  static String get _base => '${ApiConfig.apiPrefix}/admin/dashboard-users';

  static Future<Options> _authOptions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Not logged in (Firebase user is null)');
    }

    final String? token = await user.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw Exception('Missing Firebase idToken');
    }

    return Options(headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });
  }

  static Future<List<dynamic>> list() async {
    final opt = await _authOptions();
    final res = await ApiClient.dio.get(_base, options: opt);
    final data = res.data;

    if (data is List) return data;
    if (data is Map && data['items'] is List) return List<dynamic>.from(data['items']);
    if (data is Map && data['users'] is List) return List<dynamic>.from(data['users']);
    throw Exception('Unexpected response shape: ${data.runtimeType}');
  }

  static Future<Map<String, dynamic>> create({
    required String email,
    required String password,
    String? name,
    required String role,
    required List<String> permissions,
  }) async {
    final opt = await _authOptions();
    final res = await ApiClient.dio.post(
      _base,
      data: {
        'email': email,
        'password': password,
        'name': name,
        'role': role,
        'permissions': permissions,
      },
      options: opt,
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  static Future<Map<String, dynamic>> update({
    required int id,
    String? name,
    required String role,
    required bool isActive,
    required List<String> permissions,
  }) async {
    final opt = await _authOptions();
    final res = await ApiClient.dio.patch(
      '$_base/$id',
      data: {
        'name': name,
        'role': role,
        'isActive': isActive,
        'permissions': permissions,
      },
      options: opt,
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  static Future<void> delete(int id) async {
    final opt = await _authOptions();
    await ApiClient.dio.delete('$_base/$id', options: opt);
  }
}