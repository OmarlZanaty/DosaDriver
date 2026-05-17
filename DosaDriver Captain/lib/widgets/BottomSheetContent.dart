import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class BottomSheetContent extends StatelessWidget {
  final bool isOnline;
  final List<Map<String, dynamic>> rides;

  final VoidCallback onOpenEarnings;
  final void Function(String id) onAcceptRide;
  final void Function(String id) onRefuseRide;

  // ✅ NEW (Step 5)
  final double Function(String id)? progressOf;
  final int Function(String id)? secondsLeftOf;

  const BottomSheetContent({
    super.key,
    required this.isOnline,
    required this.rides,
    required this.onOpenEarnings,
    required this.onAcceptRide,
    required this.onRefuseRide,
    this.progressOf,
    this.secondsLeftOf,
  });

  String _addrOf(Map<String, dynamic> r, String key) {
    final direct = r['${key}Addr'];
    if (direct is String && direct.isNotEmpty) return direct;

    final obj = r[key];
    if (obj is Map) {
      final a = obj['addr'];
      if (a is String && a.isNotEmpty) return a;
    }
    return '---';
  }

  @override
  Widget build(BuildContext context) {
    // ✅ IMPORTANT: do NOT use ListView/Expanded here (we already scroll outside)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // مثال: زر الأرباح/الصفحة
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: OutlinedButton(
            onPressed: onOpenEarnings,
            child: const Text('الأرباح'),
          ),
        ),

        // Rides list (no internal scrolling)
        ...rides.map((r) {
          final idStr = (r['id'] ?? '').toString();
          final pickup = _addrOf(r, 'pickup');
          final drop = _addrOf(r, 'drop');
          final price = (r['price'] ?? r['suggestedFare'] ?? 0).toString();

          // ✅ progress/time from CaptainHomeScreen
          final p = progressOf?.call(idStr) ?? 1.0;
          final s = secondsLeftOf?.call(idStr) ?? 20;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // title + seconds
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'رحلة #$idStr',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$s ث',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // ✅ progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: p,
                    minHeight: 6,
                    backgroundColor: Colors.black.withOpacity(0.06),
                  ),
                ),

                const SizedBox(height: 10),
                Text('من: $pickup', maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('إلى: $drop', maxLines: 1, overflow: TextOverflow.ellipsis),

                const SizedBox(height: 10),
                Row(
                  children: [
                    Text('السعر: $price', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => onRefuseRide(idStr),
                      child: const Text('رفض'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => onAcceptRide(idStr),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('قبول'),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
