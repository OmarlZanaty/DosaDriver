import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Import the design system tokens and components.
import '../ui/components/app_chip.dart';
import '../ui/components/details_dialog.dart';
import '../ui/components/kpi_card.dart';
import '../ui/components/ride_card.dart';
import '../ui/tokens/app_colors.dart';
import '../ui/tokens/app_radii.dart';


class RidesScreen extends StatefulWidget {
  final String search; // external search (topbar)
  const RidesScreen({super.key, required this.search});

  @override
  State<RidesScreen> createState() => _RidesScreenState();
}

class _RidesScreenState extends State<RidesScreen> {
  String _filter = 'all';

  // internal search in this screen (desktop-friendly)
  final _localSearch = TextEditingController();

  // UI statuses (normalized lower-case)
  static const _statuses = <String>[
    'requested',
    'accepted',
    'on_the_way',
    'arrived',
    'started',
    'completed',
    'cancelled',
  ];

  /// Normalize status from backend/firestore.
  /// Your backend writes: COMPLETED / CANCELED / etc (UPPERCASE)
  String _normStatus(Map<String, dynamic> data) {
    final raw = (data['status'] ?? data['backendStatus'] ?? '').toString().trim();
    final s = raw.toLowerCase();

    switch (s) {
      case 'requested':
        return 'requested';
      case 'accepted':
        return 'accepted';
      case 'on_the_way':
      case 'on-the-way':
      case 'ontheway':
        return 'on_the_way';
      case 'arrived':
        return 'arrived';
      case 'started':
        return 'started';
      case 'completed':
        return 'completed';
      case 'canceled':
      case 'cancelled':
        return 'cancelled';
      default:
        return s.isEmpty ? '' : s;
    }
  }

  /// Convert normalized UI status → backend canonical (UPPERCASE)
  String _toBackendStatus(String uiStatus) => uiStatus.toUpperCase();

  String _statusAr(String s) {
    switch (s) {
      case 'requested':
        return 'مطلوب';
      case 'accepted':
        return 'مقبول';
      case 'on_the_way':
        return 'في الطريق';
      case 'arrived':
        return 'وصل';
      case 'started':
        return 'بدأ';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      default:
        return s.isEmpty ? '—' : s;
    }
  }

  Color _statusBg(String s) {
    switch (s) {
      case 'requested':
        return AppColors.warningSoft;
      case 'accepted':
        return AppColors.primarySoft;
      case 'on_the_way':
        return AppColors.infoSoft;
      case 'arrived':
        return const Color(0xFFF3E8FF); // not defined in tokens, keep original
      case 'started':
        return AppColors.successSoft;
      case 'completed':
        return AppColors.neutralSoft;
      case 'cancelled':
        return AppColors.dangerSoft;
      default:
        return AppColors.neutralSoft;
    }
  }

  Color _statusFg(String s) {
    switch (s) {
      case 'requested':
        return const Color(0xFF92400E);
      case 'accepted':
        return const Color(0xFF1E40AF);
      case 'on_the_way':
        return const Color(0xFF3730A3);
      case 'arrived':
        return const Color(0xFF6B21A8);
      case 'started':
        return AppColors.success;
      case 'completed':
        return AppColors.textPrimary;
      case 'cancelled':
        return const Color(0xFF991B1B);
      default:
        return AppColors.textPrimary;
    }
  }

