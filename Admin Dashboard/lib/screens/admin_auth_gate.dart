import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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

        if (snap.hasError) {
          debugPrint('[AuthGate] /admin/me error: ${snap.error}');
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  const Text('غير مصرح بالدخول للوحة التحكم',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (kDebugMode)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text('${snap.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () async {
                      await AdminAuthApi().logout();
                      if (context.mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
                      }
                    },
                    child: const Text('تسجيل الخروج'),
                  ),
                ],
              ),
            ),
          );
        }

        if (SessionStore.current == null) {
          // /admin/me returned but role was empty — treat same as unauthorized
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  const Text('غير مصرح بالدخول للوحة التحكم',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () async {
                      await AdminAuthApi().logout();
                      if (context.mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
                      }
                    },
                    child: const Text('تسجيل الخروج'),
                  ),
                ],
              ),
            ),
          );
        }

        return const AdminDashboard();
      },
    );
  }
}