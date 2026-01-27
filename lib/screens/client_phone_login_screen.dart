import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../core/localization/locale_controller.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/localization/localization_helper.dart';
import 'client_otp_verification_screen.dart';

class ClientPhoneLoginScreen extends StatefulWidget {
  const ClientPhoneLoginScreen({super.key});

  @override
  State<ClientPhoneLoginScreen> createState() =>
      _ClientPhoneLoginScreenState();
}

class _ClientPhoneLoginScreenState extends State<ClientPhoneLoginScreen> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isLoading = false;

  String _formatPhone(String input) {
    String phone = input.trim();
    if (phone.startsWith('+')) return phone;
    if (phone.startsWith('0')) return '+20${phone.substring(1)}';
    return '+20$phone';
  }

  Future<void> _sendOTP() async {
    if (_phoneController.text.isEmpty || _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('enter_name_and_phone'))),
      );
      return;
    }

    setState(() => _isLoading = true);

    final phone = _formatPhone(_phoneController.text);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (_) {},
        verificationFailed: (e) {
          throw Exception(e.message);
        },
        codeSent: (verificationId, _) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClientOTPVerificationScreen(
                verificationId: verificationId,
                phoneNumber: phone,
                userName: _nameController.text.trim(),
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
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(

          children: [

            Align(
              alignment: Alignment.topRight,
              child: TextButton.icon(
                onPressed: () {
                  context.read<LocaleController>().toggle();
                },
                icon: const Icon(Icons.language),
                label: Text(
                  Localizations.localeOf(context).languageCode == 'ar'
                      ? 'English'
                      : 'العربية',
                ),
              ),
            ),

            SizedBox(height: MediaQuery.of(context).size.height * 0.15),

            Image.asset('assets/logo.png', width: 120),

            const SizedBox(height: 24),

            Text(
              context.tr('app_name'),
              style: AppTextStyles.headline1,
            ),

            const SizedBox(height: 8),

            Text(
              context.tr('login_with_phone'),
              style: AppTextStyles.bodyMedium,
            ),

            const SizedBox(height: 48),

            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: context.tr('full_name'),
                prefixIcon: const Icon(Icons.person),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: context.tr('phone_number'),
                prefixIcon: const Icon(Icons.phone),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendOTP,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(context.tr('send_otp')),
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
