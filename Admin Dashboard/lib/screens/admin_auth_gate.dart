import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/session_store.dart';
import '../features/auth/admin_auth_api.dart';
import 'admin_dashboard.dart';
import 'admin_login_screen.dart';

class AdminAuthGate extends StatefulWidget {
  const AdminAuthGate({super.key});

  @override
  State<AdminAuthGate> createState() => _AdminAuthGateState();
}

class _AdminAuthGateState extends State<AdminAuthGate> {
  Future<void>? _loadMe;

  @override
  void initState() {
    super.initState();

    // Whenever auth changes, we re-fetch /admin/me to load role/perms
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;

      if (user == null) {
        setState(() {
          SessionStore.current = null;
          _loadMe = null;
        });
      } else {
        setState(() {
          _loadMe = AdminAuthApi().me().then((_) => null);
        });
      }
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _loadMe = AdminAuthApi().me().then((_) => null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const AdminLoginScreen();
    }

    return FutureBuilder<void>(
      future: _loadMe,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (SessionStore.current == null) {
          // logged in firebase but not authorized as dashboard admin
          return const Scaffold(
            body: Center(child: Text('Not authorized for dashboard')),
          );
        }

        return const AdminDashboard();
      },
    );
  }
}