// lib/src/features/authentication/data/auth_repository.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/user_model.dart' as model;

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRepository(this._auth, this._firestore);

  // Stream to listen to auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign Up with Email and Password
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      if (userCredential.user != null) {
        await _createUserDocument(userCredential.user!);
      }
      return userCredential;
    } on FirebaseAuthException catch (e) {
      // Throw cleaner, user-friendly messages
      if (e.code == 'weak-password') {
        throw Exception('The password provided is too weak.');
      } else if (e.code == 'email-already-in-use') {
        throw Exception('An account already exists for that email.');
      } else if (e.code == 'invalid-email') {
        throw Exception('The email address is not valid.');
      }
      throw Exception('An error occurred. Please try again.');
    } catch (e) {
      throw Exception('An unknown error occurred.');
    }
  }

  // Helper method to create user document
  Future<void> _createUserDocument(User user) async {
    final newUser = model.AppUser(uid: user.uid, email: user.email!);
    await _firestore.collection('users').doc(user.uid).set(newUser.toMap());
  }

  // Sign In with Email and Password
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      // Use a generic message for security
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        throw Exception('Invalid email or password.');
      }
      throw Exception('An error occurred. Please try again.');
    } catch (e) {
      throw Exception('An unknown error occurred.');
    }
  }

  // Create Farm (We can place this here or in a separate FarmRepository)
  Future<void> createFarm({
    required String farmName,
    required String ownerId,
  }) async {
    final newFarm = {
      'name': farmName,
      'ownerId': ownerId,
      'createdAt': Timestamp.now(),
    };
    await _firestore.collection('farms').add(newFarm);
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
