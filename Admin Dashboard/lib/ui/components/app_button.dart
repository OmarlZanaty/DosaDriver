import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_radii.dart';

/// Variants supported by [AppButton]. Each variant maps to a colour
/// configuration defined in the design tokens.
enum AppButtonVariant { primary, secondary, danger, ghost }

/// A configurable button widget. This wrapper around [ElevatedButton] and
/// [OutlinedButton] centralises the styling for all button types used in
/// the admin UI. It supports a loading state and an optional leading
/// icon.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final AppButtonVariant variant;
  final IconData? icon;

  const AppButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.variant = AppButtonVariant.primary,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool disabled = onPressed == null || loading;
    Color bg;
    Color fg;
    Color border;

    switch (variant) {
      case AppButtonVariant.primary:
        bg = disabled ? AppColors.primary.withOpacity(0.5) : AppColors.primary;
        fg = Colors.white;
        border = bg;
        break;
      case AppButtonVariant.secondary:
        bg = AppColors.bgSurface;
        fg = disabled ? AppColors.textSecondary : AppColors.textPrimary;
        border = AppColors.border;
        break;
      case AppButtonVariant.danger:
        bg = disabled ? AppColors.danger.withOpacity(0.5) : AppColors.danger;
        fg = Colors.white;
        border = bg;
        break;
      case AppButtonVariant.ghost:
        bg = Colors.transparent;
        fg = disabled ? AppColors.textSecondary : AppColors.primary;
        border = AppColors.border;
        break;
    }

    final child = loading
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: fg,
                ),
              ),
            ],
          );

    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: disabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
            side: BorderSide(color: border),
          ),
        ),
        child: child,
      ),
    );
  }
}