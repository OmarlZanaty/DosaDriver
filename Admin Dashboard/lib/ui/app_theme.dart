import 'package:flutter/material.dart';

import 'tokens/app_colors.dart';
import 'tokens/app_radii.dart';
import 'tokens/app_text.dart';

/// Provides the overarching [ThemeData] for the admin panel. Applying this
/// theme at the root of the application ensures consistent colours,
/// typography and default component behaviour. It also makes it trivial
/// to support dark mode or brand theming in the future.
class AppTheme {
  /// Returns the default light theme. You can extend this method to
  /// generate a dark theme by swapping colours.
  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bgApp,
      primaryColor: AppColors.primary,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        primaryContainer: AppColors.primarySoft,
        secondary: AppColors.info,
        error: AppColors.danger,
        surface: AppColors.bgSurface,
        background: AppColors.bgApp,
        onPrimary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: base.textTheme.copyWith(
        displayLarge: AppTextStyles.h1,
        displayMedium: AppTextStyles.h2,
        displaySmall: AppTextStyles.h3,
        bodyLarge: AppTextStyles.bodyLarge,
        bodyMedium: AppTextStyles.body,
        bodySmall: AppTextStyles.small,
        titleLarge: AppTextStyles.h2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
        ),
        hintStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontFamily: 'Cairo',
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          textStyle: MaterialStateProperty.all(
            const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          backgroundColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.disabled)) {
              return AppColors.primary.withOpacity(0.5);
            }
              return AppColors.primary;
          }),
          foregroundColor: MaterialStateProperty.all(Colors.white),
          minimumSize: MaterialStateProperty.all(const Size.fromHeight(50)),
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
          ),
          elevation: MaterialStateProperty.all(0),
        ),
      ),
    );
  }
}