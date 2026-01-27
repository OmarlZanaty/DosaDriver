import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  static Future<void> ensureUserDocument() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref =
    FirebaseFirestore.instance.collection('users').doc(user.uid);

    await ref.set({
      'uid': user.uid,
      'email': user.email,
      'role': 'client',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
