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

    _log('== Captain Diagnostics Start ==');
    _log('User: ${uid ?? "NOT LOGGED IN"}');

    if (uid != null) {
      final userSnap = await db.collection('users').doc(uid).get();
      _log('[User] users/$uid => ${userSnap.exists ? "OK" : "MISSING"}');

      if (userSnap.exists) {
        final data = userSnap.data() as Map<String, dynamic>;
        _log('[User] isOnline=${data['isOnline'] ?? data['online']} lat=${data['lat']} lng=${data['lng']}');
        _log('[User] activeRideId=${data['activeRideId']}');
      }

      final activeRides = await db
          .collection('rides')
          .where('driverId', isEqualTo: uid)
          .where('status', whereIn: ['accepted', 'on_the_way', 'arrived', 'started'])
          .limit(3)
          .get();

      _log('[Rides] active for captain => ${activeRides.docs.length}');
      for (final d in activeRides.docs) {
        final data = d.data();
        _log('  - ${d.id} status=${data['status']} clientId=${data['clientId']}');
      }
    }

    _log('== Captain Diagnostics End ==');

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
