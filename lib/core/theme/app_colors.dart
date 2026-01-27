import 'package:flutter/material.dart';

/// DosaDriver Brand Colors
class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFFD32F2F);
  static const Color primaryLight = Color(0xFFFFCDD2);
  static const Color primaryDark = Color(0xFFB71C1C);

  // Secondary Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color successLight = Color(0xFFC8E6C9);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFF44336);

  static const Color background = Color(0xFFFAFAFA);
  static const Color secondary = Color(0xFF1976D2);
  static const Color errorLight = Color(0xFFFFEBEE);

  // Neutral Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color darkGray = Color(0xFF212121);
  static const Color mediumGray = Color(0xFF757575);
  static const Color lightGray = Color(0xFFF5F5F5);
  static const Color divider = Color(0xFFE0E0E0);

  // Map Colors
  static const Color mapRoute = Color(0xFF2196F3);
  static const Color pickupMarker = Color(0xFF4CAF50);
  static const Color destinationMarker = Color(0xFFD32F2F);

  // Status Colors
  static const Color online = Color(0xFF4CAF50);
  static const Color offline = Color(0xFF9E9E9E);
  static const Color busy = Color(0xFFFF9800);

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
