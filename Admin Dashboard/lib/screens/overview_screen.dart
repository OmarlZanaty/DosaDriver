import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/api_client.dart';
import '../core/api_config.dart';

// Import the design system tokens and components
import '../ui/tokens/app_colors.dart';
import '../ui/tokens/app_radii.dart';
import '../ui/components/stat_card.dart';
import '../ui/components/app_button.dart';

class OverviewScreen extends StatefulWidget {
  final String search;
  const OverviewScreen({super.key, required this.search});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  late Future<_OverviewCounts> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadCounts();
  }

  Future<Options> _authOptions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not logged in');

    final String? token = await user.getIdToken(true);
    if (token == null || token.isEmpty) throw Exception('Missing Firebase idToken');

    return Options(headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });
  }

  Future<_OverviewCounts> _loadCounts() async {
    final opt = await _authOptions();

    // ✅ Use API prefix helper (returns "/v1/...")
    final res = await ApiClient.dio.get(
      ApiConfig.api('/admin/overview-stats'),
      options: opt,
    );

    final data = (res.data is Map)
        ? Map<String, dynamic>.from(res.data as Map)
        : <String, dynamic>{};

    // backend returns { ok:true, activeRides, requestedRides, onlineDrivers }
    int asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('$v') ?? 0;
    }

    return _OverviewCounts(
      activeRides: asInt(data['activeRides']),
      requestedRides: asInt(data['requestedRides']),
      onlineDrivers: asInt(data['onlineDrivers']),
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadCounts();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_OverviewCounts>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.error_outline, size: 46, color: AppColors.danger),
                        const SizedBox(height: 10),
                        const Text(
                          'فشل في تحميل إحصائيات النظرة العامة',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snap.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),
                        AppButton(
                          label: 'إعادة المحاولة',
                          onPressed: _refresh,
                          variant: AppButtonVariant.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snap.data!;
            final active = data.activeRides;
            final requested = data.requestedRides;
            final online = data.onlineDrivers;

            // Determine columns based on screen width. Use 4 columns for large
            // desktop widths and 2 columns for narrower layouts.
            final double width = MediaQuery.of(context).size.width;
            final int cols = width > 1200 ? 4 : 2;

            return GridView.count(
              physics: const AlwaysScrollableScrollPhysics(),
              crossAxisCount: cols,
              childAspectRatio: 2.6,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              padding: const EdgeInsets.only(top: 2),
              children: [
                StatCard(
                  icon: Icons.local_taxi,
                  title: 'الرحلات النشطة',
                  value: '$active',
                  subtitle: '$requested في الانتظار',
                  color: AppColors.primary,
                ),
                StatCard(
                  icon: Icons.groups,
                  title: 'الكباتن المتصلون',
                  value: '$online',
                  subtitle: 'أونلاين الآن',
                  color: AppColors.success,
                ),
                StatCard(
                  icon: Icons.check_circle,
                  title: 'مكتملة اليوم',
                  value: '—',
                  subtitle: 'قريباً سيتم إضافة الاستعلام',
                  color: AppColors.info,
                ),
                StatCard(
                  icon: Icons.payments,
                  title: 'إيراد اليوم',
                  value: '—',
                  subtitle: 'قريباً سيتم إضافة الإيرادات',
                  color: AppColors.warning,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OverviewCounts {
  final int activeRides;
  final int requestedRides;
  final int onlineDrivers;

  _OverviewCounts({
    required this.activeRides,
    required this.requestedRides,
    required this.onlineDrivers,
  });
}