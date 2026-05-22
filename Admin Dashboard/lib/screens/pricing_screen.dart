import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/lang_controller.dart';
import '../ui/tokens/app_colors.dart';

/// Admin: Pricing / Fare Management
/// Reads from Firestore `rideTypePricing` collection.
/// Each doc ID is the ride type (FAIR_VALUE, PREMIUM, CUTE_CAR, SCOOTER).
class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  static const _rideTypes = [
    _RideType(
      id: 'FAIR_VALUE',
      labelAr: 'القيمة العادلة',
      labelEn: 'Fair Value',
      icon: Icons.local_taxi,
      color: AppColors.primary,
    ),
    _RideType(
      id: 'PREMIUM',
      labelAr: 'بريميوم',
      labelEn: 'Premium',
      icon: Icons.directions_car,
      color: AppColors.info,
    ),
    _RideType(
      id: 'CUTE_CAR',
      labelAr: 'السيارة اللطيفة',
      labelEn: 'Cute Car',
      icon: Icons.electric_car,
      color: AppColors.success,
    ),
    _RideType(
      id: 'SCOOTER',
      labelAr: 'الدراجة',
      labelEn: 'Scooter',
      icon: Icons.two_wheeler,
      color: AppColors.warning,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final lang = LangController.instance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title row
        Row(
          children: [
            Text(
              lang.t('pricing'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.blueSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                lang.isArabic ? 'تحديث فوري عبر Firestore' : 'Live Firestore',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.blue),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Grid of ride type cards
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('rideTypePricing')
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: Text(
                    '${lang.t("error")}: ${snap.error}',
                    style:
                        const TextStyle(color: AppColors.danger),
                  ),
                );
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              // Build a map: rideTypeId → data
              final dataMap = <String, Map<String, dynamic>>{};
              for (final doc in snap.data!.docs) {
                dataMap[doc.id] = doc.data();
              }

              return GridView.builder(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.6,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _rideTypes.length,
                itemBuilder: (context, i) {
                  final rt = _rideTypes[i];
                  final d = dataMap[rt.id] ?? {};
                  return _PricingCard(
                    rideType: rt,
                    data: d,
                    lang: lang,
                    onEdit: () =>
                        _showEditDialog(context, rt, d, lang),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showEditDialog(
    BuildContext context,
    _RideType rt,
    Map<String, dynamic> current,
    LangController lang,
  ) {
    final fields = <String, TextEditingController>{
      'baseFare': TextEditingController(
          text: (current['baseFare'] ?? '0').toString()),
      'perKm': TextEditingController(
          text: (current['perKm'] ?? '0').toString()),
      'perMin': TextEditingController(
          text: (current['perMin'] ?? '0').toString()),
      'minFare': TextEditingController(
          text: (current['minFare'] ?? '0').toString()),
      // Use minPrice / maxPrice / averagePrice — the same field names that
      // the client & captain apps read.  Also fall back to the old names
      // (minOffer / maxOffer / avgPrice) so existing Firestore data is shown.
      'minPrice': TextEditingController(
          text: (current['minPrice'] ?? current['minOffer'] ?? '0').toString()),
      'maxPrice': TextEditingController(
          text: (current['maxPrice'] ?? current['maxOffer'] ?? '0').toString()),
      'averagePrice': TextEditingController(
          text: (current['averagePrice'] ?? current['avgPrice'] ?? '0')
              .toString()),
      'commissionPct': TextEditingController(
          text: (current['commissionPct'] ?? '10').toString()),
    };

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(rt.icon, color: rt.color, size: 22),
            const SizedBox(width: 8),
            Text(
              lang.isArabic ? rt.labelAr : rt.labelEn,
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogRow(lang.t('base_fare'),
                    fields['baseFare']!),
                _dialogRow(lang.t('per_km'), fields['perKm']!),
                _dialogRow(lang.t('per_min'), fields['perMin']!),
                _dialogRow(lang.t('min_fare'), fields['minFare']!),
                _dialogRow(lang.t('min_offer'), fields['minPrice']!),
                _dialogRow(
                    lang.t('max_offer'), fields['maxPrice']!),
                _dialogRow(
                    lang.t('avg_price'), fields['averagePrice']!),
                _dialogRow(lang.t('commission_pct'),
                    fields['commissionPct']!,
                    suffix: '%'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final updates = <String, dynamic>{};
              fields.forEach((key, ctrl) {
                final val =
                    double.tryParse(ctrl.text.trim()) ?? 0;
                updates[key] = val;
              });
              await FirebaseFirestore.instance
                  .collection('rideTypePricing')
                  .doc(rt.id)
                  .set(updates, SetOptions(merge: true));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(lang.t('save')),
          ),
        ],
      ),
    ).then((_) {
      for (final c in fields.values) {
        c.dispose();
      }
    });
  }

  Widget _dialogRow(String label, TextEditingController ctrl,
      {String suffix = 'EGP'}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: TextField(
              controller: ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                suffixText: suffix,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pricing Card ─────────────────────────────────────────────────────────────

class _PricingCard extends StatelessWidget {
  final _RideType rideType;
  final Map<String, dynamic> data;
  final LangController lang;
  final VoidCallback onEdit;

  const _PricingCard({
    required this.rideType,
    required this.data,
    required this.lang,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    String fmt(String key, [String? alt]) {
      final v = data[key] ?? (alt != null ? data[alt] : null) ?? 0;
      return v.toString();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: rideType.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(rideType.icon,
                    color: rideType.color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  lang.isArabic ? rideType.labelAr : rideType.labelEn,
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined,
                    size: 18, color: AppColors.textSecondary),
                tooltip: lang.t('edit'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.8,
              crossAxisSpacing: 8,
              mainAxisSpacing: 4,
              children: [
                _statItem(lang.t('base_fare'), fmt('baseFare')),
                _statItem(lang.t('per_km'), fmt('perKm')),
                _statItem(lang.t('min_fare'), fmt('minFare')),
                _statItem(lang.t('commission_pct'),
                    '${fmt('commissionPct')}%'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: rideType.color,
          ),
        ),
      ],
    );
  }
}

// ── Model ────────────────────────────────────────────────────────────────────

class _RideType {
  final String id;
  final String labelAr;
  final String labelEn;
  final IconData icon;
  final Color color;

  const _RideType({
    required this.id,
    required this.labelAr,
    required this.labelEn,
    required this.icon,
    required this.color,
  });
}
