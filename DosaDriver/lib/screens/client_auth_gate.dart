import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'client_signin_screen.dart';
import 'client_home_screen.dart';

class ClientAuthGate extends StatelessWidget {
  const ClientAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.data == null) return const ClientSignInScreen();
        return const ClientHomeScreen();
      },
    );
  }
}
