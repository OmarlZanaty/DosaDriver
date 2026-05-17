import 'package:flutter/material.dart';

/// Standardised shadows used throughout the application. Shadows are
/// notoriously hard to match by eye; defining them here ensures that
/// elements share the same depth and weight.
class AppShadows {
  AppShadows._();

  /// A subtle card shadow used for most cards on the dashboard. This
  /// corresponds to a blur radius of 18 and a small downward offset.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 18,
      offset: Offset(0, 10),
    ),
  ];

  /// A slightly stronger shadow used on the login card to elevate it above
  /// the gradient background. The blur radius and opacity were extracted
  /// from the exported Figma specification.
  static const List<BoxShadow> loginCard = [
    BoxShadow(
      color: Color(0x11000000),
      blurRadius: 22,
      offset: Offset(0, 12),
    ),
  ];

  /// A shadow used for modal dialogs and drawers. It provides more depth
  /// so that modals clearly float above the page content.
  static const List<BoxShadow> dialog = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 24,
      offset: Offset(0, 14),
    ),
  ];
}