import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CreateAgencyScreen extends StatefulWidget {
  const CreateAgencyScreen({super.key});

  @override
  State<CreateAgencyScreen> createState() => _CreateAgencyScreenState();
}

class _CreateAgencyScreenState extends State<CreateAgencyScreen> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final commission = TextEditingController();

  bool loading = false;

  String generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();

    return List.generate(
      6,
          (_) => chars[rand.nextInt(chars.length)],
    ).join();
  }

  Future<void> createAgency() async {
    final pct = int.tryParse(commission.text.trim());
    if (name.text.trim().isEmpty || pct == null || pct < 0 || pct > 100) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال اسم الوكالة ونسبة عمولة صحيحة (0–100)')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final code = generateCode();

      await FirebaseFirestore.instance.collection('agencies').add({
        'name': name.text.trim(),
        'phone': phone.text.trim(),
        'email': email.text.trim(),
        'referralCode': code,
        'commissionPercent': pct,
        'status': 'active',
        'totalDrivers': 0,
        'totalRevenue': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل إنشاء الوكالة: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("إنشاء وكالة")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: name, decoration: InputDecoration(labelText: "اسم الوكالة")),
            TextField(controller: phone, decoration: InputDecoration(labelText: "الهاتف")),
            TextField(controller: email, decoration: InputDecoration(labelText: "البريد")),
            TextField(controller: commission, decoration: InputDecoration(labelText: "نسبة العمولة %")),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: loading ? null : createAgency,
              child: const Text("إنشاء"),
            )
          ],
        ),
      ),
    );
  }
}