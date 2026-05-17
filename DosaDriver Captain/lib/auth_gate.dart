import 'package:DosaDriver_captain/screens/phone_login_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'screens/captain_home_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {

        // 🔥 IMPORTANT: wait until Firebase finishes restoring session
        final user = FirebaseAuth.instance.currentUser;

        debugPrint('🔥 AUTH SNAPSHOT = ${snapshot.data}');
        debugPrint('🔥 AUTH CURRENT  = $user');

        // ⏳ Still initializing auth
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // ⛔ Only show login if BOTH are null
        if (snapshot.data == null && user == null) {
          return const PhoneLoginScreen();
        }

        // ✅ Logged in
        return const CaptainHomeScreen();
      },
    );
  }
}
