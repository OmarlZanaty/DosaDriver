import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/localization/localization_helper.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../services/api_client.dart';
import '../services/auth_api.dart';
import '../services/session_store.dart';
import '../services/notification_service.dart'; // ✅ ADD THIS
import 'client_email_signup_screen.dart';
import 'client_home_new.dart';
import 'complete_phone_screen.dart';

class ClientLoginScreen extends StatefulWidget {
  const ClientLoginScreen({super.key});

  @override
  State<ClientLoginScreen> createState() => _ClientLoginScreenState();
}

class _ClientLoginScreenState extends State<ClientLoginScreen> {
  final _emailController = TextEditingController();
  final _passController = TextEditingController();

  bool _loading = false;
  bool _obscure = true;

  final _auth = FirebaseAuth.instance;
  final _authApi = AuthApi(ApiClient());
  final _session = SessionStore();

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final pass = _passController.text;

    if (email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('enter_email_password'))),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await _auth.signInWithEmailAndPassword(email: email, password: pass);

      // call backend /auth/me (guard upserts user + returns dbUser)
      final dbUser = await _authApi.me();
      await _session.saveDbUser(dbUser);

      // If backend user has no phone => enforce phone entry
      final phone = (dbUser.phone ?? '').trim();
      if (phone.isEmpty) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const CompletePhoneScreen()),
        );
        return;
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ClientHomeNew()),
      );
    } on FirebaseAuthException catch (e) {
      final msg = e.message ?? e.code;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ✅ TEST NOTIFICATION BUTTON ACTION
  Future<void> _testNotification() async {
    try {
      await NotificationService().init();
      await NotificationService().show(
        'Test Notification ✅',
        'If you see this, local notifications are working.',
        {'rideId': 'TEST_123'},
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test notification triggered')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notification test failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),

              Text(
                context.tr('login'),
                style: AppTextStyles.headline1,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: context.tr('email'),
                  prefixIcon: const Icon(Icons.email),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: _passController,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: context.tr('password'),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : Text(context.tr('login')),
              ),

              const SizedBox(height: 12),

              // ✅ TEST NOTIFICATION BUTTON
              OutlinedButton.icon(
                onPressed: _loading ? null : _testNotification,
                icon: const Icon(Icons.notifications_active),
                label: const Text('Test Notification'),
              ),

              const SizedBox(height: 16),

              TextButton(
                onPressed: _loading
                    ? null
                    : () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ClientEmailSignupScreen(),
                    ),
                  );
                },
                child: Text(context.tr('create_account')),
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
    _passController.dispose();
    super.dispose();
  }
}