  String _fmtTime(dynamic v) {
    DateTime? d;

    if (v is Timestamp) d = v.toDate();
    if (v is int) d = DateTime.fromMillisecondsSinceEpoch(v);
    if (v is double) d = DateTime.fromMillisecondsSinceEpoch(v.toInt());
    if (v is String) {
      final parsed = DateTime.tryParse(v);
      if (parsed != null) d = parsed.toLocal();
    }

    if (d == null) return '—';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}  ${two(d.hour)}:${two(d.minute)}';
  }

  String _pickupAddr(Map<String, dynamic> data) {
    final v = data['pickupAddress'];
    if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    final pickup = data['pickup'];
    if (pickup is Map && pickup['addr'] != null) return pickup['addr'].toString();
    return '—';
  }

  String _dropAddr(Map<String, dynamic> data) {
    final v = data['destinationAddress'];
    if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    final drop = data['drop'];
    if (drop is Map && drop['addr'] != null) return drop['addr'].toString();
    return '—';
  }

  String _rideType(Map<String, dynamic> data) {
    final t = (data['rideType'] ?? '').toString().trim().toLowerCase();
    if (t.isEmpty) return '—';
    return t; // premium, economy, fair_value, scooter...
  }

  Color _typeBg(String t) {
    switch (t) {
      case 'premium':
        return const Color(0xFF111827);
      case 'economy':
        return const Color(0xFF2563EB);
      case 'fair_value':
        return const Color(0xFF059669);
      case 'scooter':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _typeLabelAr(String t) {
    switch (t) {
      case 'premium':
        return 'بريميوم';
      case 'economy':
        return 'اقتصادي';
      case 'fair_value':
        return 'سعر عادل';
      case 'scooter':
        return 'سكوتر';
      default:
        return t;
    }
  }

  bool _matchesSearch(DocumentSnapshot<Map<String, dynamic>> doc) {
    final external = widget.search.trim().toLowerCase();
    final local = _localSearch.text.trim().toLowerCase();
    final q = (local.isNotEmpty) ? local : external;
    if (q.isEmpty) return true;

    final data = doc.data() ?? {};
    final status = _normStatus(data);

    final riderId = (data['riderId'] ?? data['clientId'] ?? '').toString();
    final captainId = (data['captainId'] ?? data['driverId'] ?? '').toString();
    final captainUid = (data['captainUid'] ?? '').toString();

    final pickup = _pickupAddr(data);
    final drop = _dropAddr(data);

    final hay = <String>[
      doc.id,
      status,
      _rideType(data),
      riderId,
      captainId,
      captainUid,
      pickup,
      drop,
      (data['price'] ?? data['suggestedFare'] ?? '').toString(),
    ].join(' | ').toLowerCase();

    return hay.contains(q);
  }

  String _prettyJson(Map<String, dynamic> data) {
    const encoder = JsonEncoder.withIndent('  ');

    dynamic normalize(dynamic v) {
      if (v is Timestamp) return v.toDate().toIso8601String();
      if (v is Map) return v.map((k, val) => MapEntry(k.toString(), normalize(val)));
      if (v is List) return v.map(normalize).toList();
      return v;
    }

    final normalized = normalize(data) as Map<String, dynamic>;
    return encoder.convert(normalized);
  }

  Future<void> _copyToClipboard(String text, {String msg = 'Copied ✅'}) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _openRideDetailsDialog(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final jsonText = _prettyJson({'id': doc.id, ...data});
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return RideDetailsDialog(
          rideId: doc.id,
          jsonText: jsonText,
          onClose: () => Navigator.pop(context),
          onCopyJson: () => _copyToClipboard(jsonText, msg: 'Copied JSON ✅'),
          onCopyId: () => _copyToClipboard(doc.id, msg: 'Copied Ride ID ✅'),
        );
      },
    );
  }

  Widget _dialogActionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.textPrimary),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                fontFamily: 'Cairo',
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateRide(String rideId, Map<String, dynamic> patch) async {
    final newData = Map<String, dynamic>.from(patch);

    if (newData.containsKey('status')) {
      final ui = newData['status']?.toString().toLowerCase() ?? '';
      final normalized = _normStatus({'status': ui});
      final backend = _toBackendStatus(normalized.isEmpty ? ui : normalized);
      newData['status'] = backend;
      newData['backendStatus'] = backend;
    }

    newData['updatedAtMs'] = DateTime.now().millisecondsSinceEpoch;
    newData['updatedAt'] = DateTime.now().toUtc().toIso8601String();

    await FirebaseFirestore.instance.collection('rides').doc(rideId).set(
      newData,
      SetOptions(merge: true),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Ride updated')),
    );
  }

  Future<void> _adminCancel(String rideId) async {
    await _updateRide(rideId, {
      'status': 'cancelled',
      'cancelledAtMs': DateTime.now().millisecondsSinceEpoch,
      'cancelledBy': 'admin',
      'terminal': true,
    });
  }

  Future<void> _forceComplete(String rideId) async {
    await _updateRide(rideId, {
      'status': 'completed',
      'completedAtMs': DateTime.now().millisecondsSinceEpoch,
      'completedBy': 'admin',
      'terminal': true,
    });
  }

  // ---------- UI helpers (new design) ----------

  Widget _pageHeader() {
    return Row(
      children: [
        const Text(
          'الرحلات',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.infoSoft,
            borderRadius: BorderRadius.circular(AppRadii.full),
            border: Border.all(color: AppColors.border),
          ),
          child: const Text(
            'Live',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.info,
              fontSize: 12,
              fontFamily: 'Cairo',
            ),
          ),
        ),
        const Spacer(),
        SizedBox(
          width: 320,
          child: TextField(
            controller: _localSearch,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'بحث بالـ ID / الراكب / الكابتن / العنوان ...',
              filled: true,
              fillColor: AppColors.bgSurface,
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
              ),
              hintStyle: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _kpiRow({
    required int total,
    required int active,
    required int completed,
    required int cancelled,
    required double revenue,
  }) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 900;
        final List<Widget> children = [
          KpiCard(
            title: 'إجمالي',
            value: '$total',
            icon: Icons.list_alt,
            iconColor: AppColors.primary,
          ),
          KpiCard(
            title: 'نشطة',
            value: '$active',
            icon: Icons.bolt,
            iconColor: AppColors.info,
          ),
          KpiCard(
            title: 'مكتملة',
            value: '$completed',
            icon: Icons.check_circle,
            iconColor: AppColors.success,
          ),
          KpiCard(
            title: 'ملغية',
            value: '$cancelled',
            icon: Icons.cancel,
            iconColor: AppColors.danger,
          ),
          KpiCard(
            title: 'إيراد',
            value: 'EG ${revenue.toStringAsFixed(0)}',
            icon: Icons.payments,
            iconColor: AppColors.textPrimary,
          ),
        ];

        if (wide) {
          return Row(
            children: children
                .map((w) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: w,
                      ),
                    ))
                .toList()
                .reversed
                .toList(),
          );
        }
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: children.map((w) => SizedBox(width: 260, child: w)).toList(),
        );
      },
    );
  }

  // Deprecated: replaced by [KpiCard] from the design system. Kept for
  // backward compatibility but no longer used.

  Widget _filterChips() {
    // Helper to build each chip using the design system.
    Widget chip(String label, String value, {IconData? icon}) {
      return AppChip(
        label: label,
        icon: icon,
        active: _filter == value,
        onTap: () => setState(() => _filter = value),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('الكل', 'all', icon: Icons.grid_view),
          const SizedBox(width: 10),
          chip('مطلوب', 'requested'),
          const SizedBox(width: 10),
          chip('مقبول', 'accepted'),
          const SizedBox(width: 10),
          chip('في الطريق', 'on_the_way'),
          const SizedBox(width: 10),
          chip('وصل', 'arrived'),
          const SizedBox(width: 10),
          chip('بدأ', 'started'),
          const SizedBox(width: 10),
          chip('مكتمل', 'completed'),
          const SizedBox(width: 10),
          chip('ملغي', 'cancelled'),
        ],
      ),
    );
  }

  double _statusProgress(String s) {
    switch (s) {
      case 'requested':
        return 0.12;
      case 'accepted':
        return 0.28;
      case 'on_the_way':
        return 0.48;
      case 'arrived':
        return 0.68;
      case 'started':
        return 0.82;
      case 'completed':
        return 1.0;
      case 'cancelled':
        return 1.0;
      default:
        return 0.0;
    }
  }

  @override
  void dispose() {
    _localSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Background similar to modern SaaS
    return Container(
      color: AppColors.bgApp,
      padding: const EdgeInsets.all(18),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            _pageHeader(),
            const SizedBox(height: 14),
            _filterChips(),
            const SizedBox(height: 14),

            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('rides').orderBy('createdAt', descending: true).snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(
                      child: Text(
                        'Firestore error: ${snap.error}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    );
                  }
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snap.hasData || snap.data!.docs.isEmpty) {
                    return const Center(
                      child: Text('لا توجد رحلات حالياً', style: TextStyle(fontWeight: FontWeight.w900)),
                    );
                  }

                  var docs = snap.data!.docs;

                  // Filter by status
                  if (_filter != 'all') {
                    docs = docs.where((d) => _normStatus(d.data()) == _filter).toList();
                  }

                  // Search filter (local overrides external)
                  docs = docs.where((d) => _matchesSearch(d)).toList();

                  // KPI 계산 on the full snapshot BEFORE filters? (better: use full snapshot)
                  final allDocs = snap.data!.docs;
                  int total = allDocs.length;
                  int completed = allDocs.where((d) => _normStatus(d.data()) == 'completed').length;
                  int cancelled = allDocs.where((d) => _normStatus(d.data()) == 'cancelled').length;
                  int active = total - completed - cancelled;
                  double revenue = 0;
                  for (final d in allDocs) {
                    final st = _normStatus(d.data());
                    if (st == 'completed') {
                      final p = d.data()['price'] ?? d.data()['suggestedFare'];
                      if (p is num) revenue += p.toDouble();
                    }
                  }

                  return Column(
                    children: [
                      _kpiRow(
                        total: total,
                        active: active,
                        completed: completed,
                        cancelled: cancelled,
                        revenue: revenue,
                      ),
                      const SizedBox(height: 14),

                      Expanded(
                        child: docs.isEmpty
                            ? const Center(
                          child: Text('لا توجد نتائج مطابقة', style: TextStyle(fontWeight: FontWeight.w900)),
                        )
                            : ListView.separated(
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data();

                            final status = _normStatus(data);
                            final type = _rideType(data);

                            final riderId = (data['riderId'] ?? data['clientId'] ?? '').toString();
                            final captainId = (data['captainId'] ?? data['driverId'] ?? '').toString();

                            final pickup = _pickupAddr(data);
                            final drop = _dropAddr(data);

                            final priceNum = data['price'] ?? data['suggestedFare'];
                            final price = (priceNum is num) ? priceNum.toDouble() : null;

                            final createdAt = data['createdAtMs'] ?? data['createdAt'];

                            final progress = _statusProgress(status);

                            return RideCard(
                              onTap: () => _openRideDetailsDialog(doc),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    // top row
                                    Row(
                                      children: [
                                        _statusChip(status),
                                        const SizedBox(width: 10),
                                        _typeChip(type),
                                        const SizedBox(width: 10),
                                        Text(
                                          'ID: ${doc.id}',
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                            fontFamily: 'Cairo',
                                          ),
                                        ),
                                        const Spacer(),
                                        if (price != null)
                                          Text(
                                            'EG ${price.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.textPrimary,
                                              fontFamily: 'Cairo',
                                            ),
                                          ),
                                      ],
                                    ),

                                    const SizedBox(height: 10),

                                    // progress (for active)
                                    if (status != 'completed' && status != 'cancelled') ...[
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(AppRadii.full),
                                        child: LinearProgressIndicator(
                                          value: progress,
                                          minHeight: 8,
                                          backgroundColor: AppColors.border,
                                          valueColor: AlwaysStoppedAnimation<Color>(_statusFg(status)),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                    ],

                                    _addressRow(Icons.my_location, 'نقطة الانطلاق', pickup, AppColors.success),
                                    const SizedBox(height: 8),
                                    _addressRow(Icons.location_on, 'الوجهة', drop, AppColors.danger),

                                    const SizedBox(height: 14),

                                    // meta row
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        _pillMeta(Icons.person, 'Rider', riderId.isEmpty ? '—' : riderId),
                                        _pillMeta(Icons.local_taxi, 'Captain', captainId.isEmpty ? '—' : captainId),
                                        _pillMeta(Icons.schedule, 'Created', _fmtTime(createdAt)),
                                      ],
                                    ),

                                    const SizedBox(height: 14),
                                    const Divider(height: 1),
                                    const SizedBox(height: 12),

                                    // actions row (compact)
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        _miniAction(
                                          label: 'في الطريق',
                                          icon: Icons.directions_car,
                                          enabled: status == 'accepted',
                                          onTap: () => _updateRide(doc.id, {'status': 'on_the_way'}),
                                        ),
                                        _miniAction(
                                          label: 'وصل',
                                          icon: Icons.pin_drop,
                                          enabled: status == 'on_the_way',
                                          onTap: () => _updateRide(doc.id, {'status': 'arrived'}),
                                        ),
                                        _miniAction(
                                          label: 'بدأ',
                                          icon: Icons.play_circle,
                                          enabled: status == 'arrived',
                                          onTap: () => _updateRide(doc.id, {'status': 'started'}),
                                        ),
                                        _miniAction(
                                          label: 'إكمال',
                                          icon: Icons.check_circle,
                                          enabled: status != 'completed' && status != 'cancelled',
                                          onTap: () => _forceComplete(doc.id),
                                          tone: _MiniTone.success,
                                        ),
                                        _miniAction(
                                          label: 'إلغاء',
                                          icon: Icons.cancel,
                                          enabled: status != 'completed' && status != 'cancelled',
                                          onTap: () => _adminCancel(doc.id),
                                          tone: _MiniTone.danger,
                                        ),
                                        _miniAction(
                                          label: 'تفاصيل',
                                          icon: Icons.open_in_new,
                                          enabled: true,
                                          onTap: () => _openRideDetailsDialog(doc),
                                          tone: _MiniTone.neutral,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );

                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _statusBg(status),
        borderRadius: BorderRadius.circular(AppRadii.full),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        _statusAr(status),
        style: TextStyle(
          color: _statusFg(status),
          fontWeight: FontWeight.w900,
          fontSize: 12,
          fontFamily: 'Cairo',
        ),
      ),
    );
  }

  Widget _typeChip(String t) {
    final bg = _typeBg(t);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadii.full),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        _typeLabelAr(t),
        style: TextStyle(
          color: bg,
          fontWeight: FontWeight.w900,
          fontSize: 12,
          fontFamily: 'Cairo',
        ),
      ),
    );
  }

  Widget _addressRow(IconData icon, String title, String value, Color iconColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pillMeta(IconData icon, String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgApp,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textPrimary),
          const SizedBox(width: 8),
          Text(
            '$k: $v',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniAction({
    required String label,
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
    _MiniTone tone = _MiniTone.primary,
  }) {
    Color bg;
    Color fg;

    switch (tone) {
      case _MiniTone.success:
        bg = AppColors.successSoft;
        fg = AppColors.success;
        break;
      case _MiniTone.danger:
        bg = AppColors.dangerSoft;
        fg = AppColors.danger;
        break;
      case _MiniTone.neutral:
        bg = AppColors.neutralSoft;
        fg = AppColors.textPrimary;
        break;
      case _MiniTone.primary:
      default:
        bg = AppColors.infoSoft;
        fg = AppColors.info;
        break;
    }

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

enum _MiniTone { primary, success, danger, neutral }