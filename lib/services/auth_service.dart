import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  String? get currentUserId => _auth.currentUser?.uid;

  Future<UserCredential> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> register(String email, String password) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  Future<void> signOut() => _auth.signOut();

  Future<String?> getIdToken() async {
    final user = _auth.currentUser;
    if (user == null) {
      return null;
    }
    return user.getIdToken();
  }

  Future<bool> hasRole(String role) async {
    final user = _auth.currentUser;
    if (user == null) {
      return false;
    }
    final result = await user.getIdTokenResult(true);
    final claim = result.claims?['role'];
    return claim?.toString().toLowerCase() == role.toLowerCase();
  }

  Future<bool> isAdmin() => hasRole('admin');
}
