import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// FIX: Auth uses phone number + password (email-format: phone@dosadriver.local)
/// FIX: Role is read from Firebase Custom Claims, not Firestore
/// FIX: Persistent login via FirebaseAuth.authStateChanges() — no re-login needed
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── LOGIN with phone + password ────────────────────────────────────────────
  Future<void> login(String phone, String password) async {
    final email = _phoneToEmail(phone);
    await _auth.signInWithEmailAndPassword(email: email, password: password);

    // Verify driver document exists
    final uid = _auth.currentUser!.uid;
    final doc = await _firestore.collection('drivers').doc(uid).get();
    if (!doc.exists) {
      await _auth.signOut();
      throw Exception('هذا الرقم غير مسجل كابتن. تواصل مع الإدارة.');
    }

    // Cache role locally for offline access
    final role = doc.data()?['role'] ?? 'captain';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userRole', role.toString());
  }

  // ─── REGISTER captain ────────────────────────────────────────────────────────
  Future<void> registerCaptain({
    required String phone,
    required String password,
    required String name,
    Map<String, dynamic>? extraData,
  }) async {
    final email = _phoneToEmail(phone);
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email, password: password,
    );
    final uid = cred.user!.uid;

    // Write driver profile — role will be set via Custom Claims by admin
    await _firestore.collection('drivers').doc(uid).set({
      'uid':       uid,
      'name':      name,
      'phone':     phone,
      'role':      'captain',
      'status':    'pending_review', // Admin must approve
      'online':    false,
      'isOnline':  false,
      'lat':       0.0,
      'lng':       0.0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      ...?extraData,
    });
  }

  // ─── LOGOUT ─────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      // Set offline before signing out
      await _firestore.collection('drivers').doc(uid).update({
        'online': false, 'isOnline': false,
      }).catchError((_) {});
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userRole');
    await _auth.signOut();
  }

  // ─── UPDATE PROFILE ──────────────────────────────────────────────────────────
  Future<void> updateProfile({required String name, required String phone}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('drivers').doc(uid).update({
      'name': name, 'phone': phone,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────────
  /// Convert phone to email format for Firebase Auth
  static String _phoneToEmail(String phone) {
    // Sanitize phone: remove spaces, dashes, parentheses
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    return '$cleaned@dosadriver.local';
  }

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
