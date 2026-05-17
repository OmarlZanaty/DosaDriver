import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/theme/app_colors.dart';
import '../services/auth_service.dart';
import 'captain_signup_screen.dart';

class CaptainSignInScreen extends StatefulWidget {
  const CaptainSignInScreen({super.key});
  @override
  State<CaptainSignInScreen> createState() => _CaptainSignInScreenState();
}

class _CaptainSignInScreenState extends State<CaptainSignInScreen> {
  final _phoneCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _authService  = AuthService();

  bool _loading      = false;
  bool _showPassword = false;
  String? _error;

  // FIX: synchronous flag prevents double-submit
  bool _submitting = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_submitting) return;
    final phone    = _phoneCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (phone.isEmpty || password.isEmpty) {
      setState(() => _error = 'يرجى إدخال رقم الهاتف وكلمة المرور');
      return;
    }

    _submitting = true;
    setState(() { _loading = true; _error = null; });

    try {
      await _authService.login(phone, password);
      // AuthGate handles navigation via authStateChanges stream
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _mapError(e.code));
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      _submitting = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  String _mapError(String code) {
    switch (code) {
      case 'user-not-found':      return 'رقم الهاتف غير مسجل';
      case 'wrong-password':      return 'كلمة المرور غير صحيحة';
      case 'invalid-credential':  return 'رقم الهاتف أو كلمة المرور غير صحيحة';
      case 'too-many-requests':   return 'محاولات كثيرة. يرجى الانتظار قليلاً';
      case 'user-disabled':       return 'تم إيقاف الحساب. تواصل مع الإدارة';
      default: return 'فشل تسجيل الدخول. حاول مرة أخرى';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFD32F2F), Color(0xFF7B1FA2)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    // Logo
                    Container(
                      width: 110, height: 110,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, offset: const Offset(0, 8))],
                      ),
                      child: const Icon(Icons.directions_car, size: 60, color: AppColors.primary),
                    ),
                    const SizedBox(height: 16),
                    const Text('DosaDriver', style: TextStyle(
                      color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 2,
                    )),
                    const Text('بوابة الكابتن', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 32),

                    // Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 24, offset: const Offset(0, 8))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('تسجيل الدخول', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 20),

                          if (_error != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(_error!, style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 13)),
                            ),

                          // Phone field
                          _Field(
                            controller: _phoneCtrl,
                            label: 'رقم الهاتف',
                            icon: Icons.phone_outlined,
                            type: TextInputType.phone,
                          ),
                          const SizedBox(height: 14),

                          // Password field
                          _Field(
                            controller: _passwordCtrl,
                            label: 'كلمة المرور',
                            icon: Icons.lock_outline,
                            obscure: !_showPassword,
                            suffix: IconButton(
                              icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.grey, size: 20),
                              onPressed: () => setState(() => _showPassword = !_showPassword),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Submit
                          SizedBox(
                            width: double.infinity, height: 52,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: _loading
                                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                  : const Text('دخول', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                            ),
                          ),

                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('ليس لديك حساب؟', style: TextStyle(color: Colors.grey)),
                              TextButton(
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CaptainSignupScreen())),
                                child: const Text('سجل الآن', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final TextInputType? type;
  final Widget? suffix;

  const _Field({
    required this.controller, required this.label, required this.icon,
    this.obscure = false, this.type, this.suffix,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    obscureText: obscure,
    keyboardType: type,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey),
      suffixIcon: suffix,
      filled: true, fillColor: const Color(0xFFF5F5F5),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
    ),
  );
}
