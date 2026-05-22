import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/lang_controller.dart';
import '../ui/tokens/app_colors.dart';

/// Admin: Captain Intelligence Dashboard
/// Aggregates per-captain stats from Firestore:
///   - captains_live (isOnline, currentRideId)
///   - users (drivers collection or captains sub-collection)
///   - rides (aggregated per captainUid)
class CaptainIntelligenceScreen extends StatefulWidget {
  const CaptainIntelligenceScreen({super.key});

  @override
  State<CaptainIntelligenceScreen> createState() =>
      _CaptainIntelligenceScreenState();
}

class _CaptainIntelligenceScreenState
    extends State<CaptainIntelligenceScreen> {
  _SortBy _sortBy = _SortBy.trips;
  bool _sortDesc = true;
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = LangController.instance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Title + KPI row ─────────────────────────────────────────────────
        Row(
          children: [
            Text(
              lang.t('captain_intel'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Live KPI cards ──────────────────────────────────────────────────
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('captains_live')
              .snapshots(),
          builder: (context, liveSnap) {
            final liveDocs = liveSnap.data?.docs ?? [];
            final online =
                liveDocs.where((d) => d.data()['isOnline'] == true).length;
            final inRide = liveDocs
                .where((d) => d.data()['currentRideId'] != null)
                .length;

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('captains')
                  .snapshots(),
              builder: (ctx, captainSnap) {
                final total = captainSnap.data?.docs.length ?? 0;

                return Row(
                  children: [
                    _KpiCard(
                      label: lang.t('online_captains'),
                      value: online.toString(),
                      icon: Icons.wifi,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 12),
                    _KpiCard(
                      label: lang.isArabic
                          ? 'في رحلة الآن'
                          : 'In a Ride',
                      value: inRide.toString(),
                      icon: Icons.local_taxi,
                      color: AppColors.blue,
                    ),
                    const SizedBox(width: 12),
                    _KpiCard(
                      label: lang.isArabic
                          ? 'إجمالي الكباتن'
                          : 'Total Captains',
                      value: total.toString(),
                      icon: Icons.directions_car,
                      color: AppColors.info,
                    ),
                  ],
                );
              },
            );
          },
        ),

        const SizedBox(height: 16),

        // ── Sort bar ─────────────────────────────────────────────────────────
        _SortBar(
          sortBy: _sortBy,
          sortDesc: _sortDesc,
          lang: lang,
          onSortChanged: (v) => setState(() {
            if (_sortBy == v) {
              _sortDesc = !_sortDesc;
            } else {
              _sortBy = v;
              _sortDesc = true;
            }
          }),
        ),
        const SizedBox(height: 10),

        // ── Captain table ───────────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('captains')
                .limit(200)
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: Text(
                    '${lang.t("error")}: ${snap.error}',
                    style: const TextStyle(color: AppColors.danger),
                  ),
                );
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              var rows = snap.data!.docs
                  .map((d) => _CaptainRow.fromDoc(d.id, d.data()))
                  .toList();

              // Sort
              rows.sort((a, b) {
                final cmp = switch (_sortBy) {
                  _SortBy.trips =>
                    a.totalTrips.compareTo(b.totalTrips),
                  _SortBy.rating =>
                    a.avgRating.compareTo(b.avgRating),
                  _SortBy.earnings =>
                    a.totalEarnings.compareTo(b.totalEarnings),
                  _SortBy.acceptance =>
                    a.acceptanceRate.compareTo(b.acceptanceRate),
                };
                return _sortDesc ? -cmp : cmp;
              });

              if (rows.isEmpty) {
                return Center(
                  child: Text(lang.t('empty'),
                      style: const TextStyle(
                          color: AppColors.textSecondary)),
                );
              }

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _TableHeader(lang: lang),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.separated(
                        controller: _scroll,
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                        ),
                        itemBuilder: (ctx, i) {
                          return _CaptainRowWidget(
                            row: rows[i],
                            rank: i + 1,
                            lang: lang,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Sort enum ─────────────────────────────────────────────────────────────────

enum _SortBy { trips, rating, earnings, acceptance }

// ── Sort bar ──────────────────────────────────────────────────────────────────

class _SortBar extends StatelessWidget {
  final _SortBy sortBy;
  final bool sortDesc;
  final LangController lang;
  final ValueChanged<_SortBy> onSortChanged;

  const _SortBar({
    required this.sortBy,
    required this.sortDesc,
    required this.lang,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          lang.isArabic ? 'ترتيب حسب:' : 'Sort by:',
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary),
        ),
        const SizedBox(width: 10),
        _chip(lang.isArabic ? 'الرحلات' : 'Trips', _SortBy.trips),
        const SizedBox(width: 6),
        _chip(lang.isArabic ? 'التقييم' : 'Rating', _SortBy.rating),
        const SizedBox(width: 6),
        _chip(
            lang.isArabic ? 'الأرباح' : 'Earnings', _SortBy.earnings),
        const SizedBox(width: 6),
        _chip(lang.isArabic ? 'القبول' : 'Acceptance',
            _SortBy.acceptance),
      ],
    );
  }

  Widget _chip(String label, _SortBy v) {
    final selected = sortBy == v;
    return GestureDetector(
      onTap: () => onSortChanged(v),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.bgApp,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 3),
              Icon(
                sortDesc
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                size: 12,
                color: AppColors.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Table header ──────────────────────────────────────────────────────────────

class _TableHeader extends StatelessWidget {
  final LangController lang;
  const _TableHeader({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.bgApp,
      child: Row(
        children: [
          const SizedBox(width: 32), // rank
          Expanded(
              flex: 3,
              child: _h(lang.isArabic ? 'الكابتن' : 'Captain')),
          Expanded(
              flex: 2,
              child: _h(lang.isArabic ? 'الهاتف' : 'Phone')),
          Expanded(
              flex: 1,
              child: _h(lang.isArabic ? 'الرحلات' : 'Trips')),
          Expanded(
              flex: 1,
              child: _h(lang.isArabic ? 'التقييم' : 'Rating')),
          Expanded(
              flex: 2,
              child: _h(lang.isArabic ? 'الأرباح' : 'Earnings')),
          Expanded(
              flex: 2,
              child:
                  _h(lang.isArabic ? 'نسبة القبول' : 'Acceptance')),
          Expanded(
              flex: 1,
              child:
                  _h(lang.isArabic ? 'الحالة' : 'Status')),
        ],
      ),
    );
  }

  Widget _h(String t) => Text(
        t,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
          letterSpacing: 0.3,
        ),
      );
}

// ── Captain row widget ────────────────────────────────────────────────────────

class _CaptainRowWidget extends StatelessWidget {
  final _CaptainRow row;
  final int rank;
  final LangController lang;

  const _CaptainRowWidget({
    required this.row,
    required this.rank,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 32,
            child: Text(
              '#$rank',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary),
            ),
          ),
          // Name + avatar
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor:
                      row.isOnline ? AppColors.successSoft : AppColors.neutralSoft,
                  child: Text(
                    row.name.isNotEmpty ? row.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: row.isOnline
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    row.name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Phone
          Expanded(
            flex: 2,
            child: Text(
              row.phone,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          // Total trips
          Expanded(
            flex: 1,
            child: Text(
              row.totalTrips.toString(),
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          // Rating
          Expanded(
            flex: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded,
                    size: 14, color: AppColors.warning),
                const SizedBox(width: 3),
                Text(
                  row.avgRating.toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          // Earnings
          Expanded(
            flex: 2,
            child: Text(
              '${row.totalEarnings.toStringAsFixed(0)} EGP',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success),
            ),
          ),
          // Acceptance rate
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: row.acceptanceRate / 100,
                    backgroundColor: AppColors.neutralSoft,
                    color: row.acceptanceRate >= 70
                        ? AppColors.success
                        : row.acceptanceRate >= 40
                            ? AppColors.warning
                            : AppColors.danger,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${row.acceptanceRate.toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          // Online status
          Expanded(
            flex: 1,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: row.isOnline
                    ? AppColors.successSoft
                    : AppColors.neutralSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                row.isOnline
                    ? (lang.isArabic ? 'متصل' : 'Online')
                    : (lang.isArabic ? 'غائب' : 'Offline'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: row.isOnline
                      ? AppColors.success
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── KPI Card ──────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: GoogleFonts.cairo(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
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

// ── Data model ────────────────────────────────────────────────────────────────

class _CaptainRow {
  final String uid;
  final String name;
  final String phone;
  final int totalTrips;
  final double avgRating;
  final double totalEarnings;
  final double acceptanceRate;
  final bool isOnline;

  const _CaptainRow({
    required this.uid,
    required this.name,
    required this.phone,
    required this.totalTrips,
    required this.avgRating,
    required this.totalEarnings,
    required this.acceptanceRate,
    required this.isOnline,
  });

  factory _CaptainRow.fromDoc(
      String id, Map<String, dynamic> d) {
    double toDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0.0;
    }

    int toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    return _CaptainRow(
      uid: id,
      name: (d['displayName'] ?? d['name'] ?? d['fullName'] ?? '')
          .toString(),
      phone:
          (d['phone'] ?? d['phoneNumber'] ?? '—').toString(),
      totalTrips: toInt(d['totalTrips'] ?? d['total_trips']),
      avgRating: toDouble(d['avgRating'] ?? d['rating']),
      totalEarnings:
          toDouble(d['totalEarnings'] ?? d['total_earnings']),
      acceptanceRate:
          toDouble(d['acceptanceRate'] ?? d['acceptance_rate']),
      isOnline: d['isOnline'] == true,
    );
  }
}
