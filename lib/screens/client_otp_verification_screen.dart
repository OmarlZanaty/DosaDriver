import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/localization/localization_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ClientOTPVerificationScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  final String userName;

  const ClientOTPVerificationScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
    required this.userName,
  });

  @override
  State<ClientOTPVerificationScreen> createState() =>
      _ClientOTPVerificationScreenState();
}

class _ClientOTPVerificationScreenState
    extends State<ClientOTPVerificationScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  int _secondsRemaining = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }


  Future<void> printIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ No currentUser (not logged in)');
      return;
    }

    final token = await user.getIdToken(true); // force refresh
    print('✅ ID_TOKEN_START');
    print(token);
    print('✅ ID_TOKEN_END');
    print('UID: ${user.uid}');
    print('Phone: ${user.phoneNumber}');
    print('Name: ${user.displayName}');
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
            _startTimer();
          } else {
            _canResend = true;
          }
        });
      }
    });
  }

  Future<void> _verifyOTP() async {
    if (_otpController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('otp_enter_error'))),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint('Verifying OTP...');

      final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: _otpController.text.trim(),
      );

      final userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);

      final user = userCredential.user;
      if (user != null) {
        await user.updateDisplayName(widget.userName);
        await user.reload();

        debugPrint('User authenticated: ${user.uid}');
        debugPrint('Phone (Firebase): ${user.phoneNumber}');
        debugPrint('Name: ${widget.userName}');

        await printIdToken(); // ✅ this prints the ID token
      }

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/client_home');
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Auth error: ${e.code} | ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('otp_invalid_error'))),
        );
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  Future<void> _resendOTP() async {
    // TODO: Implement resend OTP logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Resend OTP functionality coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.darkGray),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.05),

              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.sms,
                  color: AppColors.primary,
                  size: 40,
                ),
              ),

              const SizedBox(height: 24),

              // Title
              Text(
                context.tr('otp_verify_title'),
                style: AppTextStyles.headline2,
              ),


              const SizedBox(height: 8),

              // Subtitle
              Text(
                '${context.tr('otp_verify_subtitle')}\n${widget.phoneNumber}',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.darkGray,
                ),
                textAlign: TextAlign.center,
              ),


              const SizedBox(height: 48),

              // OTP Input
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  hintText: context.tr('otp_hint'),

                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  counterText: '',
                ),
              ),

              const SizedBox(height: 24),

              // Verify Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                    context.tr('otp_verify_button'),
                    style: AppTextStyles.headline3.copyWith(
                      color: Colors.white,
                    ),
                  ),

                ),
              ),

              const SizedBox(height: 24),

              // Resend OTP
              if (_canResend)
                GestureDetector(
                  onTap: _resendOTP,
                  child: Text(
                    context.tr('otp_resend'),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                )
              else
                Text(
                  context
                      .tr('otp_resend_in')
                      .replaceAll('{{seconds}}', '$_secondsRemaining'),

                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.darkGray,
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
    _otpController.dispose();
    super.dispose();
  }
}
