import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/localization/localization_helper.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../services/api_client.dart';
import '../services/auth_api.dart';
import '../services/session_store.dart';
import 'client_home_new.dart';
import 'complete_phone_screen.dart';

class ClientEmailSignupScreen extends StatefulWidget {
  const ClientEmailSignupScreen({super.key});

  @override
  State<ClientEmailSignupScreen> createState() => _ClientEmailSignupScreenState();
}

class _ClientEmailSignupScreenState extends State<ClientEmailSignupScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  final _authApi = AuthApi(ApiClient());
  final _session = SessionStore();

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _anim.forward();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // Egypt normalize:
  // - "+2010..." => keep
  // - "010..." => +2010...
  // - "10..." => +2010...
  String _normalizePhone(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return raw;
    if (raw.startsWith('+')) return raw;
    if (raw.startsWith('0')) return '+20${raw.substring(1)}';
    return '+20$raw';
  }

  bool _looksValid(String phone) {
    // Basic validation only; backend should enforce uniqueness/format.
    return phone.startsWith('+') && phone.length >= 11;
  }

  Future<void> _signup() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _normalizePhone(_phoneController.text);
    final pass = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (name.isEmpty || email.isEmpty || phone.isEmpty || pass.isEmpty || confirm.isEmpty) {
      _snack(context.tr('please_fill_all_fields'));
      return;
    }

    if (!_looksValid(phone)) {
      _snack(context.tr('invalid_phone'));
      return;
    }

    if (pass != confirm) {
      _snack(context.tr('passwords_do_not_match'));
      return;
    }

    if (pass.length < 6) {
      _snack(context.tr('password_min_6'));
      return;
    }

    setState(() => _loading = true);

    try {
      // 1) Create Firebase account
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: pass,
      );

      final user = cred.user;
      if (user != null) {
        await user.updateDisplayName(name);
        await user.reload();
      }

      if (!mounted) return;

      // 2) Save to Firestore users (optional mirror / legacy)
      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
        'uid': cred.user!.uid,
        'name': name,
        'email': email,
        'phone': phone,
        'walletBalance': 0.0,
        'emergencyContacts': [],
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3) ✅ IMPORTANT: Save to backend so AuthGate doesn't ask again
      try {
        // Ensure backend user exists (upsert)
        final dbUser = await _authApi.me();
        await _session.saveDbUser(dbUser);

        // Update phone on backend
        await _authApi.updateMyPhone(phone);

        // Refresh dbUser (so session has phone)
        final dbUser2 = await _authApi.me();
        await _session.saveDbUser(dbUser2);
      } catch (e) {
        // If backend endpoint missing or network issue:
        // fallback -> app may still ask in AuthGate, so we route to CompletePhoneScreen
        if (!mounted) return;
        _snack('${context.tr('signup_failed')}: $e');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const CompletePhoneScreen()),
        );
        return;
      }

      _snack(context.tr('account_created_success'));

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ClientHomeNew()),
      );
    } on FirebaseAuthException catch (e) {
      _snack('${context.tr('error')}: ${e.message ?? e.code}');
    } catch (e) {
      _snack('${context.tr('signup_failed')}: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _decoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: BackButton(color: AppColors.darkGray),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),

                  // Logo
                  Center(
                    child: Container(
                      width: 90,
                      height: 90,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                    ),
                  ),

                  const SizedBox(height: 18),

                  Text(
                    context.tr('create_account'),
                    style: AppTextStyles.headline2,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr('join_dosadriver'),
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.darkGray),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 28),

                  TextField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: _decoration(hint: context.tr('full_name'), icon: Icons.person),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: _decoration(hint: context.tr('email'), icon: Icons.email),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: _decoration(hint: context.tr('phone_number'), icon: Icons.phone),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePass,
                    textInputAction: TextInputAction.next,
                    decoration: _decoration(
                      hint: context.tr('password'),
                      icon: Icons.lock,
                      suffix: IconButton(
                        icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscurePass = !_obscurePass),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirm,
                    textInputAction: TextInputAction.done,
                    decoration: _decoration(
                      hint: context.tr('confirm_password'),
                      icon: Icons.lock,
                      suffix: IconButton(
                        icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  ElevatedButton(
                    onPressed: _loading ? null : _signup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _loading
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : Text(
                      context.tr('create_account'),
                      style: AppTextStyles.headline3.copyWith(color: Colors.white),
                    ),
                  ),

                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      context.tr('password_hint_min_6'),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.darkGray),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
