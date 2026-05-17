
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/localization/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

///
/// IMPORTANT:
/// This widget MUST remain public because BottomSheetContent.dart imports
/// captain_home_screen.dart to use it.
///
class RideRequestCard extends StatelessWidget {
  final String rideId;
  final double fare;
  final double distance;
  final int duration;
  final String pickupAddress;
  final String destinationAddress;
  final VoidCallback onAccept;
  final VoidCallback onRefuse;

  const RideRequestCard({
    super.key,
    required this.rideId,
    required this.fare,
    required this.distance,
    required this.duration,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.onAccept,
    required this.onRefuse,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.white,
        border: Border.all(color: AppColors.divider),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EG ${fare.toStringAsFixed(2)}',
              style: AppTextStyles.headline2,
            ),
            const SizedBox(height: 8),

            Text(
              pickupAddress,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            Text(
              destinationAddress,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onRefuse,
                    child: Text(
                      AppStrings.t('refuse', Localizations.localeOf(context).languageCode),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccept,
                    child: Text(
                      AppStrings.t('accept', Localizations.localeOf(context).languageCode),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),

    );
  }
}