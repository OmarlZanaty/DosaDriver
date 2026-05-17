import 'package:shared_preferences/shared_preferences.dart';

class AdminCreds {
  final String email;
  final String password;
  const AdminCreds({required this.email, required this.password});
}

class SessionData {
  final String role;
  final List<String> permissions;
  const SessionData({required this.role, required this.permissions});
}

class SessionStore {
  static late SharedPreferences _sp;

  static const _kAdminEmail = 'admin_email';
  static const _kAdminPass = 'admin_pass';

  static const _kRole = 'me_role';
  static const _kPerms = 'me_perms';

  static SessionData? current;

  static Future<void> init() async {
    _sp = await SharedPreferences.getInstance();

    final role = _sp.getString(_kRole);
    final perms = _sp.getStringList(_kPerms);

    if (role != null) {
      current = SessionData(role: role, permissions: perms ?? const []);
    }
  }

  /// Only email is persisted (for convenience); password is NEVER stored.
  static Future<void> saveAdminCreds({
    required String email,
  }) async {
    await _sp.setString(_kAdminEmail, email);
  }

  static AdminCreds? loadAdminCreds() {
    final email = _sp.getString(_kAdminEmail);
    if (email == null || email.isEmpty) return null;
    return AdminCreds(email: email, password: '');
  }

  static Future<void> saveMe({
    required String role,
    required List<String> perms,
  }) async {
    current = SessionData(role: role, permissions: perms);
    await _sp.setString(_kRole, role);
    await _sp.setStringList(_kPerms, perms);
  }

  static Future<void> clear() async {
    current = null;
    await _sp.remove(_kAdminEmail);
    await _sp.remove(_kAdminPass);
    await _sp.remove(_kRole);
    await _sp.remove(_kPerms);
  }
}