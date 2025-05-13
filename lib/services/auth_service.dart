import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // Get the current user
  User? get currentUser => _firebaseAuth.currentUser;

  // Stream for authentication state changes
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Sign in with Email (CPF) and Password
  // Assumption: CPF is used as the email for Firebase Authentication.
  // This requires users to be registered in Firebase Auth with their CPF as the email.
  Future<UserCredential?> signInWithCpfAndPassword(
      String cpf, String password) async {
    try {
      // Trim whitespace
      final String email = cpf.trim();
      final String pass = password.trim();

      // Attempt sign in
      UserCredential userCredential =
          await _firebaseAuth.signInWithEmailAndPassword(
        email: email, // Using CPF as email
        password: pass,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      // Re-throw the exception to be handled by the caller (e.g., LoginPage)
      print("AuthService Error: ${e.code} - ${e.message}");
      throw e;
    } catch (e) {
      print("AuthService Unexpected Error: $e");
      // Throw a generic exception for other errors
      throw Exception('An unexpected error occurred during sign in.');
    }
  }

  // Sign up with Email (CPF) and Password (Example - might not be needed based on user flow)
  // Assumption: CPF is used as the email for Firebase Authentication.
  Future<UserCredential?> signUpWithCpfAndPassword(
      String cpf, String password) async {
    try {
      final String email = cpf.trim();
      final String pass = password.trim();

      UserCredential userCredential =
          await _firebaseAuth.createUserWithEmailAndPassword(
        email: email, // Using CPF as email
        password: pass,
      );
      // You might want to save additional user info (like CPF) to Firestore here
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print("AuthService SignUp Error: ${e.code} - ${e.message}");
      throw e;
    } catch (e) {
      print("AuthService SignUp Unexpected Error: $e");
      throw Exception('An unexpected error occurred during sign up.');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      print("AuthService SignOut Error: $e");
      // Optionally re-throw or handle
    }
  }

  // TODO: Add methods for password reset, first access if needed
  // Future<void> sendPasswordResetEmail(String cpf) async { ... }
}
