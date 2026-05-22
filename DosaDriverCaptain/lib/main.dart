import 'package:DosaDriver_captain/screens/captain_auth_gate.dart';
import 'package:DosaDriver_captain/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'core/localization/language_controller.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fix: SurfaceProducer crashes on Android 12 (API 31/32) with Impeller.
  // Force legacy renderer to avoid ImageReader "Image is already closed" fatal crash.
  final mapsImpl = GoogleMapsFlutterPlatform.instance;
  if (mapsImpl is GoogleMapsFlutterAndroid) {
    await mapsImpl.initializeWithRenderer(AndroidMapRenderer.legacy);
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  await NotificationService().init();

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    NotificationService().show(
      message.notification?.title,
      message.notification?.body,
      message.data,
    );
  });

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
