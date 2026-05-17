import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_shadows.dart';

/// A reusable card widget that encapsulates a surface with rounded corners,
/// a border and a subtle shadow. This card respects the design system
/// specifications for elevation, radii and colours.
class AppCard extends StatelessWidget {
  /// The content of the card.
  final Widget child;

  /// Optional padding to apply around [child]. Defaults to 16px on all
  /// sides to match the design guidelines.
  final EdgeInsetsGeometry padding;

  /// Custom border radius. Uses the large radius by default.
  final double radius;

  /// Whether to include the default shadow. Set to `false` for flat cards
  /// such as those used within lists.
  final bool elevate;

  const AppCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppRadii.lg,
    this.elevate = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
        boxShadow: elevate ? AppShadows.card : null,
      ),
      child: child,
    );
  }
}