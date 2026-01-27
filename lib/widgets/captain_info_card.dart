import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

class CaptainInfoCard extends StatelessWidget {
  final String name;
  final String phone;
  final String carType;
  final String carNumber;
  final String photoUrl;
  final String etaText;

  const CaptainInfoCard({
    super.key,
    required this.name,
    required this.phone,
    required this.carType,
    required this.carNumber,
    required this.photoUrl,
    required this.etaText,
  });

  Future<void> _callCaptain() async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage: NetworkImage(photoUrl),
            backgroundColor: AppColors.lightGray,
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.headline3),
                const SizedBox(height: 4),
                Text(
                  '$carType • $carNumber',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 4),
                Text(
                  'ETA: $etaText',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: _callCaptain,
            icon: const Icon(Icons.call),
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
