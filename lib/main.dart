import 'package:DosaDriver/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'core/localization/app_localizations_delegate.dart';
import 'core/localization/locale_controller.dart';
import 'core/theme/app_theme.dart';
import 'screens/client_home_new.dart';
import 'screens/client_login_screen.dart';
import 'screens/complete_phone_screen.dart';
import 'screens/biometric_gate_screen.dart';
import 'services/api_client.dart';
import 'services/auth_api.dart';
import 'services/session_store.dart';

import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> _firebaseMessagingForegroundHandler() async {
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    NotificationService().show(
      message.notification?.title,
      message.notification?.body,
      message.data,
    );
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Local notifications (Android/iOS permissions + init)
  await NotificationService().init();

  // Foreground FCM -> local notification
  await _firebaseMessagingForegroundHandler();

  runApp(
    ChangeNotifierProvider(
      create: (_) => LocaleController(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleController>(
      builder: (context, localeController, _) {
        return MaterialApp(
          title: 'DosaDriver - Rider',
          debugShowCheckedModeBanner: false,

          // ✅ Put transitions here (NOT inside main())
          theme: AppTheme.lightTheme.copyWith(
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
                TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
              },
            ),
          ),

          locale: localeController.locale,
          supportedLocales: const [
            Locale('ar'),
            Locale('en'),
          ],
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          home: const AuthGate(),
          routes: {
            '/client_home': (context) => const ClientHomeNew(),
            '/client_login': (context) => const ClientLoginScreen(),
          },
        );
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _auth = FirebaseAuth.instance;
  final _authApi = AuthApi(ApiClient());
  final _session = SessionStore();

  bool _loading = true;
  Widget? _screen;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final user = _auth.currentUser;

    if (user == null) {
      setState(() {
        _screen = const ClientLoginScreen();
        _loading = false;
      });
      return;
    }

    try {
      // Backend upsert + fetch dbUser
      final dbUser = await _authApi.me();
      await _session.saveDbUser(dbUser);

      // ✅ Use backend phone first, fallback phone second
      String phone = (dbUser.phone ?? '').trim();
      if (phone.isEmpty) {
        final fallback = await _session.readFallbackPhone();
        if (fallback != null && fallback.trim().isNotEmpty) {
          phone = fallback.trim();
        }
      }

      final Widget target =
      phone.isEmpty ? const CompletePhoneScreen() : const ClientHomeNew();

      // ✅ One biometric wrap only
      _screen = BiometricGateScreen(child: target);
    } catch (_) {
      await _auth.signOut();
      _screen = const ClientLoginScreen();
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _screen ?? const ClientLoginScreen();
  }
}
