import 'package:flutter/material.dart';

import '../tokens/app_radii.dart';
import '../tokens/app_shadows.dart';
import '../tokens/app_colors.dart';

/// A wrapper around [InkWell] and [AppCard] tailored for a single ride.
/// The ride card handles the tap interaction and uses a slightly larger
/// radius than a regular card. Consumers can supply arbitrary content
/// through the [child] parameter.
class RideCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const RideCard({Key? key, required this.child, this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.card,
        ),
        child: child,
      ),
    );
  }
}