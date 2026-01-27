import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign In / Sign Up logic simplified for demo
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        // If user doesn't exist, try to create one (Demo convenience)
        // BUT we must re-throw if the sign-up also fails
        try {
           // FORCE ROLE TO CLIENT
           return await signUp(email, password, "User", "client");
        } catch (signUpError) {
           throw signUpError; // Re-throw the sign-up error
        }
      } else {
        throw e.message ?? "Login failed";
      }
    } catch (e) {
      // Catch generic platform errors (like the pigeon error) and try to extract meaningful text
      String errorStr = e.toString();
      if (errorStr.contains("INVALID_LOGIN_CREDENTIALS")) {
        throw "Invalid email or password.";
      }
      throw errorStr;
    }
  }

  Future<User?> signUp(String email, String password, String name, String role) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      User? user = result.user;
      if (user != null) {
        // Create User Document
        UserModel newUser = UserModel(
          uid: user.uid,
          name: name,
          role: role,
          online: false,
          createdAt: DateTime.now(),
        );
        
        await _firestore.collection('users').doc(user.uid).set(newUser.toMap());
      }
      return user;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? "Registration failed";
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Fetch user role
  Future<String?> getUserRole(String uid) async {
    DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      return doc.get('role') as String?;
    }
    return null;
  }
}
