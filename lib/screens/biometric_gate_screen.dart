import 'dart:async';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../core/localization/localization_helper.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

class BiometricGateScreen extends StatefulWidget {
  final Widget child;

  const BiometricGateScreen({super.key, required this.child});

  @override
  State<BiometricGateScreen> createState() => _BiometricGateScreenState();
}

class _BiometricGateScreenState extends State<BiometricGateScreen> {
  final LocalAuthentication _auth = LocalAuthentication();

  bool _loading = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      // ✅ Small delay helps MIUI / slow startup
      await Future.delayed(const Duration(milliseconds: 350));

      final supported = await _auth.isDeviceSupported();
      if (!supported) {
        setState(() {
          _loading = false;
          _message = context.tr('biometric_not_supported');
        });
        return;
      }

      final canCheck = await _auth.canCheckBiometrics;
      final available = await _auth.getAvailableBiometrics();

      if (!canCheck || available.isEmpty) {
        setState(() {
          _loading = false;
          _message = context.tr('biometric_not_enrolled');
        });
        return;
      }

      final ok = await _auth.authenticate(
        localizedReason: context.tr('biometric_reason'),
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true, // ✅ shows system dialogs when possible
        ),
      );

      if (!mounted) return;

      if (ok) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => widget.child),
        );
      } else {
        // User cancelled OR failed
        setState(() {
          _loading = false;
          _message = context.tr('biometric_cancelled');
        });
      }
    } catch (e) {
      // Common cases:
      // - Not enrolled
      // - Not secure lock screen
      // - Locked out due to too many attempts
      setState(() {
        _loading = false;
        _message = '${context.tr('biometric_error')}\n$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.fingerprint, size: 64, color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                  context.tr('biometric_title'),
                  style: AppTextStyles.headline2,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),

                if (_loading)
                  const CircularProgressIndicator()
                else ...[
                  Text(
                    _message ?? '',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.darkGray),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _run,
                      child: Text(context.tr('biometric_try_again')),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
