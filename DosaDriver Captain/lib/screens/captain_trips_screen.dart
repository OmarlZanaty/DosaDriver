import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/localization/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/ride/ride_status.dart';

class CaptainTripsScreen extends StatelessWidget {
  const CaptainTripsScreen({super.key});

  // ================= TIME FORMAT =================
  String _formatTripTime(BuildContext context, Timestamp? timestamp) {
    if (timestamp == null) return '';

    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} • '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        title: Text(AppStrings.myTrips(context)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rides')
            .where('captainId', isEqualTo: uid)
            .where('status', whereIn: [
          'completed', 'COMPLETED',
          'cancelled', 'CANCELLED',
          'canceled', 'CANCELED',
        ])
            .orderBy('updatedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                AppStrings.noTrips(context),
                style: AppTextStyles.bodyMedium,
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;

              final statusRaw = (data['status'] ?? 'UNKNOWN').toString();
              final st = rideStatusFromAny(statusRaw);
              final isCompleted = st == RideStatus.completed;

              final amount = (data['price'] as num?)?.toDouble() ?? 0.0;

              final pickup =
              (data['pickupAddress'] ??
                  (data['pickup'] is Map ? data['pickup']['addr'] : null) ??
                  AppStrings.pickup(context))
                  .toString();

              final destination =
              (data['destinationAddress'] ??
                  (data['drop'] is Map ? data['drop']['addr'] : null) ??
                  AppStrings.destination(context))
                  .toString();

              final Timestamp? timeStamp =
                  data['completedAt'] ?? data['cancelledAt'] ?? data['updatedAt'];

              final tripTime = _formatTripTime(context, timeStamp);

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isCompleted ? Icons.check_circle : Icons.cancel,
                          color: isCompleted ? AppColors.success : AppColors.error,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isCompleted
                                  ? AppStrings.completed(context)
                                  : AppStrings.cancelled(context),
                              style: AppTextStyles.caption,
                            ),
                            const SizedBox(height: 2),
                            Text(tripTime, style: AppTextStyles.bodySmall),
                          ],
                        ),
                        const Spacer(),
                        Text('EG ${amount.toStringAsFixed(2)}',
                            style: AppTextStyles.headline3),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    Row(
                      children: [
                        const Icon(Icons.circle, size: 10, color: AppColors.success),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(pickup,
                              style: AppTextStyles.bodyMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.circle, size: 10, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(destination,
                              style: AppTextStyles.bodyMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },

          );
        },
      ),
    );
  }
}
