import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme/app_colors.dart';
import '../widgets/custom_widgets.dart';

class ClientTripsScreen extends StatelessWidget {
  const ClientTripsScreen({super.key});

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED': return AppColors.success;
      case 'CANCELED':
      case 'CANCELLED': return AppColors.error;
      case 'STARTED':   return AppColors.secondary;
      case 'ACCEPTED':  return AppColors.warning;
      default:          return AppColors.mediumGray;
    }
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED': return 'مكتملة';
      case 'CANCELED':
      case 'CANCELLED': return 'ملغاة';
      case 'STARTED':   return 'جارية';
      case 'ACCEPTED':  return 'مقبولة';
      case 'REQUESTED': return 'بانتظار';
      case 'ARRIVED':   return 'وصل الكابتن';
      default:          return status;
    }
  }

  String _rideTypeLabel(String? type) {
    switch ((type ?? '').toUpperCase()) {
      case 'FAIR_VALUE': return '🚖 قيمة عادلة';
      case 'PREMIUM':    return '🏆 بريميوم';
      case 'CUTE_CAR':   return '💚 اقتصادي';
      case 'SCOOTER':    return '🛵 سكوتر';
      default:           return type ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'رحلاتي',
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: uid == null
          ? const Center(child: Text('يرجى تسجيل الدخول'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('rides')
                  .where('riderFirebaseUid', isEqualTo: uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary));
                }

                final docs = snap.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_rounded,
                            size: 80, color: AppColors.divider),
                        const SizedBox(height: 16),
                        const Text(
                          'لا توجد رحلات بعد',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.mediumGray),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'ابدأ رحلتك الأولى الآن!',
                          style: TextStyle(color: AppColors.mediumGray),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final data = docs[i].data()! as Map<String, dynamic>;
                    final status = (data['status'] ?? '').toString();
                    final type   = (data['rideType'] ?? data['type'] ?? '').toString();
                    final price  = (data['price'] ?? data['suggestedFare'] ?? data['finalFare'] ?? 0);
                    final rating = data['clientRating'];

                    // ─── Addresses ───
                    final pickupMap = data['pickup'] is Map
                        ? Map<String, dynamic>.from(data['pickup'] as Map)
                        : null;
                    final dropMap = data['drop'] is Map
                        ? Map<String, dynamic>.from(data['drop'] as Map)
                        : null;

                    final pickupAddr = (data['pickupAddress'] ??
                            pickupMap?['addr'] ??
                            '')
                        .toString();
                    final dropAddr = (data['dropAddress'] ??
                            dropMap?['addr'] ??
                            '')
                        .toString();

                    // ─── Date ───
                    String dateStr = '';
                    final ts = data['createdAt'];
                    if (ts is Timestamp) {
                      final dt = ts.toDate();
                      dateStr =
                          '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                    }

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          )
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ─── Top Row ───
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                StatusChip(
                                  label: _statusLabel(status),
                                  color: _statusColor(status),
                                ),
                                Text(
                                  dateStr,
                                  style: const TextStyle(
                                      fontSize: 11, color: AppColors.mediumGray),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // ─── Route ───
                            _RouteRow(
                              icon: Icons.circle,
                              iconColor: AppColors.success,
                              address: pickupAddr.isEmpty ? 'غير محدد' : pickupAddr,
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Container(
                                  width: 1,
                                  height: 18,
                                  color: AppColors.divider),
                            ),
                            _RouteRow(
                              icon: Icons.location_on,
                              iconColor: AppColors.primary,
                              address: dropAddr.isEmpty ? 'غير محدد' : dropAddr,
                            ),

                            const SizedBox(height: 14),
                            const Divider(height: 1),
                            const SizedBox(height: 10),

                            // ─── Bottom Row ───
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _rideTypeLabel(type),
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.darkGray),
                                ),
                                Row(
                                  children: [
                                    if (rating != null) ...[
                                      const Icon(Icons.star,
                                          size: 15, color: AppColors.warning),
                                      const SizedBox(width: 3),
                                      Text(
                                        '$rating',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    Text(
                                      '${price.toStringAsFixed(2)} جنيه',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String address;

  const _RouteRow({
    required this.icon,
    required this.iconColor,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 13, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            address,
            style: const TextStyle(fontSize: 13, color: AppColors.darkGray),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
