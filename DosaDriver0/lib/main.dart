import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/localization/language_controller.dart';
import 'core/theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/client_auth_gate.dart';
import 'services/notification_service.dart';

// Handle FCM background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // Portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Firebase
  await Firebase.initializeApp();

  // FCM background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Notifications
  await NotificationService().init();

  // FCM foreground
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    NotificationService().show(
      message.notification?.title,
      message.notification?.body,
      message.data,
    );
  });

  // Request notification permission
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  runApp(const DosaDriverClientApp());
}

class DosaDriverClientApp extends StatefulWidget {
  const DosaDriverClientApp({super.key});

  @override
  State<DosaDriverClientApp> createState() => _DosaDriverClientAppState();
}

class _DosaDriverClientAppState extends State<DosaDriverClientApp> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    LanguageController.instance.addListener(_onLanguageChange);
    // Simulate brief splash
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isInitialized = true);
    });
  }

  void _onLanguageChange() => setState(() {});

  @override
  void dispose() {
    LanguageController.instance.removeListener(_onLanguageChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DosaDriver — تطبيق العميل',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,

      // Localization
      locale: LanguageController.instance.locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // RTL for Arabic
      builder: (context, child) {
        return Directionality(
          textDirection: LanguageController.instance.isArabic
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: child!,
        );
      },

      home: _isInitialized ? const ClientAuthGate() : const SplashScreen(),
    );
  }
}
