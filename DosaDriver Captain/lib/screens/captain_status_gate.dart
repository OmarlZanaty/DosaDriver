import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'captain_profile_completion_screen.dart';
import 'captain_signin_screen.dart';
import 'captain_home_screen.dart';
import 'captain_waiting_approval_screen.dart';
// import 'biometric_gate_screen.dart'; // optional later

class CaptainStatusGate extends StatelessWidget {
  const CaptainStatusGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = authSnap.data;
        if (user == null) {
          return const CaptainSignInScreen();
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('drivers')
              .doc(user.uid)
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // If driver doc doesn't exist -> go complete profile
            if (!snap.hasData || !snap.data!.exists) {
              return const CaptainProfileCompletionScreen();
            }

            final data = snap.data!.data() ?? {};

            final bool documentsUploaded =
                (data['documentsUploaded'] == true) ||
                    (data['docsUploaded'] == true);

            final bool approved =
                (data['approved'] == true) || (data['isApproved'] == true);

            Widget child;
            if (!documentsUploaded) {
              child = const CaptainProfileCompletionScreen();
            } else if (!approved) {
              child = const CaptainWaitingApprovalScreen();
            } else {
              child = const CaptainHomeScreen();
            }

            // ✅ return WITHOUT biometric for now
            return child;

            // ✅ later if you want biometric:
            // return BiometricGateScreen(child: child);
          },
        );
      },
    );
  }
}
