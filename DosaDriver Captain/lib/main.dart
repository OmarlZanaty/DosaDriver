import 'package:DosaDriver_captain/screens/biometric_gate_screen.dart';
import 'package:DosaDriver_captain/screens/captain_auth_gate.dart';
import 'package:DosaDriver_captain/screens/captain_status_gate.dart';
import 'package:DosaDriver_captain/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'auth_gate.dart';
import 'core/localization/language_controller.dart';
import 'core/theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/captain_home_screen.dart';
import 'screens/captain_earnings_screen.dart';
import 'screens/captain_trips_screen.dart';
import 'screens/captain_profile_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Setup local notifications
  await NotificationService().init();

  // Listen for foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    NotificationService().show(message.notification?.title, message.notification?.body, message.data);
  });

  // b
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = LanguageController.instance;

    return AnimatedBuilder(
      animation: lang,
      builder: (_, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,

          // ✅ THIS IS CRITICAL
          locale: lang.locale,

          supportedLocales: const [
            Locale('en'),
            Locale('ar'),
          ],

          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          home: const CaptainAuthGate(),
        );
      },
    );
  }
}

