import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/localization/language_controller.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/client_auth_gate.dart';
import 'screens/client_active_ride_screen.dart';
import 'services/notification_service.dart';

/// Global navigator key — used for push-notification deep linking
/// even when the app is launched from a terminated state.
final GlobalKey<NavigatorState> clientNavigatorKey =
    GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
  } catch (e, stack) {
    debugPrint('Firebase.initializeApp failed: $e\n$stack');
    runApp(FirebaseInitErrorApp(message: e.toString()));
    return;
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);



  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    NotificationService().show(
      message.notification?.title,
      message.notification?.body,
      message.data,
    );
  });

  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // ── Deep link: app launched from a notification (terminated state) ──
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    _handleNotificationTap(initialMessage.data);
  }

  // ── Deep link: app in background, user taps notification ──
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    _handleNotificationTap(message.data);
  });

  runApp(const DosaDriverClientApp());
}

/// Navigate to the correct screen based on the notification payload.
void _handleNotificationTap(Map<String, dynamic> data) {
  final rideId = data['rideId']?.toString();
  if (rideId == null || rideId.isEmpty) return;

  // Wait until the navigator is ready (post first frame)
  WidgetsBinding.instance.addPostFrameCallback((_) {
    clientNavigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => ClientActiveRideScreen(rideId: rideId),
      ),
    );
  });
}

/// Shown when Firebase cannot start (missing/invalid google-services.json).
class FirebaseInitErrorApp extends StatelessWidget {
  final String message;
  const FirebaseInitErrorApp({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'تعذر تهيئة Firebase',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(message, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 16),
                const Text(
                  '1. افتح Firebase Console → مشروع dosadriver\n'
                  '2. أضف تطبيق Android بالحزمة: com.almobarmg.clientapp\n'
                  '3. حمّل google-services.json إلى android/app/\n'
                  '4. شغّل: dart pub global activate flutterfire_cli && flutterfire configure',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
    // Remove the Future.delayed — just initialize immediately
    _isInitialized = true;
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
      locale: LanguageController.instance.locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: LanguageController.instance.isArabic
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: child!,
        );
      },
      navigatorKey: clientNavigatorKey,
      home: _isInitialized ? const ClientAuthGate() : const SplashScreen(),
    );
  }
}
