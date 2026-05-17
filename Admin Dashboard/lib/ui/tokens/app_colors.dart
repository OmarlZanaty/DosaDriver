import 'package:flutter/material.dart';

/// A centralised palette for the admin panel. All colours used in the
/// application should be defined here. This makes it easy to tune the
/// visual appearance from a single place and ensures that new widgets
/// remain consistent with the design system extracted from Figma.
class AppColors {
  /////////////////
  // Neutrals
  /////////////////

  /// Primary background colour for the entire application. This should be
  /// applied to [Scaffold.backgroundColor].
  static const Color bgApp = Color(0xFFF9FAFB);

  /// Colour used for surfaces such as cards and sheets.
  static const Color bgSurface = Color(0xFFFFFFFF);

  /// Default border colour used around inputs, cards and other elements.
  static const Color border = Color(0xFFE5E7EB);

  /// Primary text colour, used for headings and important information.
  static const Color textPrimary = Color(0xFF111827);

  /// Secondary text colour for body copy, labels and less prominent text.
  static const Color textSecondary = Color(0xFF6B7280);

  /////////////////
  // Brand colours
  /////////////////

  /// Primary brand colour (blue). Used for call‑to‑action buttons and
  /// highlights on the dashboard.
  static const Color primary = Color(0xFF2563EB);

  /// Hover/active state for the primary brand colour. Use for interactive
  /// states such as hovered buttons or selected chips.
  static const Color primaryHover = Color(0xFF1D4ED8);

  /// Soft version of the primary colour. Ideal for backgrounds of chips
  /// representing the primary status.
  static const Color primarySoft = Color(0xFFDBEAFE);

  /////////////////
  // Status colours
  /////////////////

  /// Success state colour. Should be used for success buttons and positive
  /// feedback.
  static const Color success = Color(0xFF10B981);

  /// Warning state colour. Use sparingly for warnings and caution messages.
  static const Color warning = Color(0xFFF59E0B);

  /// Danger state colour. Used for destructive actions such as cancel or
  /// delete.
  static const Color danger = Color(0xFFEF4444);

  /// Informational colour. Useful for neutral statuses and informational
  /// chips.
  static const Color info = Color(0xFF6366F1);

  /// Soft backgrounds for each status colour. These are used as subtle
  /// backgrounds behind status chips or icons.
  static const Color successSoft = Color(0xFFD1FAE5);
  static const Color warningSoft = Color(0xFFFEF3C7);
  static const Color dangerSoft = Color(0xFFFEE2E2);
  static const Color infoSoft = Color(0xFFE0E7FF);

  /// Neutral soft background used for completed rides or neutral chips.
  static const Color neutralSoft = Color(0xFFF3F4F6);

  /////////////////
  // Legacy brand colours (login screen)
  /////////////////

  /// Start colour for the red gradient on the login screen. You can find
  /// these values by inspecting the exported Figma gradient stops.
  static const Color loginRedStart = Color(0xFF8E0E00);

  /// Middle colour for the red gradient on the login screen.
  static const Color loginRedMid = Color(0xFFE53935);

  /// End colour for the red gradient on the login screen.
  static const Color loginRedEnd = Color(0xFFFF6B6B);

  /// A pale red colour used on error banners and warning chips.
  static const Color errorBg = Color(0xFFFFF1F2);

  /// Error border and foreground used on error banners.
  static const Color errorBorder = Color(0xFFFECACA);
  static const Color errorText = Color(0xFFB91C1C);

  /// Soft grey used as a light input background.
  static const Color inputBg = Color(0xFFF3F4F6);

  /// Accent colour used on the login screen for the brand name. This
  /// duplicates [loginRedMid] for convenience.
  static const Color brandAccent = loginRedMid;
}