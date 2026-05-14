import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/user_model.dart' as model;

class AuthRepository {
  AuthRepository(this._auth, this._firestore);
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password,
      );
      if (cred.user != null) await _ensureUserDoc(cred.user!);
      return cred;
    } on FirebaseAuthException catch (e) {
      throw _authError(e);
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw _authError(e);
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> _ensureUserDoc(User user) async {
    final ref = _firestore.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set(model.AppUser(
        uid: user.uid,
        email: user.email!,
      ).toMap());
    }
  }

  Future<model.AppUser?> getUserDoc(String uid) async {
    final snap = await _firestore.collection('users').doc(uid).get();
    if (!snap.exists) return null;
    return model.AppUser.fromMap(snap.data()!);
  }

  Future<void> setDisplayName({required String userId, required String displayName}) async {
    await _firestore.collection('users').doc(userId).update({'displayName': displayName.trim()});
  }

  Future<void> setLastSelectedFarmId({required String userId, required String farmId}) async {
    await _firestore.collection('users').doc(userId).update({'lastSelectedFarmId': farmId});
  }

  Exception _authError(FirebaseAuthException e) {
    if (e.code == 'weak-password') return Exception('The password provided is too weak.');
    if (e.code == 'email-already-in-use') return Exception('An account already exists for that email.');
    if (e.code == 'invalid-email') return Exception('The email address is not valid.');
    if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
      return Exception('Invalid email or password.');
    }
    return Exception('An error occurred. Please try again.');
  }
}
