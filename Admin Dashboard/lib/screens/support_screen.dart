import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SupportScreen extends StatefulWidget {
  final String search;
  const SupportScreen({super.key, required this.search});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  String _filter = 'all'; // all | open | in_progress | closed

  String _fmtTime(Timestamp? ts) {
    if (ts == null) return '—';
    final d = ts.toDate();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}  ${two(d.hour)}:${two(d.minute)}';
  }

  bool _matchesSearch(DocumentSnapshot<Map<String, dynamic>> doc) {
    final q = widget.search.trim().toLowerCase();
    if (q.isEmpty) return true;

    final data = doc.data() ?? {};
    final fields = <String>[
      doc.id,
      (data['subject'] ?? '').toString(),
      (data['type'] ?? '').toString(),
      (data['status'] ?? '').toString(),
      (data['priority'] ?? '').toString(),
      (data['rideId'] ?? '').toString(),
      (data['clientId'] ?? '').toString(),
      (data['driverId'] ?? '').toString(),
    ].map((e) => e.toLowerCase()).join(' | ');

    return fields.contains(q);
  }

  Color _priorityBg(String p) {
    switch (p) {
      case 'high':
        return const Color(0xFFFEE2E2); // red-100
      case 'medium':
        return const Color(0xFFFEF3C7); // amber-100
      case 'low':
        return const Color(0xFFDBEAFE); // blue-100
      default:
        return const Color(0xFFF3F4F6); // gray-100
    }
  }

  Color _priorityFg(String p) {
    switch (p) {
      case 'high':
        return const Color(0xFF991B1B); // red-800
      case 'medium':
        return const Color(0xFF92400E); // amber-800
      case 'low':
        return const Color(0xFF1E40AF); // blue-800
      default:
        return const Color(0xFF374151); // gray-700
    }
  }

  Color _statusBg(String s) {
    switch (s) {
      case 'open':
        return const Color(0xFFFEE2E2);
      case 'in_progress':
        return const Color(0xFFDBEAFE);
      case 'closed':
        return const Color(0xFFD1FAE5);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  Color _statusFg(String s) {
    switch (s) {
      case 'open':
        return const Color(0xFF991B1B);
      case 'in_progress':
        return const Color(0xFF1E40AF);
      case 'closed':
        return const Color(0xFF065F46);
      default:
        return const Color(0xFF374151);
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'open':
        return 'مفتوح';
      case 'in_progress':
        return 'قيد المعالجة';
      case 'closed':
        return 'مغلق';
      default:
        return s.isEmpty ? '—' : s;
    }
  }

  String _priorityLabel(String p) {
    switch (p) {
      case 'high':
        return 'عالي';
      case 'medium':
        return 'متوسط';
      case 'low':
        return 'منخفض';
      default:
        return p.isEmpty ? '—' : p;
    }
  }

  Future<void> _setStatus(String ticketId, String newStatus) async {
    await FirebaseFirestore.instance.collection('supportTickets').doc(ticketId).set(
      {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ تم تحديث الحالة إلى: ${_statusLabel(newStatus)}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          // Filters row
          Row(
            children: [
              _filterBtn('الكل', 'all'),
              const SizedBox(width: 8),
              _filterBtn('مفتوح', 'open'),
              const SizedBox(width: 8),
              _filterBtn('قيد المعالجة', 'in_progress'),
              const SizedBox(width: 8),
              _filterBtn('مغلق', 'closed'),
            ],
          ),
          const SizedBox(height: 14),

          // Tickets list
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('supportTickets')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'لا توجد تذاكر دعم حالياً',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  );
                }

                var docs = snap.data!.docs;

                // filter by status
                if (_filter != 'all') {
                  docs = docs.where((d) => (d.data()['status'] ?? '') == _filter).toList();
                }

                // filter by search
                docs = docs.where(_matchesSearch).toList();

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'لا توجد نتائج مطابقة',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();

                    final subject = (data['subject'] ?? 'بدون عنوان').toString();
                    final type = (data['type'] ?? 'عام').toString(); // ride/payment/other...
                    final status = (data['status'] ?? 'open').toString();
                    final priority = (data['priority'] ?? 'medium').toString();

                    final rideId = (data['rideId'] ?? '').toString();
                    final clientId = (data['clientId'] ?? '').toString();
                    final driverId = (data['driverId'] ?? '').toString();

                    final createdAt = data['createdAt'] is Timestamp ? data['createdAt'] as Timestamp : null;
                    final updatedAt = data['updatedAt'] is Timestamp ? data['updatedAt'] as Timestamp : null;

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0C000000),
                            blurRadius: 12,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // top badges
                          Row(
                            children: [
                              _badge(
                                label: 'الأولوية: ${_priorityLabel(priority)}',
                                bg: _priorityBg(priority),
                                fg: _priorityFg(priority),
                              ),
                              const SizedBox(width: 8),
                              _badge(
                                label: 'الحالة: ${_statusLabel(status)}',
                                bg: _statusBg(status),
                                fg: _statusFg(status),
                              ),
                              const Spacer(),
                              Text(
                                _fmtTime(createdAt),
                                style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          Text(
                            subject,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF111827),
                            ),
                          ),

                          const SizedBox(height: 8),

                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _meta('ID', doc.id),
                              _meta('النوع', type),
                              if (rideId.isNotEmpty) _meta('RideId', rideId),
                              if (clientId.isNotEmpty) _meta('ClientId', clientId),
                              if (driverId.isNotEmpty) _meta('DriverId', driverId),
                              if (updatedAt != null) _meta('آخر تحديث', _fmtTime(updatedAt)),
                            ],
                          ),

                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),

                          // actions
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: status == 'in_progress'
                                      ? null
                                      : () => _setStatus(doc.id, 'in_progress'),
                                  icon: const Icon(Icons.play_circle, size: 20),
                                  label: const Text('بدء المعالجة'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF1E40AF),
                                    side: const BorderSide(color: Color(0xFFDBEAFE)),
                                    backgroundColor: const Color(0xFFEEF2FF),
                                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: status == 'closed' ? null : () => _setStatus(doc.id, 'closed'),
                                  icon: const Icon(Icons.check_circle, size: 20),
                                  label: const Text('إغلاق التذكرة'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF16A34A),
                                    foregroundColor: Colors.white,
                                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterBtn(String label, String value) {
    final active = _filter == value;
    return InkWell(
      onTap: () => setState(() => _filter = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFF111827),
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _badge({required String label, required Color bg, required Color fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _meta(String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        '$k: $v',
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: Color(0xFF111827),
          fontSize: 12,
        ),
      ),
    );
  }
}
