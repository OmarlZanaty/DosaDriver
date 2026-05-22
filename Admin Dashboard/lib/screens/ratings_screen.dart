import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../core/lang_controller.dart';
import '../ui/tokens/app_colors.dart';

/// Admin: Ratings & Reviews
/// Reads from Firestore `rideRatings` (or `ratings`) collection.
/// Each doc: { rideId, captainUid, clientUid, captainRating, clientRating,
///             captainComment, clientComment, createdAt }
class RatingsScreen extends StatefulWidget {
  final String search;
  const RatingsScreen({super.key, required this.search});

  @override
  State<RatingsScreen> createState() => _RatingsScreenState();
}

class _RatingsScreenState extends State<RatingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  // Filter
  String _starFilter = 'all'; // all | 5 | 4 | 3 | <=2
  int _limit = 40;

  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        setState(() => _limit += 20);
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> _query(bool captainPov) {
    Query<Map<String, dynamic>> q =
        FirebaseFirestore.instance.collection('rideRatings');
    // Filter by captain-side or client-side ratings
    final ratingField = captainPov ? 'captainRating' : 'clientRating';
    if (_starFilter == '5') {
      q = q.where(ratingField, isEqualTo: 5);
    } else if (_starFilter == '4') {
      q = q.where(ratingField, isEqualTo: 4);
    } else if (_starFilter == '3') {
      q = q.where(ratingField, isEqualTo: 3);
    } else if (_starFilter == '<=2') {
      q = q.where(ratingField, isLessThanOrEqualTo: 2);
    }
    return q.orderBy('createdAt', descending: true).limit(_limit);
  }

  bool _matchesSearch(Map<String, dynamic> d) {
    final q = widget.search.toLowerCase().trim();
    if (q.isEmpty) return true;
    return (d['captainName'] ?? d['captainUid'] ?? '')
            .toString()
            .toLowerCase()
            .contains(q) ||
        (d['clientName'] ?? d['clientUid'] ?? '')
            .toString()
            .toLowerCase()
            .contains(q) ||
        (d['rideId'] ?? '').toString().toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final lang = LangController.instance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Stat summary row ──────────────────────────────────────────────
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('rideRatings')
              .limit(500)
              .snapshots(),
          builder: (ctx, snap) {
            if (!snap.hasData) return const SizedBox(height: 80);
            final docs = snap.data!.docs.map((d) => d.data()).toList();
            return _SummaryRow(docs: docs, lang: lang);
          },
        ),

        const SizedBox(height: 16),

        // ── Filter bar ────────────────────────────────────────────────────
        Row(
          children: [
            Text(
              lang.isArabic ? 'تصفية حسب النجوم:' : 'Filter by stars:',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary),
            ),
            const SizedBox(width: 10),
            ...[
              ('all', lang.t('all')),
              ('5', '★ 5'),
              ('4', '★ 4'),
              ('3', '★ 3'),
              ('<=2', '★ ≤2'),
            ].map((e) {
              final (key, label) = e;
              final sel = _starFilter == key;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => setState(() {
                    _starFilter = key;
                    _limit = 40;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.warning : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color:
                              sel ? AppColors.warning : AppColors.border),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: sel ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),

        const SizedBox(height: 12),

        // ── Tabs ──────────────────────────────────────────────────────────
        TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: GoogleFonts.cairo(
              fontWeight: FontWeight.w800, fontSize: 13),
          tabs: [
            Tab(
                text: lang.isArabic
                    ? 'تقييمات الكباتن'
                    : 'Captain Ratings'),
            Tab(
                text: lang.isArabic
                    ? 'تقييمات العملاء'
                    : 'Client Ratings'),
          ],
        ),

        const SizedBox(height: 12),

        // ── Tab content ───────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _RatingsList(
                query: _query(true),
                ratingField: 'captainRating',
                commentField: 'captainComment',
                nameField: 'captainName',
                scroll: _scroll,
                matchesSearch: _matchesSearch,
                lang: lang,
              ),
              _RatingsList(
                query: _query(false),
                ratingField: 'clientRating',
                commentField: 'clientComment',
                nameField: 'clientName',
                scroll: _scroll,
                matchesSearch: _matchesSearch,
                lang: lang,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Summary row ───────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final List<Map<String, dynamic>> docs;
  final LangController lang;

  const _SummaryRow({required this.docs, required this.lang});

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) return const SizedBox(height: 80);

    // Compute stats for captain ratings
    final captainRatings = docs
        .where((d) => d['captainRating'] != null)
        .map((d) => (d['captainRating'] as num).toDouble())
        .toList();

    final clientRatings = docs
        .where((d) => d['clientRating'] != null)
        .map((d) => (d['clientRating'] as num).toDouble())
        .toList();

    double avg(List<double> list) =>
        list.isEmpty ? 0 : list.reduce((a, b) => a + b) / list.length;

    // Distribution for chart
    final dist = [0, 0, 0, 0, 0]; // index 0 = 1-star ... 4 = 5-star
    for (final r in captainRatings) {
      final i = r.round().clamp(1, 5) - 1;
      dist[i]++;
    }

    return Row(
      children: [
        // Summary cards
        _SumCard(
          label: lang.isArabic ? 'متوسط تقييم الكباتن' : 'Avg Captain Rating',
          value: avg(captainRatings).toStringAsFixed(1),
          icon: Icons.star_rounded,
          color: AppColors.warning,
        ),
        const SizedBox(width: 12),
        _SumCard(
          label: lang.isArabic ? 'متوسط تقييم العملاء' : 'Avg Client Rating',
          value: avg(clientRatings).toStringAsFixed(1),
          icon: Icons.star_outlined,
          color: AppColors.blue,
        ),
        const SizedBox(width: 12),
        _SumCard(
          label: lang.isArabic ? 'إجمالي التقييمات' : 'Total Ratings',
          value: docs.length.toString(),
          icon: Icons.reviews_outlined,
          color: AppColors.success,
        ),
        const SizedBox(width: 16),
        // Distribution mini-chart
        Expanded(
          child: Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: List.generate(5, (i) {
                final count = dist[i];
                final maxCount = dist.isEmpty
                    ? 1
                    : dist.reduce((a, b) => a > b ? a : b);
                final frac = maxCount == 0 ? 0.0 : count / maxCount;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: FractionallySizedBox(
                            heightFactor: frac.clamp(0.05, 1.0),
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _starColor(i + 1),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${i + 1}★',
                          style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  Color _starColor(int stars) {
    if (stars >= 4) return AppColors.success;
    if (stars == 3) return AppColors.warning;
    return AppColors.danger;
  }
}

class _SumCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SumCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: GoogleFonts.cairo(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Ratings list ──────────────────────────────────────────────────────────────

class _RatingsList extends StatelessWidget {
  final Query<Map<String, dynamic>> query;
  final String ratingField;
  final String commentField;
  final String nameField;
  final ScrollController scroll;
  final bool Function(Map<String, dynamic>) matchesSearch;
  final LangController lang;

  const _RatingsList({
    required this.query,
    required this.ratingField,
    required this.commentField,
    required this.nameField,
    required this.scroll,
    required this.matchesSearch,
    required this.lang,
  });

  String _fmt(dynamic ts) {
    if (ts == null) return '—';
    DateTime dt;
    if (ts is Timestamp) {
      dt = ts.toDate();
    } else {
      return '—';
    }
    return DateFormat('dd MMM yyyy  HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (ctx, snap) {
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

        final docs = snap.data!.docs
            .where((d) => matchesSearch(d.data()))
            .toList();

        if (docs.isEmpty) {
          return Center(
            child: Text(lang.t('empty'),
                style:
                    const TextStyle(color: AppColors.textSecondary)),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: ListView.separated(
            controller: scroll,
            itemCount: docs.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (ctx, i) {
              final d = docs[i].data();
              final rating =
                  (d[ratingField] as num?)?.toInt() ?? 0;
              final comment =
                  (d[commentField] ?? '').toString();
              final name = (d[nameField] ?? '—').toString();
              final rideId = (d['rideId'] ?? '').toString();
              final date = _fmt(d['createdAt']);

              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 18,
                      backgroundColor:
                          _ratingBg(rating),
                      child: Text(
                        name.isNotEmpty
                            ? name[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _ratingFg(rating),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Name + comment
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (comment.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              comment,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Stars
                    _StarRow(stars: rating),
                    const SizedBox(width: 16),
                    // Ride ID
                    Text(
                      rideId.isNotEmpty
                          ? '#${rideId.substring(0, rideId.length.clamp(0, 8))}'
                          : '',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 16),
                    // Date
                    Text(
                      date,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Color _ratingBg(int r) {
    if (r >= 4) return AppColors.successSoft;
    if (r == 3) return AppColors.warningSoft;
    return AppColors.dangerSoft;
  }

  Color _ratingFg(int r) {
    if (r >= 4) return AppColors.success;
    if (r == 3) return AppColors.warning;
    return AppColors.danger;
  }
}

class _StarRow extends StatelessWidget {
  final int stars;
  const _StarRow({required this.stars});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 14,
          color: i < stars ? AppColors.warning : AppColors.border,
        ),
      ),
    );
  }
}
