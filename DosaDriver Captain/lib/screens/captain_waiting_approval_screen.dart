import 'package:flutter/material.dart';

class CaptainWaitingApprovalScreen extends StatelessWidget {
  const CaptainWaitingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: Text(
            'حسابك قيد المراجعة حالياً.\nسيتم إخطارك فور الموافقة عليه.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
