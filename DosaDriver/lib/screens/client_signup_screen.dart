import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../services/auth_service.dart';
import '../widgets/custom_widgets.dart';

class ClientSignupScreen extends StatefulWidget {
  const ClientSignupScreen({super.key});

  @override
  State<ClientSignupScreen> createState() => _ClientSignupScreenState();
}

class _ClientSignupScreenState extends State<ClientSignupScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _authService = ClientAuthService();

  bool _loading = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose(); _phone.dispose();
    _email.dispose(); _password.dispose(); _confirm.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    final confirm = _confirm.text;

    if (name.isEmpty || phone.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _error = 'من فضلك أدخل جميع البيانات المطلوبة');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'كلمة المرور وتأكيدها غير متطابقتين');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      await _authService.register(
        password: password, name: name, phone: phone,
      );
      // Auth gate handles navigation
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _field(TextEditingController c, String label, IconData icon, {
    bool obscure = false, TextInputType? type,
  }) {
    return TextField(
      controller: c,
      obscureText: obscure ? !_showPassword : false,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.mediumGray),
        suffixIcon: obscure
            ? IconButton(
                icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, color: AppColors.mediumGray),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              )
            : null,
        filled: true, fillColor: AppColors.lightGray,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Text('إنشاء حساب جديد', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 16),
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
                          const Text('بياناتك الشخصية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.darkGray)),
                          const SizedBox(height: 16),

                          if (_error != null)
                            Container(
                              width: double.infinity, padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(10)),
                              child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                            ),

                          _field(_name, 'الاسم الكامل', Icons.person_outline),
                          const SizedBox(height: 12),
                          _field(_phone, 'رقم الهاتف', Icons.phone_outlined, type: TextInputType.phone),
                          const SizedBox(height: 12),
                          _field(_email, 'البريد الإلكتروني', Icons.email_outlined, type: TextInputType.emailAddress),
                          const SizedBox(height: 12),
                          _field(_password, 'كلمة المرور', Icons.lock_outline, obscure: true),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _confirm,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'تأكيد كلمة المرور',
                              prefixIcon: const Icon(Icons.lock_outline, color: AppColors.mediumGray),
                              filled: true, fillColor: AppColors.lightGray,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                            ),
                          ),
                          const SizedBox(height: 24),

                          PrimaryButton(text: 'إنشاء الحساب', onPressed: _signup, loading: _loading),

                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('لديك حساب بالفعل؟', style: TextStyle(color: AppColors.mediumGray)),
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('تسجيل الدخول', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
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
