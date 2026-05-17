import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'captain_signin_screen.dart';
import 'captain_status_gate.dart';
import 'biometric_gate_screen.dart';

class CaptainAuthGate extends StatelessWidget {
  const CaptainAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = snap.data;

        // ❌ Not logged in -> show sign-in
        if (user == null) {
          return const CaptainSignInScreen();
        }

        // ✅ Logged in -> require biometrics then continue
        return BiometricGateScreen(
          child: const CaptainStatusGate(),
        );
      },
    );
  }
}