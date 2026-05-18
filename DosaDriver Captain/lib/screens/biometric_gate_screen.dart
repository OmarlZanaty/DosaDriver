import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

class BiometricGateScreen extends StatefulWidget {
  final Widget child;
  const BiometricGateScreen({super.key, required this.child});

  @override
  State<BiometricGateScreen> createState() => _BiometricGateScreenState();
}

class _BiometricGateScreenState extends State<BiometricGateScreen>
    with WidgetsBindingObserver {
  final LocalAuthentication _auth = LocalAuthentication();

  bool _passed = false;
  bool _checking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _runAuth());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // re-lock when returning from background
    if (state == AppLifecycleState.resumed && !_passed) {
      _runAuth();
    }
  }

  Future<void> _runAuth() async {
    if (_checking) return;
    _checking = true;

    try {
      final canCheck = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();

      if (!canCheck || !supported) {
        if (!mounted) return;
        setState(() {
          _passed = false;
          _error = 'استخدم قفل الشاشة أو كلمة مرور الجهاز للمتابعة';
        });
        return;
      }

      final ok = await _auth.authenticate(
        localizedReason: 'Please verify your identity',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (!mounted) return;
      setState(() {
        _passed = ok;
        _error = ok ? null : 'Authentication failed';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      _checking = false;
    }
  }

  Future<void> _unlockWithDeviceCredential() async {
    await _runAuth();
  }

  @override
  Widget build(BuildContext context) {
    if (_passed) return widget.child;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.fingerprint, size: 72),
                const SizedBox(height: 16),
                const Text(
                  'Confirm Identity',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _checking ? null : _runAuth,
                  child: Text(_checking ? 'Checking...' : 'Try Again'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _checking ? null : _unlockWithDeviceCredential,
                  child: const Text('Unlock with device PIN / password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}