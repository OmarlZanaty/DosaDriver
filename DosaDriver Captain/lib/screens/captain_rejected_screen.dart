import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CaptainRejectedScreen extends StatelessWidget {
  final String reason;
  const CaptainRejectedScreen({super.key, required this.reason});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cancel, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(reason, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .update({'status': 'pending_docs'});
                },
                child: const Text('Re-upload Documents'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
