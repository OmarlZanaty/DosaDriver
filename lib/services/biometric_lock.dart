import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricLock {
  static const _keyEnabled = 'biometric_enabled';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<bool> isEnabled() async {
    final v = await _storage.read(key: _keyEnabled);
    return v == '1';
  }

  Future<void> setEnabled(bool enabled) async {
    await _storage.write(key: _keyEnabled, value: enabled ? '1' : '0');
  }
}
