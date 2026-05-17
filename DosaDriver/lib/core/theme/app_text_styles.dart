import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static const TextStyle headline1 = TextStyle(
    fontSize: 28, fontWeight: FontWeight.bold,
    color: AppColors.darkGray, letterSpacing: -0.5,
  );
  static const TextStyle headline2 = TextStyle(
    fontSize: 22, fontWeight: FontWeight.bold,
    color: AppColors.darkGray, letterSpacing: -0.3,
  );
  static const TextStyle headline3 = TextStyle(
    fontSize: 18, fontWeight: FontWeight.w600,
    color: AppColors.darkGray,
  );
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16, fontWeight: FontWeight.normal,
    color: AppColors.darkGray, height: 1.5,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14, fontWeight: FontWeight.normal,
    color: AppColors.darkGray, height: 1.4,
  );
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12, fontWeight: FontWeight.normal,
    color: AppColors.mediumGray, height: 1.4,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 12, fontWeight: FontWeight.normal,
    color: AppColors.mediumGray,
  );
  static const TextStyle label = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w500,
    color: AppColors.darkGray,
  );
  static const TextStyle button = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w600,
    color: AppColors.white, letterSpacing: 0.5,
  );
  static const TextStyle priceLarge = TextStyle(
    fontSize: 32, fontWeight: FontWeight.bold,
    color: AppColors.darkGray,
  );
}
