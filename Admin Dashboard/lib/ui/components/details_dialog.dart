import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_shadows.dart';

/// A modal dialog displaying JSON details of a ride. It offers actions
/// to copy the entire JSON or just the ride ID to the clipboard. This
/// widget extracts out the layout used in the rides screen so that it
/// can be reused or modified independently of the page logic.
class RideDetailsDialog extends StatelessWidget {
  final String rideId;
  final String jsonText;
  final VoidCallback onClose;
  final VoidCallback onCopyJson;
  final VoidCallback onCopyId;

  const RideDetailsDialog({
    Key? key,
    required this.rideId,
    required this.jsonText,
    required this.onClose,
    required this.onCopyJson,
    required this.onCopyId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 980,
            maxHeight: MediaQuery.of(context).size.height * 0.86,
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long, size: 22, color: AppColors.textPrimary),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'تفاصيل الرحلة',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'إغلاق',
                      onPressed: onClose,
                      icon: const Icon(Icons.close, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
              // Actions
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _DialogActionButton(
                      icon: Icons.copy,
                      label: 'نسخ JSON',
                      onTap: onCopyJson,
                    ),
                    _DialogActionButton(
                      icon: Icons.tag,
                      label: 'نسخ Ride ID',
                      onTap: onCopyId,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.bgApp,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: SelectableText(
                      jsonText,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12.5,
                        height: 1.35,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppRadii.lg)),
                ),
                child: Row(
                  children: const [
                    Text(
                      'يمكنك تحديد أي جزء ونسخه.',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Spacer(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small button used inside the details dialog. It resembles a soft
/// secondary button with an icon.
class _DialogActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DialogActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.textPrimary),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}