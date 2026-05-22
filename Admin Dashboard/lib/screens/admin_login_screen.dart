import 'package:flutter/material.dart';

import '../core/session_store.dart';
import '../features/auth/admin_auth_api.dart';

// Import the design system tokens and components created from the Figma export.
import '../ui/tokens/app_colors.dart';
import '../ui/tokens/app_radii.dart';
import '../ui/tokens/app_shadows.dart';
import '../ui/components/app_input.dart';
import '../ui/components/app_button.dart';
import '../ui/components/app_card.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();

  bool _loading = false;
  String? _error;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    final creds = SessionStore.loadAdminCreds();
    if (creds != null) {
      _email.text = creds.email;
      // Password is NEVER stored; user must re-enter each time.
    }
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AdminAuthApi().login(email: _email.text, password: _pass.text);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
    } catch (e) {
      // keep it friendly for admin
      if (mounted) setState(() => _error = 'البريد الإلكتروني أو كلمة المرور غير صحيحة');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use colours from the design system rather than hard‑coded values.
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        // Use the neutral background from the palette.
        backgroundColor: AppColors.bgApp,
        body: LayoutBuilder(
          builder: (context, c) {
            final isDesktop = c.maxWidth >= 980;
            final isTablet = c.maxWidth >= 700 && c.maxWidth < 980;

            if (isDesktop) {
              // Desktop split layout
              return Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: _LeftBrandPanel(),
                  ),
                  Expanded(
                    flex: 5,
                    child: _RightLoginPanel(
                      email: _email,
                      pass: _pass,
                      obscure: _obscure,
                      loading: _loading,
                      error: _error,
                      onToggleObscure: () => setState(() => _obscure = !_obscure),
                      onSubmit: _loading ? null : _submit,
                    ),
                  ),
                ],
              );
            }

            // Tablet/Mobile stacked layout
            return Stack(
              children: [
                // Top gradient background. Use the red gradient values from
                // our palette.
                Container(
                  height: isTablet ? 320 : 280,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        AppColors.loginRedStart,
                        AppColors.loginRedMid,
                        AppColors.loginRedEnd,
                      ],
                    ),
                  ),
                ),

                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        children: [
                          const SizedBox(height: 24),
                          const _BrandLogo(size: 96),
                          const SizedBox(height: 14),
                          const Text(
                            'لوحة تحكم DosaDriver',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'سجّل الدخول لإدارة الرحلات والكباتن',
                            style: TextStyle(
                              color: Color(0xFFFDECEC),
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          const SizedBox(height: 18),

                          _LoginCard(
                            email: _email,
                            pass: _pass,
                            obscure: _obscure,
                            loading: _loading,
                            error: _error,
                            onToggleObscure: () => setState(() => _obscure = !_obscure),
                            onSubmit: _loading ? null : _submit,
                            footerSmall: true,
                          ),

                          const SizedBox(height: 18),
                          const Text(
                            'DosaDriver',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// =======================
/// LEFT BRAND PANEL (Desktop)
/// =======================
class _LeftBrandPanel extends StatelessWidget {
  const _LeftBrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            AppColors.loginRedStart,
            AppColors.loginRedMid,
            AppColors.loginRedEnd,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            Row(
              children: const [
                _BrandLogo(size: 88),
                SizedBox(width: 18),
                Expanded(
                  child: Text(
                    'لوحة تحكم DosaDriver',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'كل شيء لإدارة الرحلات مباشرةً:\nطلبات، قبول، متابعة، إكمال، وإلغاء.',
              style: TextStyle(
                color: Color(0xFFFFEAEA),
                fontSize: 16,
                height: 1.4,
                fontWeight: FontWeight.w700,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 20),

            _bullet('متابعة الرحلات لحظيًا'),
            _bullet('إجراءات سريعة: إكمال / إلغاء'),
            _bullet('بحث وفلاتر متقدمة'),
            _bullet('صلاحيات وإدارة مدراء'),

            const Spacer(),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.16),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.22)),
              ),
              child: const Text(
                '🔒',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: const Icon(Icons.check, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFFFFEAEA),
                fontWeight: FontWeight.w900,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// =======================
/// RIGHT LOGIN PANEL (Desktop)
/// =======================
class _RightLoginPanel extends StatelessWidget {
  final TextEditingController email;
  final TextEditingController pass;
  final bool obscure;
  final bool loading;
  final String? error;
  final VoidCallback onToggleObscure;
  final VoidCallback? onSubmit;

  const _RightLoginPanel({
    required this.email,
    required this.pass,
    required this.obscure,
    required this.loading,
    required this.error,
    required this.onToggleObscure,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'تسجيل الدخول',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Cairo',
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'استخدم بيانات المدير للدخول للوحة التحكم',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 22),

              _LoginCard(
                email: email,
                pass: pass,
                obscure: obscure,
                loading: loading,
                error: error,
                onToggleObscure: onToggleObscure,
                onSubmit: onSubmit,
                footerSmall: false,
              ),

              const SizedBox(height: 18),
              const Text(
                'DosaDriver',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// =======================
/// LOGIN CARD (shared)
/// =======================
class _LoginCard extends StatelessWidget {
  final TextEditingController email;
  final TextEditingController pass;
  final bool obscure;
  final bool loading;
  final String? error;
  final VoidCallback onToggleObscure;
  final VoidCallback? onSubmit;
  final bool footerSmall;

  const _LoginCard({
    required this.email,
    required this.pass,
    required this.obscure,
    required this.loading,
    required this.error,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.footerSmall,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(22),
      radius: 22,
      elevate: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Email input
          AppInput(
            controller: email,
            hint: 'البريد الإلكتروني',
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          // Password input
          AppInput(
            controller: pass,
            hint: 'كلمة المرور',
            icon: Icons.lock_outline,
            obscure: obscure,
            suffix: IconButton(
              onPressed: onToggleObscure,
              icon: Icon(
                obscure ? Icons.visibility_off : Icons.visibility,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (error != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorBg,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: AppColors.errorBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.errorText),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      error!,
                      style: const TextStyle(
                        color: AppColors.errorText,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Login button
          AppButton(
            label: 'تسجيل الدخول',
            onPressed: onSubmit,
            loading: loading,
            variant: AppButtonVariant.primary,
          ),

          const SizedBox(height: 14),

          // Footer text
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                footerSmall ? 'لا يوجد حساب؟ ' : 'ليس لديك حساب؟ ',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Cairo',
                ),
              ),
              Text(
                'تواصل مع الدعم',
                style: const TextStyle(
                  color: AppColors.loginRedMid,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// =======================
/// INPUT LOOK (premium)
/// =======================

/// =======================
/// LOGO
/// =======================
class _BrandLogo extends StatelessWidget {
  final double size;
  const _BrandLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 10)),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/logo.png', // ✅ change to your real logo asset
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return const Center(
              child: Text(
                'D',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Cairo',
                  color: AppColors.textPrimary,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}