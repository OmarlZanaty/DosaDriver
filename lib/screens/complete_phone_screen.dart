import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/localization/localization_helper.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../services/api_client.dart';
import '../services/auth_api.dart';
import '../services/session_store.dart';
import 'client_home_new.dart';

class CompletePhoneScreen extends StatefulWidget {
  const CompletePhoneScreen({super.key});

  @override
  State<CompletePhoneScreen> createState() => _CompletePhoneScreenState();
}

class _CompletePhoneScreenState extends State<CompletePhoneScreen> {
  final _phoneController = TextEditingController();
  bool _loading = false;

  final _session = SessionStore();
  final _authApi = AuthApi(ApiClient());

  String _normalizePhone(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return raw;
    if (raw.startsWith('+')) return raw;
    if (raw.startsWith('0')) return '+20${raw.substring(1)}';
    return '+20$raw';
  }

  bool _looksValid(String phone) {
    return phone.startsWith('+') && phone.length >= 11;
  }

  Future<void> _saveAndContinue() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final phone = _normalizePhone(_phoneController.text);

    if (!_looksValid(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('phone_required'))),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // 1) Save to backend (authoritative)
      await _authApi.updateMyPhone(phone);

      // 2) Refresh dbUser and store in session (so AuthGate sees phone next time)
      final dbUser = await _authApi.me();
      await _session.saveDbUser(dbUser);

      // 3) Optional: mirror in Firestore users/{uid}
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'phone': phone,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ClientHomeNew()),
      );
    } catch (e) {
      // If backend endpoint missing, don't loop forever:
      // store fallback locally AND in Firestore, then allow continue.
      await _session.saveFallbackPhone(phone);

      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'phone': phone,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backend phone update failed: $e')),
      );

      // Allow continue (but AuthGate might still send again until backend endpoint exists)
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ClientHomeNew()),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(context.tr('complete_phone_title')),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('complete_phone_desc'),
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: context.tr('phone_number'),
                hintText: '+2010xxxxxxxx',
                prefixIcon: const Icon(Icons.phone),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _saveAndContinue,
                child: _loading
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : Text(context.tr('save_continue')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }
}
