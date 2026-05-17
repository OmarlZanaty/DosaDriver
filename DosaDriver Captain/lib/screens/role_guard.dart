import 'package:DosaDriver_captain/screens/phone_login_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'captain_signin_screen.dart';
import 'captain_status_gate.dart';

class RoleGuard extends StatelessWidget {
  const RoleGuard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // ======================
    // NOT LOGGED IN
    // ======================
    if (user == null) {
      return const CaptainSignInScreen();
    }

    // ======================
    // CHECK CAPTAIN RECORD
    // ======================
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // ❌ Logged in but NOT a captain → logout
        if (!snapshot.hasData || !snapshot.data!.exists) {
          //FirebaseAuth.instance.signOut();
          //return const CaptainSignInScreen();
        }

        // ✅ Captain exists → let status gate decide
        return const CaptainStatusGate();
      },
    );
  }
}
