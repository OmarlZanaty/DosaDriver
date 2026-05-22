import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/lang_controller.dart';
import '../ui/tokens/app_colors.dart';

/// Admin: Clients Management
/// Reads from Firestore `users` where role == 'client' (or no role filter
/// if the collection only holds clients). Supports search by name/phone,
/// status filter, block/unblock, and infinite scroll pagination.
class ClientsScreen extends StatefulWidget {
  final String search;
  const ClientsScreen({super.key, required this.search});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final ScrollController _scroll = ScrollController();
  int _limit = 30;
  final int _pageStep = 30;

  String _statusFilter = 'all'; // all | active | blocked

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      setState(() => _limit += _pageStep);
    }
  }

  Query<Map<String, dynamic>> _query() {
    Query<Map<String, dynamic>> q =
        FirebaseFirestore.instance.collection('users');
    if (_statusFilter == 'blocked') {
      q = q.where('blocked', isEqualTo: true);
    } else if (_statusFilter == 'active') {
      q = q.where('blocked', isEqualTo: false);
    }
    return q.orderBy('createdAt', descending: true).limit(_limit);
  }

  bool _matchesSearch(Map<String, dynamic> d) {
    final q = widget.search.toLowerCase().trim();
    if (q.isEmpty) return true;
    return (d['displayName'] ?? d['name'] ?? '')
            .toString()
            .toLowerCase()
            .contains(q) ||
        (d['phone'] ?? d['phoneNumber'] ?? '')
            .toString()
            .toLowerCase()
            .contains(q) ||
        (d['email'] ?? '').toString().toLowerCase().contains(q);
  }

  Future<void> _toggleBlock(String uid, bool currentlyBlocked) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'blocked': !currentlyBlocked});
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '—';
    DateTime dt;
    if (ts is Timestamp) {
      dt = ts.toDate();
    } else if (ts is String) {
      dt = DateTime.tryParse(ts) ?? DateTime.now();
    } else {
      return '—';
    }
    return DateFormat('dd MMM yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final lang = LangController.instance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Toolbar ─────────────────────────────────────────────────────────
        _Toolbar(
          lang: lang,
          statusFilter: _statusFilter,
          onStatusChanged: (v) => setState(() {
            _statusFilter = v;
            _limit = _pageStep;
          }),
        ),
        const SizedBox(height: 16),

        // ── Table ────────────────────────────────────────────────────────────
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _query().snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return _ErrorState(
                    message: snap.error.toString(),
                    onRetry: () => setState(() {}),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data!.docs
                    .where((d) => _matchesSearch(d.data()))
                    .toList();

                if (docs.isEmpty) {
                  return _EmptyState(lang: lang);
                }

                return Column(
                  children: [
                    // Header row
                    _TableHeader(lang: lang),
                    const Divider(height: 1),
                    // Data rows
                    Expanded(
                      child: ListView.separated(
                        controller: _scroll,
                        itemCount: docs.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 16, endIndent: 16),
                        itemBuilder: (context, i) {
                          final doc = docs[i];
                          final d = doc.data();
                          return _ClientRow(
                            uid: doc.id,
                            data: d,
                            formatDate: _formatDate,
                            onToggleBlock: _toggleBlock,
                            lang: lang,
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ── Toolbar ──────────────────────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  final LangController lang;
  final String statusFilter;
  final ValueChanged<String> onStatusChanged;

  const _Toolbar({
    required this.lang,
    required this.statusFilter,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          lang.t('clients'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        _FilterChip(
          label: lang.t('all'),
          selected: statusFilter == 'all',
          onTap: () => onStatusChanged('all'),
        ),
        const SizedBox(width: 6),
        _FilterChip(
          label: lang.t('active'),
          selected: statusFilter == 'active',
          onTap: () => onStatusChanged('active'),
          color: AppColors.success,
        ),
        const SizedBox(width: 6),
        _FilterChip(
          label: lang.t('blocked'),
          selected: statusFilter == 'blocked',
          onTap: () => onStatusChanged('blocked'),
          color: AppColors.danger,
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha:0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? color : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Table Header ─────────────────────────────────────────────────────────────

class _TableHeader extends StatelessWidget {
  final LangController lang;
  const _TableHeader({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.bgApp,
      child: Row(
        children: [
          Expanded(flex: 3, child: _hCell(lang.t('client_name'))),
          Expanded(flex: 2, child: _hCell(lang.t('phone'))),
          Expanded(flex: 3, child: _hCell(lang.t('email'))),
          Expanded(flex: 2, child: _hCell(lang.t('joined'))),
          Expanded(flex: 1, child: _hCell(lang.t('total_trips'))),
          Expanded(flex: 2, child: _hCell(lang.t('status'))),
          const SizedBox(width: 80),
        ],
      ),
    );
  }

  Widget _hCell(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      );
}

// ── Client Row ───────────────────────────────────────────────────────────────

class _ClientRow extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> data;
  final String Function(dynamic) formatDate;
  final Future<void> Function(String, bool) onToggleBlock;
  final LangController lang;

  const _ClientRow({
    required this.uid,
    required this.data,
    required this.formatDate,
    required this.onToggleBlock,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final name =
        (data['displayName'] ?? data['name'] ?? '—').toString();
    final phone =
        (data['phone'] ?? data['phoneNumber'] ?? '—').toString();
    final email = (data['email'] ?? '—').toString();
    final joined = formatDate(data['createdAt']);
    final trips = (data['totalTrips'] ?? data['total_trips'] ?? 0).toString();
    final blocked = data['blocked'] == true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Avatar + name
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primarySoft,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
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
          // Phone (tap to copy)
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: phone));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('📋 $phone'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              child: Text(
                phone,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.blue),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // Email
          Expanded(
            flex: 3,
            child: Text(
              email,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Joined
          Expanded(
            flex: 2,
            child: Text(
              joined,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          // Trips
          Expanded(
            flex: 1,
            child: Text(
              trips,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          // Status chip
          Expanded(
            flex: 2,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: blocked
                    ? AppColors.dangerSoft
                    : AppColors.successSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                blocked ? lang.t('blocked') : lang.t('active'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: blocked ? AppColors.danger : AppColors.success,
                ),
              ),
            ),
          ),
          // Block / Unblock button
          SizedBox(
            width: 80,
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor:
                    blocked ? AppColors.success : AppColors.danger,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                textStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700),
              ),
              onPressed: () => _confirmToggle(context, blocked),
              child: Text(
                  blocked ? lang.t('unblock') : lang.t('block')),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmToggle(BuildContext context, bool blocked) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          blocked ? lang.t('unblock') : lang.t('block'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          blocked
              ? 'هل تريد رفع الحظر عن هذا العميل؟'
              : 'هل تريد حظر هذا العميل؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang.t('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  blocked ? AppColors.success : AppColors.danger,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await onToggleBlock(uid, blocked);
            },
            child: Text(lang.t('confirm')),
          ),
        ],
      ),
    );
  }
}

// ── Empty / Error states ─────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final LangController lang;
  const _EmptyState({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_outline, size: 48, color: AppColors.border),
          const SizedBox(height: 12),
          Text(lang.t('empty'),
              style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
