import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CaptainApprovalScreen extends StatelessWidget {
  const CaptainApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('طلبات اعتماد السائقين'),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('drivers')
              .where('role', isEqualTo: 'captain')
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: SelectableText(
                  'Firestore Error:\n${snapshot.error}',
                  textDirection: TextDirection.ltr,
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Center(child: Text('لا توجد طلبات حالياً'));
            }

            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, i) {
                final doc = docs[i];
                final data = doc.data();

                final name = (data['name'] ?? 'بدون اسم').toString();
                final phone = (data['phone'] ?? '').toString();

                return Card(
                  margin: const EdgeInsets.all(12),
                  child: ListTile(
                    title: Text(name),
                    subtitle: Text(phone.isEmpty ? '—' : phone),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () async {
                            await FirebaseFirestore.instance
                                .collection('drivers')
                                .doc(doc.id)
                                .update({
                              'status': 'approved',
                              'approvedAt': FieldValue.serverTimestamp(),
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () async {
                            await FirebaseFirestore.instance
                                .collection('drivers')
                                .doc(doc.id)
                                .update({
                              'status': 'rejected', // ✅ not blocked
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
