import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/api_client.dart';
import '../../core/api_config.dart';
import '../../core/session_store.dart';

class AdminAuthApi {
  static String get _mePath => '${ApiConfig.apiPrefix}/admin/me';

  Future<void> login({
    required String email,
    required String password,
  }) async {
    // 1) Firebase login
    final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );

    final user = cred.user;
    if (user == null) throw Exception('Firebase login failed (no user)');

    // 2) Load dashboard role/perms from backend
    await me();
  }

  Future<Map<String, dynamic>> me() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not logged in');

    final String? token = await user.getIdToken(true);
    if (token == null || token.isEmpty) throw Exception('Missing Firebase idToken');

    final res = await ApiClient.dio.get(
      _mePath,
      options: Options(headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      }),
    );

    final root = (res.data is Map) ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    final u = (root['user'] is Map) ? Map<String, dynamic>.from(root['user'] as Map) : root;

    final role = (u['role'] ?? '').toString();
    final rawPerms = u['permissions'];
    final perms = (rawPerms is List) ? rawPerms.map((e) => e.toString()).toList() : <String>[];

    await SessionStore.saveMe(role: role, perms: perms);

    return u;
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    await SessionStore.clear();
  }
}