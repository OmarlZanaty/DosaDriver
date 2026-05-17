import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/localization/app_strings.dart';
import 'captain_status_gate.dart';

class OtpVerifyScreen extends StatefulWidget {
  final String verificationId;
  final String phone;
  final String captainName;

  const OtpVerifyScreen({
    super.key,
    required this.verificationId,
    required this.phone,
    required this.captainName,
  });

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;

  // ============================
  // VERIFY OTP
  // ============================
  Future<void> _verifyOtp() async {
    if (_otpController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.invalidOtp(context)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: _otpController.text.trim(),
      );

      final userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);

      final uid = userCredential.user!.uid;

      final driverRef =
      FirebaseFirestore.instance.collection('users').doc(uid);

      final doc = await driverRef.get();

      if (!doc.exists) {
        await driverRef.set({
          'name': widget.captainName,
          'phone': widget.phone,
          'status': 'pending',
          'online': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const CaptainStatusGate()),
            (_) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================
  // UI
  // ============================
  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment:
          isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            const Spacer(),

            Center(
              child: Text(
                AppStrings.verifyOtp(context),
                style: AppTextStyles.headline1,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                AppStrings.otpSentTo(context, widget.phone),
                style: AppTextStyles.bodyMedium,
              ),
            ),

            const SizedBox(height: 32),

            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: AppStrings.enterOtp(context),
                counterText: '',
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtp,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(AppStrings.verify(context)),
              ),
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }
}
