import 'package:firebase_auth/firebase_auth.dart';
import 'services/user_service.dart';

class Auth {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  User? get currentUser => _firebaseAuth.currentUser;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Future<void> singInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    
    // Check if user document exists, if not create it
    if (userCredential.user != null) {
      final existingUser = await UserService.getUser(userCredential.user!.uid);
      if (existingUser == null) {
        // User doesn't have a Firestore document yet, create it
        await UserService.createUser(
          uid: userCredential.user!.uid,
          email: email,
        );
      }
    }
  }

  Future<void> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    
    // Create user document in Firestore
    if (userCredential.user != null) {
      await UserService.createUser(
        uid: userCredential.user!.uid,
        email: email,
      );
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  Future<void> sendPasswordReset({required String email}) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }

}
