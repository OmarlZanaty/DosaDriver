import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  final String search;
  const NotificationsScreen({super.key, required this.search});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Notifications Screen (search: "$search")'),
    );
  }
}
