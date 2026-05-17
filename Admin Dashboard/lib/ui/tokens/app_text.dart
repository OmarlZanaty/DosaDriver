import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typography definitions. Each text style corresponds to a semantic role
/// (heading, body, caption) rather than a specific widget. Use these
/// constants throughout the application rather than raw TextStyle
/// constructors. If the design system ever changes its typographic scale,
/// you will only need to update this file.
class AppTextStyles {
  AppTextStyles._();

  static const String _fontFamily = 'Cairo';

  /// Large headline, used for page titles.
  static const TextStyle h1 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  /// Secondary headline, used for section titles.
  static const TextStyle h2 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  /// Tertiary headline, used for card titles and smaller headings.
  static const TextStyle h3 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  /// Regular body text for paragraphs.
  static const TextStyle body = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  /// Large body text, used when more breathing room is required.
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  /// Small caption text for annotations or secondary labels.
  static const TextStyle small = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    height: 1.4,
  );
}