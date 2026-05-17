import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../screens/captain_home_screen.dart';
import '../screens/map_screen.dart';
import '../screens/captain_signin_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Not logged in -> proper phone+password auth
        if (!snapshot.hasData) {
          return const CaptainSignInScreen();
        }

        final user = snapshot.data!;

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(),
          builder: (context, driverSnapshot) {
            if (driverSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // IF captain
            if (driverSnapshot.hasData && driverSnapshot.data!.exists) {
              return const CaptainHomeScreen();
            }

            // ELSE client
            return const MapScreen();
          },
        );
      },
    );
  }
}
