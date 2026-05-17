import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ApprovalsScreen extends StatefulWidget {
  final String search;
  const ApprovalsScreen({super.key, required this.search});

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  Future<void> _approve(String uid) async {
    await FirebaseFirestore.instance.collection('drivers').doc(uid).update({
      'status': 'approved',
      'approvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ تم اعتماد الكابتن')),
    );
  }

  Future<void> _reject(String uid) async {
    await FirebaseFirestore.instance.collection('drivers').doc(uid).update({
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ تم رفض الكابتن')),
    );
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    final q = widget.search.trim().toLowerCase();
    if (q.isEmpty) return true;

    final name = (data['name'] ?? '').toString().toLowerCase();
    final phone = (data['phone'] ?? '').toString().toLowerCase();
    return name.contains(q) || phone.contains(q);
  }

  String _fmtTime(Timestamp? ts) {
    if (ts == null) return '—';
    final d = ts.toDate();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}  ${two(d.hour)}:${two(d.minute)}';
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ تم النسخ')),
    );
  }

  // Optional documents
  List<_DocItem> _extractDocs(Map<String, dynamic> data) {
    final docs = data['documents'];
    if (docs is! Map) return [];

    String? getUrl(String key) {
      final v = docs[key];
      if (v == null) return null;
      if (v is String && v.trim().isNotEmpty) return v.trim();
      return null;
    }

    final items = <_DocItem>[
      _DocItem('صورة شخصية', getUrl('profileImage')),
      _DocItem('بطاقة (أمام)', getUrl('nationalIdFront')),
      _DocItem('بطاقة (خلف)', getUrl('nationalIdBack')),
      _DocItem('رخصة قيادة', getUrl('drivingLicense')),
      _DocItem('رخصة سيارة', getUrl('vehicleLicense')),
    ];

    return items.where((e) => e.url != null).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('drivers')
            .where('role', isEqualTo: 'captain')
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'لا يوجد طلبات اعتماد حالياً',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            );
          }

          final docs = snap.data!.docs;
          final filtered = docs.where((d) => _matchesSearch(d.data())).toList();

          if (filtered.isEmpty) {
            return const Center(
              child: Text(
                'لا توجد نتائج مطابقة',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(6),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = filtered[index];
              final data = doc.data();

              final name = (data['name'] ?? 'بدون اسم').toString();
              final phone = (data['phone'] ?? '').toString();
              final createdAt = data['createdAt'] is Timestamp ? data['createdAt'] as Timestamp : null;

              final carType = (data['carType'] ?? '').toString();
              final carNumber = (data['carNumber'] ?? '').toString();
              final carColor = (data['carColor'] ?? '').toString();

              final docItems = _extractDocs(data);

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
                    // Header
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFEEF2FF),
                            border: Border.all(color: const Color(0xFFF59E0B), width: 2),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            name.isNotEmpty ? name.characters.first : 'C',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1E40AF),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    phone.isEmpty ? '—' : phone,
                                    style: const TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  InkWell(
                                    onTap: phone.isEmpty ? null : () => _copy(phone),
                                    child: const Icon(Icons.copy, size: 18, color: Color(0xFF6B7280)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'قيد المراجعة',
                            style: TextStyle(
                              color: Color(0xFFF59E0B),
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    // Meta
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _metaChip('تاريخ التسجيل', _fmtTime(createdAt)),
                        _metaChip('UID', doc.id, copyValue: doc.id, onCopy: _copy),
                        if (carType.isNotEmpty) _metaChip('نوع السيارة', carType),
                        if (carColor.isNotEmpty) _metaChip('لون السيارة', carColor),
                        if (carNumber.isNotEmpty) _metaChip('لوحة السيارة', carNumber),
                      ],
                    ),

                    if (docItems.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'الملفات المرفوعة',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: docItems.map((e) {
                          return OutlinedButton.icon(
                            onPressed: () {
                              // We only show / copy URL for now (no webview inside)
                              _copy(e.url!);
                            },
                            icon: const Icon(Icons.link, size: 18),
                            label: Text('نسخ رابط ${e.title}'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF111827),
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                              textStyle: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _approve(doc.id),
                            icon: const Icon(Icons.check_circle, size: 20),
                            label: const Text('اعتماد'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              textStyle: const TextStyle(fontWeight: FontWeight.w900),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _reject(doc.id),
                            icon: const Icon(Icons.block, size: 20),
                            label: const Text('رفض'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              textStyle: const TextStyle(fontWeight: FontWeight.w900),
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
    );
  }

  Widget _metaChip(
      String label,
      String value, {
        String? copyValue,
        Future<void> Function(String text)? onCopy,
      }) {
    final hasCopy = copyValue != null && onCopy != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
          if (hasCopy) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: () => onCopy(copyValue),
              child: const Icon(Icons.copy, size: 16, color: Color(0xFF6B7280)),
            ),
          ],
        ],
      ),
    );
  }
}

class _DocItem {
  final String title;
  final String? url;
  _DocItem(this.title, this.url);
}
