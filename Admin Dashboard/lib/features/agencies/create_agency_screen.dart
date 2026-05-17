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
    setState(() => loading = true);

    final code = generateCode();

    await FirebaseFirestore.instance.collection('agencies').add({
      "name": name.text,
      "phone": phone.text,
      "email": email.text,
      "referralCode": code,
      "commissionPercent": int.parse(commission.text),
      "status": "active",
      "totalDrivers": 0,
      "totalRevenue": 0,
      "createdAt": FieldValue.serverTimestamp(),
    });

    Navigator.pop(context);
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