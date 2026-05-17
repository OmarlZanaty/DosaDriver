/*
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/localization/app_strings.dart';
import '../core/localization/language_controller.dart';
import 'captain_home_screen.dart';
import 'captain_profile_completion_screen.dart';
import 'captain_waiting_approval_screen.dart';

class EmailLoginScreen extends StatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;

  // ============================
  // POST LOGIN ROUTING
  // ============================
  Future<void> _handlePostLogin(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    if (!doc.exists) return;

    final data = doc.data()!;
    final bool profileCompleted = data['profileCompleted'] == true;
    final String status = data['status']?.toString() ?? 'pending_review';

    if (!profileCompleted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const CaptainProfileCompletionScreen(),
        ),
      );
      return;
    }

    if (status == 'pending_review') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const CaptainWaitingApprovalScreen(),
        ),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const CaptainHomeScreen(),
      ),
    );
  }

  // ============================
  // REGISTER OR LOGIN
  // ============================
  Future<void> _loginOrRegister() async {
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _nameController.text.isEmpty ||
        _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          AppStrings.enterNameAndPhone(context),
        )),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential cred;

      try {
        cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } catch (_) {
        cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }

      final uid = cred.user!.uid;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({
        'uid': uid,
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'name': _nameController.text.trim(),
        'role': 'captain',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _handlePostLogin(uid);
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
    final isArabic =
        Localizations.localeOf(context).languageCode == 'ar';

    return Directionality(
      textDirection:
      isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,

        // 🌐 LANGUAGE SWITCH
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
            children: [
              const SizedBox(height: 24),
              Image.asset('assets/logo.png', width: 120),
              const SizedBox(height: 32),

              Text(
                AppStrings.captainLoginTitle(context),
                style: AppTextStyles.headline1,
              ),

              const SizedBox(height: 24),

              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: AppStrings.fullName(context),
                  prefixIcon: const Icon(Icons.person),
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: AppStrings.phoneNumber(context),
                  prefixIcon: const Icon(Icons.phone),
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: AppStrings.email(context),
                  prefixIcon: const Icon(Icons.email),
                ),
              ),


              const SizedBox(height: 16),

              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: AppStrings.password(context),
                  prefixIcon: const Icon(Icons.lock),
                ),
              ),


              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _loginOrRegister,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(AppStrings.verify(context)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
*/
