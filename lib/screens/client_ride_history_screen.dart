import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/localization/localization_helper.dart';

class ClientRideHistoryScreen extends StatefulWidget {
  const ClientRideHistoryScreen({super.key});

  @override
  State<ClientRideHistoryScreen> createState() =>
      _ClientRideHistoryScreenState();
}

class _ClientRideHistoryScreenState extends State<ClientRideHistoryScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  String _filterStatus = 'all'; // all, completed, cancelled

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          context.tr('ride_history'),
          style: AppTextStyles.headline2,
        ),
      ),
      body: Column(
        children: [
          // ================= FILTER TABS =================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.white,
            child: Row(
              children: [
                _buildFilterTab(context.tr('filter_all'), 'all'),
                const SizedBox(width: 12),
                _buildFilterTab(context.tr('filter_completed'), 'completed'),
                const SizedBox(width: 12),
                _buildFilterTab(context.tr('filter_cancelled'), 'cancelled'),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ================= HISTORY LIST =================
          Expanded(
            child: _user == null
                ? Center(
              child: Text(
                context.tr('login_to_view'),
                style: AppTextStyles.bodyMedium,
              ),
            )
                : StreamBuilder<QuerySnapshot>(
              stream: _getRidesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (!snapshot.hasData ||
                    snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history,
                            size: 64,
                            color: AppColors.divider),
                        const SizedBox(height: 16),
                        Text(
                          context.tr('no_rides'),
                          style: AppTextStyles.headline3,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr('no_rides_hint'),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.darkGray,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final rides = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: rides.length,
                  itemBuilder: (context, index) {
                    final ride =
                    rides[index].data() as Map<String, dynamic>;
                    return _buildRideCard(context, ride);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ================= FIRESTORE QUERY (SAFE) =================
  Stream<QuerySnapshot> _getRidesStream() {
    Query query = FirebaseFirestore.instance
        .collection('rides')
        .where('clientId', isEqualTo: _user!.uid)
        .orderBy('createdAt', descending: true);

    if (_filterStatus != 'all') {
      query = query.where('status', isEqualTo: _filterStatus);
    }

    return query.snapshots();
  }

  // ================= FILTER TAB =================
  Widget _buildFilterTab(String label, String value) {
    final isActive = _filterStatus == value;

    return GestureDetector(
      onTap: () => setState(() => _filterStatus = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: isActive ? Colors.white : AppColors.darkGray,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ================= RIDE CARD =================
  Widget _buildRideCard(BuildContext context, Map<String, dynamic> ride) {
    final status = ride['status'] ?? 'unknown';
    final price = (ride['price'] ?? 0).toDouble();
    final distance = (ride['distanceKm'] ?? 0).toDouble();
    final pickup =
        ride['pickupAddress'] ?? context.tr('unknown_location');
    final destination =
        ride['destinationAddress'] ?? context.tr('unknown_location');

    final createdAt = ride['createdAt'] as Timestamp?;
    final date = createdAt?.toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pickup,
                        style: AppTextStyles.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(
                      '→ $destination',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.darkGray,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: _getStatusColor(status),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDetail(Icons.location_on,
                  '${distance.toStringAsFixed(1)} km'),
              _buildDetail(Icons.attach_money,
                  '${price.toStringAsFixed(2)} EGP'),
              _buildDetail(
                Icons.schedule,
                date != null ? _formatDate(context, date) : '—',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetail(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 4),
        Text(text, style: AppTextStyles.bodySmall),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AppColors.success;
      case 'cancelled':
      case 'canceled':
        return Colors.red;

      default:
        return AppColors.primary;
    }
  }

  String _formatDate(BuildContext context, DateTime date) {
    final diff = DateTime.now().difference(date);

    if (diff.inDays == 0) return context.tr('today');
    if (diff.inDays == 1) return context.tr('yesterday');
    if (diff.inDays < 7) {
      return context
          .tr('days_ago')
          .replaceAll('{days}', diff.inDays.toString());
    }

    return '${date.day}/${date.month}/${date.year}';
  }
}
