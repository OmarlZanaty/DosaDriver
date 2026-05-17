import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/backend_api.dart';
import '../services/captain_ride_api.dart';
import '../core/localization/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../widgets/custom_button.dart';
import 'captain_home_screen.dart';

class CaptainEndTripScreen extends StatefulWidget {
  final String rideId;

  const CaptainEndTripScreen({
    super.key,
    required this.rideId,
  });

  @override
  State<CaptainEndTripScreen> createState() => _CaptainEndTripScreenState();
}

class _CaptainEndTripScreenState extends State<CaptainEndTripScreen> {
  double _captainRating = 5.0;
  String _captainComment = '';
  bool _isSubmitting = false;

  Map<String, dynamic>? _ride;

  @override
  void initState() {
    super.initState();
    _loadRide();
  }

  // ================= LOAD RIDE (READ ONLY) =================
  Future<void> _loadRide() async {
    final doc = await FirebaseFirestore.instance
        .collection('rides')
        .doc(widget.rideId)
        .get();

    if (!doc.exists) return;

    setState(() {
      _ride = doc.data();
    });
  }

  // ================= COMPLETE RIDE =================
// ================= COMPLETE RIDE =================
  Future<void> _completeRide() async {
    if (_ride == null) return;

    setState(() => _isSubmitting = true);

    try {
      // ✅ ONLY save rating/comment (no ride status changes here)
      await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .set({
        'captainRating': _captainRating,
        'captainComment': _captainComment,
        'captainRatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.tripCompletedSuccess(context))),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const CaptainHomeScreen()),
            (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed to submit feedback: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }



  @override
  Widget build(BuildContext context) {
    if (_ride == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 🔒 READ ONLY (NO CALC)
    final double distanceKm =
    (_ride!['distanceKm'] ?? 0.0).toDouble();
    final double fare =
    (_ride!['price'] ?? 0.0).toDouble();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppStrings.tripCompletedTitle(context)),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ================= SUMMARY =================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _row(
                    AppStrings.distanceLabel(context),
                    '${distanceKm.toStringAsFixed(2)} km',
                  ),
                  const Divider(),
                  _row(
                    AppStrings.totalFare(context),
                    'EGP ${fare.toStringAsFixed(2)}',
                    highlight: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ================= FEEDBACK =================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    AppStrings.clientFeedback(context),
                    style: AppTextStyles.headline3,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      return IconButton(
                        onPressed: () =>
                            setState(() => _captainRating = i + 1),
                        icon: Icon(
                          i < _captainRating
                              ? Icons.star
                              : Icons.star_border,
                          color: AppColors.primary,
                        ),
                      );
                    }),
                  ),
                  TextField(
                    onChanged: (v) => _captainComment = v,
                    decoration: InputDecoration(
                      hintText: AppStrings.addComment(context),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ================= COMPLETE BUTTON =================
            ActionButton(
              text: _isSubmitting
                  ? AppStrings.completing(context)
                  : AppStrings.completeTrip(context),
              icon: Icons.check_circle,
              backgroundColor: AppColors.primary,
              onPressed: _isSubmitting ? null : _completeRide,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodySmall),
        Text(
          value,
          style: highlight
              ? AppTextStyles.headline3.copyWith(
            color: AppColors.primary,
          )
              : AppTextStyles.bodyLarge,
        ),
      ],
    );
  }
}
