import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';
import 'core/session_store.dart';
import 'core/lang_controller.dart';
import 'screens/admin_auth_gate.dart';
import 'screens/admin_login_screen.dart';
import 'ui/tokens/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await SessionStore.init();
  await LangController.instance.init();

  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LangController.instance,
      builder: (_, __) {
        final lang = LangController.instance;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'DosaDriver Admin',
          locale: lang.locale,
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => Directionality(
            textDirection: lang.dir,
            child: child!,
          ),
          theme: _buildTheme(lang.isArabic),
          initialRoute: '/',
          routes: {
            '/': (_) => const AdminAuthGate(),
            '/login': (_) => const AdminLoginScreen(),
          },
        );
      },
    );
  }

  ThemeData _buildTheme(bool isArabic) {
    final base = ThemeData.light(useMaterial3: false);

    final textTheme = isArabic
        ? GoogleFonts.cairoTextTheme(base.textTheme).copyWith(
            displayLarge: GoogleFonts.cairo(
                fontSize: 32, fontWeight: FontWeight.w900,
                color: AppColors.textPrimary),
            headlineLarge: GoogleFonts.cairo(
                fontSize: 24, fontWeight: FontWeight.w800,
                color: AppColors.textPrimary),
            headlineMedium: GoogleFonts.cairo(
                fontSize: 20, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
            titleLarge: GoogleFonts.cairo(
                fontSize: 16, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
            bodyLarge: GoogleFonts.cairo(
                fontSize: 14, fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
            bodyMedium: GoogleFonts.cairo(
                fontSize: 13, fontWeight: FontWeight.normal,
                color: AppColors.textSecondary),
            labelSmall: GoogleFonts.cairo(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: AppColors.textSecondary),
          )
        : base.textTheme.copyWith(
            headlineLarge: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.w800,
                color: AppColors.textPrimary),
          );

    return base.copyWith(
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.blue,
        error: AppColors.danger,
        surface: AppColors.bgSurface,
      ),
      scaffoldBackgroundColor: AppColors.bgApp,
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: AppColors.bgSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgApp,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      dividerColor: AppColors.border,
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
    );
  }
}
