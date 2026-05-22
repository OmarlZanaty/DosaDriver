import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../services/backend_api.dart';
import '../services/client_ride_api.dart';
import '../widgets/custom_widgets.dart';
import 'client_home_screen.dart';
import 'client_trip_receipt_screen.dart';

class ClientRateRideScreen extends StatefulWidget {
  final String rideId;
  final Map<String, dynamic> rideData;

  const ClientRateRideScreen({
    super.key,
    required this.rideId,
    required this.rideData,
  });

  @override
  State<ClientRateRideScreen> createState() => _ClientRateRideScreenState();
}

class _ClientRateRideScreenState extends State<ClientRateRideScreen> {
  int _rating = 5;
  final _commentCtrl = TextEditingController();
  bool _loading = false;
  final _rideApi = ClientRideApi(BackendApi());

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    setState(() => _loading = true);
    try {
      await _rideApi.rateRide(
        int.parse(widget.rideId),
        rating: _rating,
        comment: _commentCtrl.text.trim(),
      );

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const ClientHomeScreen()),
        (r) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = (widget.rideData['price'] ??
            widget.rideData['suggestedFare'] ??
            widget.rideData['finalFare'] ??
            0)
        .toStringAsFixed(2);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // ─── Success Icon ───
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 60,
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'اكتملت الرحلة!',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.darkGray,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'شكراً لاستخدامك DosaDriver',
                style: TextStyle(fontSize: 15, color: AppColors.mediumGray),
              ),

              const SizedBox(height: 24),

              // ─── Fare Card ───
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'المبلغ المدفوع',
                      style: TextStyle(color: AppColors.mediumGray, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$price جنيه',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'من: ${(widget.rideData['pickupAddress'] ?? widget.rideData['pickup']?['addr'] ?? '---').toString()}',
                          style: const TextStyle(fontSize: 12, color: AppColors.mediumGray),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ─── Rating ───
              const Text(
                'قيّم تجربتك',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkGray,
                ),
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return GestureDetector(
                    onTap: () => setState(() => _rating = i + 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        i < _rating ? Icons.star : Icons.star_border,
                        size: 44,
                        color: i < _rating ? AppColors.warning : AppColors.divider,
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 8),
              Text(
                _ratingLabel(),
                style: TextStyle(
                  fontSize: 14,
                  color: _rating >= 4 ? AppColors.success : AppColors.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 20),

              // ─── Comment ───
              TextField(
                controller: _commentCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'أضف تعليقاً (اختياري)...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── View Receipt ──
              OutlinedButton.icon(
                icon: const Icon(Icons.receipt_long_outlined,
                    color: AppColors.primary),
                label: const Text(
                  'عرض الإيصال التفصيلي',
                  style: TextStyle(color: AppColors.primary),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClientTripReceiptScreen(
                        rideId: widget.rideId,
                        rideData: widget.rideData,
                        fromHistory: false,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              PrimaryButton(
                text: 'إرسال التقييم',
                onPressed: _submitRating,
                loading: _loading,
                icon: Icons.send,
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const ClientHomeScreen()),
                    (r) => false,
                  );
                },
                child: const Text(
                  'تخطى',
                  style: TextStyle(color: AppColors.mediumGray),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _ratingLabel() {
    switch (_rating) {
      case 1: return 'سيء جداً 😞';
      case 2: return 'سيء 😕';
      case 3: return 'مقبول 😐';
      case 4: return 'جيد 😊';
      case 5: return 'ممتاز! 🌟';
      default: return '';
    }
  }
}
