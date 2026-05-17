import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'captain_waiting_approval_screen.dart';

class CaptainCreateProfileScreen extends StatefulWidget {
  const CaptainCreateProfileScreen({super.key});

  @override
  State<CaptainCreateProfileScreen> createState() =>
      _CaptainCreateProfileScreenState();
}

class _CaptainCreateProfileScreenState extends State<CaptainCreateProfileScreen> {
  final _nameCtrl = TextEditingController();

  Future<void> _submit() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'uid': uid,
      'name': _nameCtrl.text,
      'status': 'pending',
      'isOnline': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CaptainWaitingApprovalScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _submit, child: const Text("Submit")),
          ],
        ),
      ),
    );
  }
}
