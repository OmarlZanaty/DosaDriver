import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  bool _running = false;
  final List<String> _logs = [];

  void _log(String msg) => setState(() => _logs.add(msg));

  Future<void> _run() async {
    setState(() {
      _running = true;
      _logs.clear();
    });

    final db = FirebaseFirestore.instance;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    _log('== Diagnostics Start ==');
    _log('User: ${uid ?? "NOT LOGGED IN"}');

    // 1) Check essential config docs
    Future<void> checkDoc(String path) async {
      final snap = await db.doc(path).get();
      _log('[Config] $path => ${snap.exists ? "OK" : "MISSING"}');
    }

    await checkDoc('settings/cancellation');
    await checkDoc('app_config/commission');
    await checkDoc('settings/payouts');
    await checkDoc('app_config/surge');

    // 2) Check user doc
    if (uid != null) {
      final userSnap = await db.collection('users').doc(uid).get();
      _log('[User] users/$uid => ${userSnap.exists ? "OK" : "MISSING"}');
    }

    // 3) Quick rides sanity: last 5 rides
    final ridesSnap = await db.collection('rides').orderBy('createdAt', descending: true).limit(5).get();
    _log('[Rides] last5 => ${ridesSnap.docs.length} docs');
    for (final d in ridesSnap.docs) {
      final data = d.data();
      _log('  - ${d.id} status=${data['status']} clientId=${data['clientId']} driverId=${data['driverId']}');
    }

    _log('== Diagnostics End ==');

    setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostics')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _running ? null : _run,
              child: Text(_running ? 'Running...' : 'Run Diagnostics'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: Text(_logs.join('\n')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
