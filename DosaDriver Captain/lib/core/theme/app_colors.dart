import 'package:flutter/material.dart';

/// DosaDriver Captain App Color Palette
/// Primary: Red (#D32F2F) - Brand color
class AppColors {
  AppColors._();

  // Primary Colors
  static const Color primary = Color(0xFFD32F2F);
  static const Color primaryDark = Color(0xFFB71C1C);
  static const Color primaryLight = Color(0xFFFFCDD2);

  // Secondary Colors
  static const Color secondary = Color(0xFF1976D2);
  static const Color secondaryLight = Color(0xFFBBDEFB);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color successLight = Color(0xFFC8E6C9);
  static const Color warning = Color(0xFFFFC107);
  static const Color warningLight = Color(0xFFFFF8E1);
  static const Color error = Color(0xFFE53935);
  static const Color errorLight = Color(0xFFFFEBEE);

  // Neutral Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color darkGray = Color(0xFF212121);
  static const Color mediumGray = Color(0xFF757575);
  static const Color lightGray = Color(0xFFF5F5F5);
  static const Color divider = Color(0xFFE0E0E0);

  // Background Colors
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);

  // Captain Specific Colors
  static const Color online = Color(0xFF4CAF50);
  static const Color offline = Color(0xFF9E9E9E);
  static const Color earnings = Color(0xFF2E7D32);
  static const Color mapRoute = Color(0xFF1976D2);

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient onlineGradient = LinearGradient(
    colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
