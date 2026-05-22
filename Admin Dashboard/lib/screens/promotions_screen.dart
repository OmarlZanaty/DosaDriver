import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../core/lang_controller.dart';
import '../ui/tokens/app_colors.dart';

/// Admin: Promotions & Referrals (Part 10)
/// Reads from Firestore `promotions` collection.
/// Supports: create promo code, activate/deactivate, view usage stats.
class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key});

  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = LangController.instance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ─────────────────────────────────────────────────────────
        Row(
          children: [
            Text(
              lang.t('promotions'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _showCreateDialog(context, lang),
              icon: const Icon(Icons.add, size: 16),
              label: Text(
                lang.isArabic ? 'كود جديد' : 'New Code',
                style:
                    GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── Summary cards from Firestore ──────────────────────────────────
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('promotions')
              .snapshots(),
          builder: (ctx, snap) {
            final docs = snap.data?.docs ?? [];
            final active =
                docs.where((d) => d.data()['active'] == true).length;
            final totalUses = docs.fold<int>(
              0,
              (sum, d) => sum + ((d.data()['usageCount'] as num?) ?? 0).toInt(),
            );
            return Row(
              children: [
                _SummaryChip(
                  icon: Icons.local_offer_outlined,
                  label: lang.isArabic ? 'إجمالي الكودات' : 'Total Codes',
                  value: docs.length.toString(),
                  color: AppColors.info,
                ),
                const SizedBox(width: 12),
                _SummaryChip(
                  icon: Icons.check_circle_outline,
                  label: lang.isArabic ? 'نشطة' : 'Active',
                  value: active.toString(),
                  color: AppColors.success,
                ),
                const SizedBox(width: 12),
                _SummaryChip(
                  icon: Icons.bar_chart_outlined,
                  label: lang.isArabic ? 'إجمالي الاستخدامات' : 'Total Uses',
                  value: totalUses.toString(),
                  color: AppColors.primary,
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 16),

        // ── Tabs ──────────────────────────────────────────────────────────
        TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle:
              GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 13),
          tabs: [
            Tab(text: lang.isArabic ? 'كودات الخصم' : 'Promo Codes'),
            Tab(text: lang.isArabic ? 'الإحالات' : 'Referrals'),
          ],
        ),

        const SizedBox(height: 12),

        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              // Promo codes list
              _PromoCodesList(lang: lang),
              // Referrals list
              _ReferralsList(lang: lang),
            ],
          ),
        ),
      ],
    );
  }

  void _showCreateDialog(BuildContext context, LangController lang) {
    final codeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final discountCtrl = TextEditingController(text: '10');
    final maxUsesCtrl = TextEditingController(text: '100');
    String discountType = 'percent'; // percent | flat

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(
            lang.isArabic ? 'إنشاء كود خصم' : 'Create Promo Code',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Code
                  TextField(
                    controller: codeCtrl,
                    decoration: InputDecoration(
                      labelText: lang.isArabic ? 'الكود' : 'Code',
                      hintText: 'PROMO2025',
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 12),
                  // Description
                  TextField(
                    controller: descCtrl,
                    decoration: InputDecoration(
                      labelText:
                          lang.isArabic ? 'الوصف' : 'Description',
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Discount type toggle
                  Row(
                    children: [
                      Text(lang.isArabic ? 'نوع الخصم:' : 'Discount type:',
                          style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        label: Text(lang.isArabic ? 'نسبة %' : 'Percent'),
                        selected: discountType == 'percent',
                        onSelected: (_) =>
                            setDlgState(() => discountType = 'percent'),
                        selectedColor: AppColors.primarySoft,
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: Text(lang.isArabic ? 'مبلغ ثابت' : 'Flat'),
                        selected: discountType == 'flat',
                        onSelected: (_) =>
                            setDlgState(() => discountType = 'flat'),
                        selectedColor: AppColors.primarySoft,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Discount value
                  TextField(
                    controller: discountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    decoration: InputDecoration(
                      labelText: lang.isArabic ? 'قيمة الخصم' : 'Discount Value',
                      suffixText: discountType == 'percent' ? '%' : 'EGP',
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Max uses
                  TextField(
                    controller: maxUsesCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      labelText:
                          lang.isArabic ? 'الحد الأقصى للاستخدام' : 'Max Uses',
                    ),
                  ),
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
                final code = codeCtrl.text.trim().toUpperCase();
                if (code.isEmpty) return;
                await FirebaseFirestore.instance
                    .collection('promotions')
                    .doc(code)
                    .set({
                  'code': code,
                  'description': descCtrl.text.trim(),
                  'discountType': discountType,
                  'discountValue':
                      double.tryParse(discountCtrl.text.trim()) ?? 10,
                  'maxUses':
                      int.tryParse(maxUsesCtrl.text.trim()) ?? 100,
                  'usageCount': 0,
                  'active': true,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(lang.t('save')),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Promo Codes List ──────────────────────────────────────────────────────────

class _PromoCodesList extends StatelessWidget {
  final LangController lang;
  const _PromoCodesList({required this.lang});

  String _fmt(dynamic ts) {
    if (ts == null) return '—';
    if (ts is Timestamp) {
      return DateFormat('dd MMM yyyy').format(ts.toDate());
    }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('promotions')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return Center(
            child: Text('${lang.t("error")}: ${snap.error}',
                style: const TextStyle(color: AppColors.danger)),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_offer_outlined,
                    size: 48, color: AppColors.border),
                const SizedBox(height: 12),
                Text(lang.t('empty'),
                    style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ),
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
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                color: AppColors.bgApp,
                child: Row(
                  children: [
                    Expanded(
                        flex: 2,
                        child: _hCell(lang.isArabic ? 'الكود' : 'Code')),
                    Expanded(
                        flex: 3,
                        child:
                            _hCell(lang.isArabic ? 'الوصف' : 'Description')),
                    Expanded(
                        flex: 2,
                        child: _hCell(
                            lang.isArabic ? 'الخصم' : 'Discount')),
                    Expanded(
                        flex: 1,
                        child: _hCell(
                            lang.isArabic ? 'الاستخدامات' : 'Uses')),
                    Expanded(
                        flex: 2,
                        child: _hCell(lang.t('status'))),
                    Expanded(
                        flex: 2,
                        child:
                            _hCell(lang.isArabic ? 'تاريخ الإنشاء' : 'Created')),
                    const SizedBox(width: 60),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final d = docs[i].data();
                    final code = d['code']?.toString() ?? docs[i].id;
                    final desc = d['description']?.toString() ?? '';
                    final dType = d['discountType']?.toString() ?? 'percent';
                    final dVal = (d['discountValue'] as num?)?.toDouble() ?? 0;
                    final uses = (d['usageCount'] as num?)?.toInt() ?? 0;
                    final maxUses = (d['maxUses'] as num?)?.toInt() ?? 0;
                    final active = d['active'] == true;
                    final created = _fmt(d['createdAt']);

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          // Code (tap to copy)
                          Expanded(
                            flex: 2,
                            child: GestureDetector(
                              onTap: () {
                                Clipboard.setData(
                                    ClipboardData(text: code));
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text('📋 $code'),
                                    duration:
                                        const Duration(seconds: 1),
                                  ),
                                );
                              },
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius:
                                      BorderRadius.circular(6),
                                ),
                                child: Text(
                                  code,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Description
                          Expanded(
                            flex: 3,
                            child: Text(
                              desc,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Discount
                          Expanded(
                            flex: 2,
                            child: Text(
                              dType == 'percent'
                                  ? '${dVal.toStringAsFixed(0)}%'
                                  : '${dVal.toStringAsFixed(0)} EGP',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary),
                            ),
                          ),
                          // Uses
                          Expanded(
                            flex: 1,
                            child: Text(
                              maxUses > 0
                                  ? '$uses / $maxUses'
                                  : uses.toString(),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary),
                            ),
                          ),
                          // Status
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: active
                                    ? AppColors.successSoft
                                    : AppColors.neutralSoft,
                                borderRadius:
                                    BorderRadius.circular(20),
                              ),
                              child: Text(
                                active
                                    ? lang.t('active')
                                    : (lang.isArabic
                                        ? 'معطل'
                                        : 'Inactive'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: active
                                      ? AppColors.success
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          // Created
                          Expanded(
                            flex: 2,
                            child: Text(
                              created,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary),
                            ),
                          ),
                          // Toggle button
                          SizedBox(
                            width: 60,
                            child: Switch(
                              value: active,
                              activeColor: AppColors.success,
                              onChanged: (v) =>
                                  FirebaseFirestore.instance
                                      .collection('promotions')
                                      .doc(docs[i].id)
                                      .update({'active': v}),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _hCell(String t) => Text(
        t,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
          letterSpacing: 0.3,
        ),
      );
}

// ── Referrals List ────────────────────────────────────────────────────────────

class _ReferralsList extends StatelessWidget {
  final LangController lang;
  const _ReferralsList({required this.lang});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('referrals')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return Center(
            child: Text('${lang.t("error")}: ${snap.error}',
                style: const TextStyle(color: AppColors.danger)),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.share_outlined,
                    size: 48, color: AppColors.border),
                const SizedBox(height: 12),
                Text(
                  lang.isArabic
                      ? 'لا توجد إحالات بعد'
                      : 'No referrals yet',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (ctx, i) {
              final d = docs[i].data();
              final referrer =
                  (d['referrerName'] ?? d['referrerPhone'] ?? '—')
                      .toString();
              final referee =
                  (d['refereeName'] ?? d['refereePhone'] ?? '—')
                      .toString();
              final bonus = (d['bonusAmount'] as num?)?.toDouble() ?? 0;
              final redeemed = d['redeemed'] == true;

              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang.isArabic ? 'المُحيل' : 'Referrer',
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary),
                          ),
                          Text(
                            referrer,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 12, color: AppColors.border),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang.isArabic ? 'المُحال إليه' : 'Referee',
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary),
                          ),
                          Text(
                            referee,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${bonus.toStringAsFixed(0)} EGP',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: redeemed
                            ? AppColors.successSoft
                            : AppColors.warningSoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        redeemed
                            ? (lang.isArabic ? 'تم الاسترداد' : 'Redeemed')
                            : (lang.isArabic ? 'معلق' : 'Pending'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: redeemed
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      ),
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
}

// ── Summary chip ──────────────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.value,
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
