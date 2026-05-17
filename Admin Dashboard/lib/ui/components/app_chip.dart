import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_radii.dart';

/// Generic pill shaped chip used for filters and statuses. The default
/// styling is derived from the design system but can be overridden by
/// specifying [background] and [foreground] colours. Chips can be
/// interactive via the [onTap] callback.
class AppChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color? background;
  final Color? foreground;
  final IconData? icon;
  final VoidCallback? onTap;

  const AppChip({
    Key? key,
    required this.label,
    this.active = false,
    this.background,
    this.foreground,
    this.icon,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool hasCustomColours = background != null || foreground != null;
    final Color bg;
    final Color fg;

    if (hasCustomColours) {
      bg = background ?? AppColors.bgSurface;
      fg = foreground ?? AppColors.textPrimary;
    } else {
      // Default filter chip behaviour: active chips are filled with primary,
      // inactive chips are outlined.
      if (active) {
        bg = AppColors.textPrimary;
        fg = Colors.white;
      } else {
        bg = AppColors.bgSurface;
        fg = AppColors.textPrimary;
      }
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.full),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadii.full),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}