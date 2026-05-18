import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// FIX: Phone+password auth, no OTP, persistent login via Firebase SDK
class ClientAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── REGISTER ───────────────────────────────────────────────────────────────
  Future<void> register({
    required String phone, required String password,
    required String name,
  }) async {
    final email = _toEmail(phone);
    UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapError(e.code));
    }

    final uid = cred.user!.uid;

    // FIX: If Firestore write fails, roll back Firebase Auth to prevent orphan accounts
    try {
      await _db.collection('users').doc(uid).set({
        'uid':    uid, 'name': name, 'phone': phone, 'email': email,
        'role':   'RIDER',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      await cred.user?.delete();
      rethrow;
    }
  }

  // ─── LOGIN ──────────────────────────────────────────────────────────────────
  Future<void> login(String phone, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: _toEmail(phone), password: password);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userRole', 'RIDER');
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapError(e.code));
    }
  }

  // ─── LOGOUT ─────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userRole');
    await _auth.signOut();
  }

  // ─── UPDATE PROFILE ──────────────────────────────────────────────────────────
  Future<void> updateProfile({required String name, required String phone}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).update({
      'name': name, 'phone': phone, 'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  static String _toEmail(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    return '$cleaned@dosadriver.local';
  }

  static String _mapError(String code) {
    switch (code) {
      case 'email-already-in-use': return 'رقم الهاتف مسجل بالفعل';
      case 'user-not-found':       return 'رقم الهاتف غير مسجل';
      case 'wrong-password':       return 'كلمة المرور غير صحيحة';
      case 'invalid-credential':   return 'رقم الهاتف أو كلمة المرور غير صحيحة';
      case 'too-many-requests':    return 'محاولات كثيرة. حاول لاحقاً';
      case 'weak-password':        return 'كلمة المرور ضعيفة (6 أحرف على الأقل)';
      default: return 'خطأ في المصادقة';
    }
  }
}
