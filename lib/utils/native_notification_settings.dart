import 'package:flutter/services.dart';

class NativeNotificationSettings {
  static const MethodChannel _channel =
  MethodChannel('dosadriver/notifications');

  static Future<bool> open() async {
    try {
      final ok = await _channel.invokeMethod<bool>('openNotificationSettings');
      return ok == true;
    } catch (_) {
      return false;
    }
  }
}