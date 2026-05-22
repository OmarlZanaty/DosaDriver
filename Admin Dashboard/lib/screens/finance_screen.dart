import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../core/api_config.dart';
import '../core/lang_controller.dart';
import '../ui/tokens/app_colors.dart';

/// Admin: Finance Overview
/// Pulls aggregated finance data from /admin/finance/overview with
/// a configurable date range. Shows KPI cards + revenue breakdown chart.
class FinanceScreen extends StatefulWidget {
  final String search;
  const FinanceScreen({super.key, required this.search});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 29)),
    end: DateTime.now(),
  );

  late Future<_FinanceData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  // ── Auth ──────────────────────────────────────────────────────────────────
  Future<Options> _authOptions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not logged in');
    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) throw Exception('Missing token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  // ── Data ──────────────────────────────────────────────────────────────────
  Future<_FinanceData> _load() async {
    final opt = await _authOptions();
    final from = DateTime(
            _range.start.year, _range.start.month, _range.start.day)
        .toUtc()
        .toIso8601String();
    final to = DateTime(_range.end.year, _range.end.month, _range.end.day,
            23, 59, 59)
        .toUtc()
        .toIso8601String();

    final res = await ApiClient.dio.get(
      ApiConfig.api('/admin/finance/overview'),
      queryParameters: {'from': from, 'to': to},
      options: opt,
    );

    final raw = (res.data is Map)
        ? Map<String, dynamic>.from(res.data as Map)
        : <String, dynamic>{};

    // Optionally load chart series
    List<_ChartPoint> revSeries = [];
    try {
      final serRes = await ApiClient.dio.get(
        ApiConfig.api('/admin/finance/revenue-series'),
        queryParameters: {'from': from, 'to': to},
        options: opt,
      );
      if (serRes.data is List) {
        revSeries = (serRes.data as List).map<_ChartPoint>((e) {
          final m = e as Map;
          return _ChartPoint(
            m['label']?.toString() ?? '',
            (m['value'] is num) ? (m['value'] as num).toDouble() : 0,
          );
        }).toList();
      }
    } catch (_) {}

    return _FinanceData.fromJson(raw, revSeries);
  }

  void _refresh() => setState(() => _future = _load());

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _range,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _range = picked;
        _future = _load();
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final lang = LangController.instance;
    final fmt = DateFormat('dd MMM yyyy');

    return FutureBuilder<_FinanceData>(
      future: _future,
      builder: (context, snap) {
        // ── Error ─────────────────────────────────────────────────────────
        if (snap.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: AppColors.danger),
                const SizedBox(height: 12),
                Text(snap.error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 14),
                ElevatedButton(
                    onPressed: _refresh, child: Text(lang.t('retry'))),
              ],
            ),
          );
        }

        // ── Loading ───────────────────────────────────────────────────────
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final d = snap.data!;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Toolbar ──────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.date_range_outlined,
                        size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      '${fmt.format(_range.start)} — ${fmt.format(_range.end)}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: _pickRange,
                      child: Text(lang.t('filter')),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh, size: 18),
                      tooltip: lang.t('retry'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── KPI cards ────────────────────────────────────────────────
              LayoutBuilder(builder: (_, c) {
                final cols = c.maxWidth > 900 ? 4 : 2;
                final kpis = [
                  _KpiDef(
                    icon: Icons.check_circle_outline,
                    color: AppColors.success,
                    label: lang.isArabic
                        ? 'الرحلات المكتملة'
                        : 'Completed Trips',
                    value: d.completedTrips.toString(),
                  ),
                  _KpiDef(
                    icon: Icons.trending_up_rounded,
                    color: AppColors.primary,
                    label: lang.t('total_revenue'),
                    value: _fmtEgp(d.grossRevenue),
                  ),
                  _KpiDef(
                    icon: Icons.percent_rounded,
                    color: AppColors.warning,
                    label: lang.t('total_commission'),
                    value: _fmtEgp(d.platformCommission),
                  ),
                  _KpiDef(
                    icon: Icons.person_outlined,
                    color: AppColors.info,
                    label: lang.t('captain_payouts'),
                    value: _fmtEgp(d.captainEarnings),
                  ),
                  _KpiDef(
                    icon: Icons.payments_outlined,
                    color: AppColors.textPrimary,
                    label: lang.isArabic ? 'إيراد كاش' : 'Cash Revenue',
                    value: _fmtEgp(d.cashRevenue),
                  ),
                  _KpiDef(
                    icon: Icons.credit_card_outlined,
                    color: AppColors.blue,
                    label: lang.isArabic ? 'إيراد كارت' : 'Card Revenue',
                    value: _fmtEgp(d.cardRevenue),
                  ),
                  _KpiDef(
                    icon: Icons.account_balance_outlined,
                    color: AppColors.primary,
                    label: lang.isArabic ? 'صافي المنصة' : 'Net Revenue',
                    value: _fmtEgp(d.netRevenue),
                  ),
                ];

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    childAspectRatio: 2.6,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: kpis.length,
                  itemBuilder: (_, i) => _KpiCard(def: kpis[i]),
                );
              }),

              const SizedBox(height: 20),

              // ── Charts row ───────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Revenue breakdown donut
                  Expanded(
                    flex: 2,
                    child: _FinanceCard(
                      title: lang.isArabic
                          ? 'توزيع الإيرادات'
                          : 'Revenue Breakdown',
                      child: _DonutChart(data: d),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Revenue trend line chart
                  Expanded(
                    flex: 3,
                    child: _FinanceCard(
                      title: lang.isArabic
                          ? 'منحنى الإيرادات'
                          : 'Revenue Trend',
                      child: d.revenueSeries.isEmpty
                          ? _emptyChart(lang)
                          : _RevenueTrendChart(
                              points: d.revenueSeries),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _fmtEgp(double v) => '${v.toStringAsFixed(0)} EGP';

  Widget _emptyChart(LangController lang) => SizedBox(
        height: 200,
        child: Center(
          child: Text(lang.t('empty'),
              style: const TextStyle(color: AppColors.textSecondary)),
        ),
      );
}

// ── KPI card ──────────────────────────────────────────────────────────────────

class _KpiDef {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _KpiDef({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });
}

class _KpiCard extends StatelessWidget {
  final _KpiDef def;
  const _KpiCard({required this.def});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: def.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(def.icon, color: def.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  def.value,
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    height: 1.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  def.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Finance card wrapper ──────────────────────────────────────────────────────

class _FinanceCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _FinanceCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ── Donut chart: commission vs captain vs net ─────────────────────────────────

class _DonutChart extends StatelessWidget {
  final _FinanceData data;
  const _DonutChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final total = data.grossRevenue == 0 ? 1.0 : data.grossRevenue;
    final sections = [
      PieChartSectionData(
        value: data.platformCommission,
        color: AppColors.primary,
        title: '${(data.platformCommission / total * 100).toStringAsFixed(0)}%',
        radius: 60,
        titleStyle: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      PieChartSectionData(
        value: data.captainEarnings,
        color: AppColors.blue,
        title: '${(data.captainEarnings / total * 100).toStringAsFixed(0)}%',
        radius: 60,
        titleStyle: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      PieChartSectionData(
        value: (data.netRevenue > 0 ? data.netRevenue : 0),
        color: AppColors.success,
        title: '${(data.netRevenue / total * 100).toStringAsFixed(0)}%',
        radius: 60,
        titleStyle: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    ];

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 40,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Legend
        _legendRow(AppColors.primary, 'Commission'),
        const SizedBox(height: 4),
        _legendRow(AppColors.blue, 'Captain'),
        const SizedBox(height: 4),
        _legendRow(AppColors.success, 'Net'),
      ],
    );
  }

  Widget _legendRow(Color color, String label) {
    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

// ── Revenue trend line chart ──────────────────────────────────────────────────

class _RevenueTrendChart extends StatelessWidget {
  final List<_ChartPoint> points;
  const _RevenueTrendChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final maxY = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final spots = points
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY * 1.2,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (_) => const FlLine(
              color: AppColors.border,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 52,
                getTitlesWidget: (v, _) => Text(
                  _fmtK(v),
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textSecondary),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (points.length / 5).ceilToDouble(),
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= points.length) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    points[i].label,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textSecondary),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.primary,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.primary.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        '${s.y.toStringAsFixed(0)} EGP',
                        const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  String _fmtK(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }
}

// ── Data models ───────────────────────────────────────────────────────────────

class _FinanceData {
  final int completedTrips;
  final double grossRevenue;
  final double platformCommission;
  final double captainEarnings;
  final double cashRevenue;
  final double cardRevenue;
  final double netRevenue;
  final List<_ChartPoint> revenueSeries;

  const _FinanceData({
    required this.completedTrips,
    required this.grossRevenue,
    required this.platformCommission,
    required this.captainEarnings,
    required this.cashRevenue,
    required this.cardRevenue,
    required this.netRevenue,
    required this.revenueSeries,
  });

  static double _d(dynamic v) =>
      (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0.0;
  static int _i(dynamic v) =>
      (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;

  factory _FinanceData.fromJson(
      Map<String, dynamic> json, List<_ChartPoint> series) {
    return _FinanceData(
      completedTrips: _i(json['completedTrips']),
      grossRevenue: _d(json['grossRevenue']),
      platformCommission: _d(json['platformCommission']),
      captainEarnings: _d(json['captainEarnings']),
      cashRevenue: _d(json['cashRevenue']),
      cardRevenue: _d(json['cardRevenue']),
      netRevenue: _d(json['netRevenue']),
      revenueSeries: series,
    );
  }
}

class _ChartPoint {
  final String label;
  final double value;
  const _ChartPoint(this.label, this.value);
}
