import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/api_client.dart';
import '../core/api_config.dart';

// (Optional) if you want to reuse your design system like OverviewScreen
import '../ui/tokens/app_colors.dart';
import '../ui/components/stat_card.dart';
import '../ui/components/app_button.dart';

class FinanceScreen extends StatefulWidget {
  final String search;
  const FinanceScreen({super.key, required this.search});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );

  late Future<_FinanceOverview> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
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

  Future<_FinanceOverview> _load() async {
    final opt = await _authOptions();

    final fromIso = DateTime(_range.start.year, _range.start.month, _range.start.day)
        .toUtc()
        .toIso8601String();

    final toIso = DateTime(_range.end.year, _range.end.month, _range.end.day, 23, 59, 59)
        .toUtc()
        .toIso8601String();

    final res = await ApiClient.dio.get(
      ApiConfig.api('/admin/finance/overview'),
      queryParameters: {'from': fromIso, 'to': toIso},
      options: opt,
    );

    final data = (res.data is Map) ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    return _FinanceOverview.fromJson(data);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _range,
    );
    if (picked == null) return;

    setState(() {
      _range = picked;
      _future = _load();
    });
  }

  String _fmtMoney(num v) => '${v.toStringAsFixed(2)} EGP';

  @override
  Widget build(BuildContext context) {
    // Match your app direction (you used RTL in OverviewScreen)
    return Directionality(
      textDirection: TextDirection.rtl,
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_FinanceOverview>(
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
                          'فشل في تحميل لوحة المالية',
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

            final o = snap.data!;

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(14),
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined),
                    const SizedBox(width: 10),
                    const Text(
                      'لوحة المالية',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: _pickRange,
                      icon: const Icon(Icons.date_range),
                      label: Text(
                        '${_range.start.year}-${_range.start.month.toString().padLeft(2, '0')}-${_range.start.day.toString().padLeft(2, '0')}'
                            ' → '
                            '${_range.end.year}-${_range.end.month.toString().padLeft(2, '0')}-${_range.end.day.toString().padLeft(2, '0')}',
                      ),
                    ),
                    IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
                  ],
                ),
                const SizedBox(height: 14),

                // Cards (same StatCard component you already have)
                LayoutBuilder(
                  builder: (context, c) {
                    final cols = c.maxWidth > 1200 ? 4 : 2;
                    final itemWidth = (c.maxWidth - (14 * (cols - 1))) / cols;

                    final cards = <Widget>[
                      StatCard(
                        icon: Icons.check_circle,
                        title: 'الرحلات المكتملة',
                        value: '${o.completedTrips}',
                        subtitle: 'ضمن الفترة',
                        color: AppColors.success,
                      ),
                      StatCard(
                        icon: Icons.trending_up,
                        title: 'إجمالي الإيراد',
                        value: _fmtMoney(o.grossRevenue),
                        subtitle: 'Gross',
                        color: AppColors.primary,
                      ),
                      StatCard(
                        icon: Icons.percent,
                        title: 'عمولة المنصة',
                        value: _fmtMoney(o.platformCommission),
                        subtitle: 'Commission',
                        color: AppColors.warning,
                      ),
                      StatCard(
                        icon: Icons.person,
                        title: 'أرباح الكباتن',
                        value: _fmtMoney(o.captainEarnings),
                        subtitle: 'Captain',
                        color: AppColors.info,
                      ),
                      StatCard(
                        icon: Icons.payments,
                        title: 'إيراد كاش',
                        value: _fmtMoney(o.cashRevenue),
                        subtitle: 'Cash',
                        color: AppColors.textPrimary,
                      ),
                      StatCard(
                        icon: Icons.credit_card,
                        title: 'إيراد كارد',
                        value: _fmtMoney(o.cardRevenue),
                        subtitle: 'Card',
                        color: AppColors.textPrimary,
                      ),
                      StatCard(
                        icon: Icons.account_balance,
                        title: 'صافي المنصة',
                        value: _fmtMoney(o.netRevenue),
                        subtitle: 'Net',
                        color: AppColors.primary,
                      ),
                    ];

                    return Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: cards
                          .map((w) => SizedBox(width: itemWidth, child: w))
                          .toList(),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Simple bars without chart package
                _BarsCard(
                  title: 'توزيع الإيرادات',
                  items: [
                    _BarItem('Cash', o.cashRevenue),
                    _BarItem('Card', o.cardRevenue),
                    _BarItem('Commission', o.platformCommission),
                    _BarItem('Captain', o.captainEarnings),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FinanceOverview {
  final int completedTrips;
  final double grossRevenue;
  final double platformCommission;
  final double captainEarnings;
  final double cashRevenue;
  final double cardRevenue;
  final double netRevenue;

  const _FinanceOverview({
    required this.completedTrips,
    required this.grossRevenue,
    required this.platformCommission,
    required this.captainEarnings,
    required this.cashRevenue,
    required this.cardRevenue,
    required this.netRevenue,
  });

  static double _d(dynamic v) => (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0.0;
  static int _i(dynamic v) => (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;

  factory _FinanceOverview.fromJson(Map<String, dynamic> json) {
    return _FinanceOverview(
      completedTrips: _i(json['completedTrips']),
      grossRevenue: _d(json['grossRevenue']),
      platformCommission: _d(json['platformCommission']),
      captainEarnings: _d(json['captainEarnings']),
      cashRevenue: _d(json['cashRevenue']),
      cardRevenue: _d(json['cardRevenue']),
      netRevenue: _d(json['netRevenue']),
    );
  }
}

class _BarItem {
  final String label;
  final double value;
  _BarItem(this.label, num value) : value = value.toDouble();
}

class _BarsCard extends StatelessWidget {
  final String title;
  final List<_BarItem> items;

  const _BarsCard({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    double maxV = 1;
    for (final i in items) {
      if (i.value > maxV) maxV = i.value;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            ...items.map((e) {
              final pct = (e.value / maxV).clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(width: 90, child: Text(e.label)),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(width: 120, child: Text('${e.value.toStringAsFixed(2)} EGP', textAlign: TextAlign.end)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}