import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/api_client.dart';
import '../core/api_config.dart';
import '../core/lang_controller.dart';
import '../ui/tokens/app_colors.dart';

/// Live Overview / Home dashboard.
/// KPIs are loaded from the backend (/admin/overview-stats) and enriched
/// with live Firestore streams. Charts pull a 7-day or 30-day series from
/// /admin/revenue-series and /admin/trip-series.
class OverviewScreen extends StatefulWidget {
  final String search;
  const OverviewScreen({super.key, required this.search});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  // ── State ────────────────────────────────────────────────────────────────
  late Future<_OverviewData> _future;
  Timer? _autoRefresh;

  // Chart period selector: 'today' | 'week' | 'month' | 'year'
  String _chartPeriod = 'week';

  @override
  void initState() {
    super.initState();
    _future = _load();
    // Auto-refresh every 60 seconds
    _autoRefresh = Timer.periodic(
      const Duration(seconds: 60),
      (_) => setState(() => _future = _load()),
    );
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    super.dispose();
  }

  // ── Auth ──────────────────────────────────────────────────────────────────
  Future<Options> _authOptions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not logged in');
    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) throw Exception('Missing token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  // ── Data load ─────────────────────────────────────────────────────────────
  Future<_OverviewData> _load() async {
    final opt = await _authOptions();

    // Hit the overview-stats endpoint
    final res = await ApiClient.dio.get(
      ApiConfig.api('/admin/overview-stats'),
      options: opt,
    );

    final raw = (res.data is Map)
        ? Map<String, dynamic>.from(res.data as Map)
        : <String, dynamic>{};

    int asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('$v') ?? 0;
    }

    double asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse('$v') ?? 0.0;
    }

    // Also fetch the chart series
    List<_ChartPoint> revenuePoints = [];
    List<_ChartPoint> tripPoints = [];

    try {
      final days = _chartPeriod == 'today'
          ? 1
          : _chartPeriod == 'week'
              ? 7
              : _chartPeriod == 'month'
                  ? 30
                  : 365;

      final revRes = await ApiClient.dio.get(
        ApiConfig.api('/admin/revenue-series'),
        queryParameters: {'days': days},
        options: opt,
      );
      final tripRes = await ApiClient.dio.get(
        ApiConfig.api('/admin/trip-series'),
        queryParameters: {'days': days},
        options: opt,
      );

      revenuePoints = _parsePoints(revRes.data);
      tripPoints = _parsePoints(tripRes.data);
    } catch (_) {
      // Charts are optional — silently degrade if endpoint missing
    }

    return _OverviewData(
      activeRides: asInt(raw['activeRides']),
      requestedRides: asInt(raw['requestedRides']),
      onlineDrivers: asInt(raw['onlineDrivers']),
      todayRevenue: asDouble(raw['todayRevenue']),
      todayTrips: asInt(raw['todayTrips']),
      todayNewUsers: asInt(raw['todayNewUsers']),
      todayNewCaptains: asInt(raw['todayNewCaptains']),
      cancelRate: asDouble(raw['cancelRate']),
      completedToday: asInt(raw['completedToday']),
      revenuePoints: revenuePoints,
      tripPoints: tripPoints,
    );
  }

  List<_ChartPoint> _parsePoints(dynamic data) {
    if (data is! List) return [];
    return data.map<_ChartPoint>((e) {
      final m = (e as Map<dynamic, dynamic>);
      final label = m['label']?.toString() ?? '';
      final val =
          (m['value'] is num) ? (m['value'] as num).toDouble() : 0.0;
      return _ChartPoint(label, val);
    }).toList();
  }

  void _refresh() => setState(() => _future = _load());

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final lang = LangController.instance;

    return FutureBuilder<_OverviewData>(
      future: _future,
      builder: (context, snap) {
        // ── Error state ─────────────────────────────────────────────────────
        if (snap.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: AppColors.danger),
                const SizedBox(height: 12),
                Text(
                  lang.t('error'),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  snap.error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: _refresh,
                  child: Text(lang.t('retry')),
                ),
              ],
            ),
          );
        }

        // ── Loading state ────────────────────────────────────────────────────
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snap.data!;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top KPI row ─────────────────────────────────────────────
              _buildKpiGrid(data, lang),

              const SizedBox(height: 20),

              // ── Charts row ──────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Revenue chart
                  Expanded(
                    flex: 3,
                    child: _ChartCard(
                      title: lang.t('revenue_chart'),
                      period: _chartPeriod,
                      onPeriodChanged: (p) =>
                          setState(() => _chartPeriod = p),
                      chart: data.revenuePoints.isEmpty
                          ? _emptyChart(lang)
                          : _RevenueLineChart(
                              points: data.revenuePoints),
                      lang: lang,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Trip volume chart
                  Expanded(
                    flex: 2,
                    child: _ChartCard(
                      title: lang.t('trip_volume'),
                      period: _chartPeriod,
                      showPeriodPicker: false,
                      chart: data.tripPoints.isEmpty
                          ? _emptyChart(lang)
                          : _TripBarChart(points: data.tripPoints),
                      lang: lang,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Live feed row ─────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _LiveRidesCard(lang: lang)),
                  const SizedBox(width: 16),
                  Expanded(child: _LiveCaptainsCard(lang: lang)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── KPI grid (2 rows × 4 cols) ─────────────────────────────────────────────
  Widget _buildKpiGrid(_OverviewData d, LangController lang) {
    final cards = [
      _KpiDef(
        icon: Icons.local_taxi,
        color: AppColors.primary,
        labelKey: 'active_rides',
        value: d.activeRides.toString(),
        subIcon: Icons.hourglass_top_rounded,
        sub: '${d.requestedRides} ${lang.t("waiting_rides")}',
      ),
      _KpiDef(
        icon: Icons.wifi,
        color: AppColors.success,
        labelKey: 'online_captains',
        value: d.onlineDrivers.toString(),
        sub: lang.t('online_now'),
      ),
      _KpiDef(
        icon: Icons.attach_money_rounded,
        color: AppColors.info,
        labelKey: 'today_revenue',
        value: '${d.todayRevenue.toStringAsFixed(0)} EGP',
        sub: '',
      ),
      _KpiDef(
        icon: Icons.check_circle_outline,
        color: AppColors.blue,
        labelKey: 'today_trips',
        value: d.todayTrips.toString(),
        sub: '${d.completedToday} ${lang.t("completed")}',
      ),
      _KpiDef(
        icon: Icons.person_add_outlined,
        color: AppColors.warning,
        labelKey: 'today_new_users',
        value: d.todayNewUsers.toString(),
        sub: '',
      ),
      _KpiDef(
        icon: Icons.directions_car_outlined,
        color: AppColors.success,
        labelKey: 'today_new_captains',
        value: d.todayNewCaptains.toString(),
        sub: '',
      ),
      _KpiDef(
        icon: Icons.cancel_outlined,
        color: AppColors.danger,
        labelKey: 'cancel_rate',
        value: '${d.cancelRate.toStringAsFixed(1)}%',
        sub: '',
      ),
    ];

    return LayoutBuilder(
      builder: (_, c) {
        final cols = c.maxWidth > 900 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            childAspectRatio: 2.6,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemCount: cards.length,
          itemBuilder: (_, i) => _KpiCard(def: cards[i], lang: lang),
        );
      },
    );
  }

  Widget _emptyChart(LangController lang) {
    return SizedBox(
      height: 180,
      child: Center(
        child: Text(lang.t('empty'),
            style: const TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }
}

// ── KPI card ──────────────────────────────────────────────────────────────────

class _KpiDef {
  final IconData icon;
  final Color color;
  final String labelKey;
  final String value;
  final String sub;
  final IconData? subIcon;

  const _KpiDef({
    required this.icon,
    required this.color,
    required this.labelKey,
    required this.value,
    required this.sub,
    this.subIcon,
  });
}

class _KpiCard extends StatelessWidget {
  final _KpiDef def;
  final LangController lang;

  const _KpiCard({required this.def, required this.lang});

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
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    height: 1.1,
                  ),
                ),
                Text(
                  lang.t(def.labelKey),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (def.sub.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (def.subIcon != null) ...[
                        Icon(def.subIcon,
                            size: 11, color: AppColors.textSecondary),
                        const SizedBox(width: 3),
                      ],
                      Expanded(
                        child: Text(
                          def.sub,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chart card wrapper ────────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  final String title;
  final String period;
  final ValueChanged<String>? onPeriodChanged;
  final bool showPeriodPicker;
  final Widget chart;
  final LangController lang;

  const _ChartCard({
    required this.title,
    required this.period,
    this.onPeriodChanged,
    this.showPeriodPicker = true,
    required this.chart,
    required this.lang,
  });

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
          Row(
            children: [
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              if (showPeriodPicker && onPeriodChanged != null) ...[
                const Spacer(),
                _PeriodPicker(
                  period: period,
                  onChanged: onPeriodChanged!,
                  lang: lang,
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          chart,
        ],
      ),
    );
  }
}

// ── Period picker ─────────────────────────────────────────────────────────────

class _PeriodPicker extends StatelessWidget {
  final String period;
  final ValueChanged<String> onChanged;
  final LangController lang;

  const _PeriodPicker({
    required this.period,
    required this.onChanged,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final options = [
      ('today', lang.t('today')),
      ('week', lang.t('this_week')),
      ('month', lang.t('this_month')),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: options.map((e) {
        final (key, label) = e;
        final selected = period == key;
        return GestureDetector(
          onTap: () => onChanged(key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Revenue Line Chart (fl_chart) ─────────────────────────────────────────────

class _RevenueLineChart extends StatelessWidget {
  final List<_ChartPoint> points;
  const _RevenueLineChart({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox(height: 180);

    final spots = points.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();

    final maxY = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 200,
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
                interval: (points.length / 4).ceilToDouble(),
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
              curveSmoothness: 0.35,
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

// ── Trip Bar Chart (fl_chart) ─────────────────────────────────────────────────

class _TripBarChart extends StatelessWidget {
  final List<_ChartPoint> points;
  const _TripBarChart({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox(height: 200);

    final maxY = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
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
                reservedSize: 30,
                getTitlesWidget: (v, _) => Text(
                  v.toStringAsFixed(0),
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textSecondary),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (points.length / 4).ceilToDouble(),
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
          barGroups: points.asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.value,
                  color: AppColors.blue,
                  width: 14,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Live Rides feed ───────────────────────────────────────────────────────────

class _LiveRidesCard extends StatelessWidget {
  final LangController lang;
  const _LiveRidesCard({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_taxi, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                lang.isArabic ? 'الرحلات النشطة الآن' : 'Live Active Rides',
                style: GoogleFonts.cairo(
                    fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('rides')
                .where('status', whereIn: ['active', 'ACTIVE', 'in_progress'])
                .limit(8)
                .snapshots(),
            builder: (ctx, snap) {
              if (!snap.hasData) {
                return const _SmallLoader();
              }
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return Text(lang.t('empty'),
                    style: const TextStyle(color: AppColors.textSecondary));
              }
              return Column(
                children: docs.map((d) {
                  final data = d.data();
                  final from = (data['pickupAddress'] ??
                          data['from'] ??
                          data['origin'] ??
                          '—')
                      .toString();
                  final captain = (data['captainName'] ??
                          data['driverName'] ??
                          '—')
                      .toString();
                  return _LiveRow(
                    icon: Icons.radio_button_on,
                    iconColor: AppColors.success,
                    primary: from,
                    secondary: captain,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Live Captains feed ────────────────────────────────────────────────────────

class _LiveCaptainsCard extends StatelessWidget {
  final LangController lang;
  const _LiveCaptainsCard({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wifi, size: 18, color: AppColors.success),
              const SizedBox(width: 8),
              Text(
                lang.isArabic ? 'الكباتن المتصلون' : 'Online Captains',
                style: GoogleFonts.cairo(
                    fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('captains_live')
                .where('isOnline', isEqualTo: true)
                .limit(8)
                .snapshots(),
            builder: (ctx, snap) {
              if (!snap.hasData) return const _SmallLoader();
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return Text(lang.t('empty'),
                    style: const TextStyle(color: AppColors.textSecondary));
              }
              return Column(
                children: docs.map((d) {
                  final data = d.data();
                  final name = (data['displayName'] ??
                          data['name'] ??
                          d.id)
                      .toString();
                  final inRide = data['currentRideId'] != null;
                  return _LiveRow(
                    icon:
                        inRide ? Icons.local_taxi : Icons.circle_outlined,
                    iconColor:
                        inRide ? AppColors.primary : AppColors.success,
                    primary: name,
                    secondary: inRide
                        ? (lang.isArabic ? 'في رحلة' : 'In a ride')
                        : (lang.isArabic ? 'متاح' : 'Available'),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LiveRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String primary;
  final String secondary;

  const _LiveRow({
    required this.icon,
    required this.iconColor,
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              primary,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            secondary,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SmallLoader extends StatelessWidget {
  const _SmallLoader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
          child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2))),
    );
  }
}

// ── Data models ───────────────────────────────────────────────────────────────

class _OverviewData {
  final int activeRides;
  final int requestedRides;
  final int onlineDrivers;
  final double todayRevenue;
  final int todayTrips;
  final int todayNewUsers;
  final int todayNewCaptains;
  final double cancelRate;
  final int completedToday;
  final List<_ChartPoint> revenuePoints;
  final List<_ChartPoint> tripPoints;

  const _OverviewData({
    required this.activeRides,
    required this.requestedRides,
    required this.onlineDrivers,
    required this.todayRevenue,
    required this.todayTrips,
    required this.todayNewUsers,
    required this.todayNewCaptains,
    required this.cancelRate,
    required this.completedToday,
    required this.revenuePoints,
    required this.tripPoints,
  });
}

class _ChartPoint {
  final String label;
  final double value;
  const _ChartPoint(this.label, this.value);
}

