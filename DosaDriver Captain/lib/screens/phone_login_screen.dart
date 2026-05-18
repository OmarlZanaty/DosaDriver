import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/localization/language_controller.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/localization/app_strings.dart';
import 'captain_home_screen.dart';
import 'captain_profile_completion_screen.dart';
import 'captain_signin_screen.dart';
import 'captain_waiting_approval_screen.dart';
import 'otp_verify_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  bool _isLoading = false;

  // ============================
  // PHONE NORMALIZATION (EGYPT)
  // ============================
  String _formatPhone(String input) {
    String phone = input.trim().replaceAll(' ', '');

    if (phone.startsWith('+')) return phone;
    if (phone.startsWith('0')) {
      return '+20${phone.substring(1)}';
    }
    return '+20$phone';
  }

  // ============================
  // SEND OTP
  // ============================
  /*Future<void> _sendOtp() async {
    if (_phoneController.text.isEmpty || _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.enterNameAndPhone(context)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final phoneE164 = _formatPhone(_phoneController.text);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneE164,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (_) {},
        verificationFailed: (e) {
          throw Exception(e.message);
        },
        codeSent: (verificationId, _) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtpVerifyScreen(
                verificationId: verificationId,
                phone: phoneE164,
                captainName: _nameController.text.trim(),
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }*/
  Future<void> _handlePostLogin(BuildContext context, String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    if (!mounted) return;

    if (!doc.exists) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CaptainSignInScreen()),
      );
      return;
    }

    final data = doc.data()!;
    final bool profileCompleted = data['profileCompleted'] == true;
    final bool approved = data['approved'] == true;

    if (!profileCompleted) {
      // 🚨 MUST upload documents first
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const CaptainProfileCompletionScreen(),
        ),
      );
      return;
    }

    if (!approved) {
      // ⏳ Waiting for admin approval
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const CaptainWaitingApprovalScreen(),
        ),
      );
      return;
    }

    // ✅ ALL CHECKS PASSED
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const CaptainHomeScreen(),
      ),
    );
  }
  Future<void> _sendOtp() async {
    if (_phoneController.text.isEmpty || _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.enterNameAndPhone(context))),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final cred = await FirebaseAuth.instance.signInAnonymously();
      final uid = cred.user!.uid;

      final phone = _formatPhone(_phoneController.text);
      final name = _nameController.text.trim();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({
        'uid': uid,
        'phone': phone,
        'name': name,
        'role': 'captain',
        'authType': 'manual_phone',
        'profileCompleted': false, // ✅ REQUIRED
        'approved': false,         // ✅ REQUIRED
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // ✅ DO NOT REMOVE

      if (!mounted) return;

      await _handlePostLogin(context, uid);

    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
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

      // 🌐 LANGUAGE SWITCH (TOP RIGHT – SAFE)
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              LanguageController.instance.toggleLanguage();
            },
            child: Text(
              isArabic ? 'EN' : 'AR',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment:
          isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [

            const SizedBox(height: 24),

            // LOGO
            Center(
              child: Image.asset('assets/logo.png', width: 120),
            ),

            const SizedBox(height: 24),

            // TITLE
            Center(
              child: Text(
                AppStrings.captainLoginTitle(context),
                style: AppTextStyles.headline1,
              ),
            ),
            const SizedBox(height: 8),

            Center(
              child: Text(
                AppStrings.loginWithPhone(context),
                style: AppTextStyles.bodyMedium,
              ),
            ),

            const SizedBox(height: 48),

            // NAME
            TextField(
              controller: _nameController,
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
              decoration: InputDecoration(
                hintText: AppStrings.fullName(context),
                prefixIcon: const Icon(Icons.person),
              ),
            ),

            const SizedBox(height: 16),

            // PHONE
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
              decoration: InputDecoration(
                hintText: AppStrings.phoneNumber(context),
                prefixIcon: const Icon(Icons.phone),
              ),
            ),

            const SizedBox(height: 24),

            // SEND OTP BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendOtp,
                child: _isLoading
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : Text(AppStrings.sendOtp(context)),
              ),
            ),
          ],
        ),
      ),
    );

  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }
}
