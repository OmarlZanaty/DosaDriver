import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> rootNavKey = GlobalKey<NavigatorState>();

class AppNav {
  static NavigatorState get _nav {
    final nav = rootNavKey.currentState;
    if (nav == null) {
      throw StateError('Navigator is not ready (rootNavKey.currentState is null)');
    }
    return nav;
  }

  static Future<void> goToLoginAndClear() async {
    _nav.pushNamedAndRemoveUntil('/login', (route) => false);
  }

  static Future<void> goHomeAndClear() async {
    _nav.pushNamedAndRemoveUntil('/', (route) => false);
  }
}