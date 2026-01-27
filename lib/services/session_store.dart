import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/db_user.dart';

class SessionStore {
  static const String _kDbUser = 'db_user';
  static const String _kFallbackPhone = 'fallback_phone';

  Future<void> saveDbUser(DbUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDbUser, json.encode(user.toJson()));
  }

  Future<DbUser?> readDbUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kDbUser);
    if (raw == null || raw.isEmpty) return null;

    try {
      final map = json.decode(raw) as Map<String, dynamic>;
      return DbUser.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearDbUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kDbUser);
  }

  Future<void> saveFallbackPhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFallbackPhone, phone.trim());
  }

  Future<String?> readFallbackPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString(_kFallbackPhone);
    if (phone == null || phone.trim().isEmpty) return null;
    return phone.trim();
  }

  Future<void> clearFallbackPhone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kFallbackPhone);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kDbUser);
    await prefs.remove(_kFallbackPhone);
  }
}
