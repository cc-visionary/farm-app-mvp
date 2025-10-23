// lib/src/features/authentication/application/auth_providers.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../domain/user_model.dart';

// Provides the instance of FirebaseAuth
final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

// Provides the instance of FirebaseFirestore
final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

// Provides the instance of our AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.read(firebaseAuthProvider),
    ref.read(firestoreProvider),
  );
});

// StreamProvider that listens to the authentication state
// This is the most important provider for managing user login state.
// It automatically updates whenever a user signs in or out.
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// Watches the Firestore document for the current user.
/// Returns an [AppUser] object.
final userDataProvider = StreamProvider<AppUser?>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final firestore = ref.watch(firestoreProvider);

  // If there's no logged-in user, return a stream of null
  if (authState.asData?.value?.uid == null) {
    return Stream.value(null);
  }

  // If there is a user, listen to their document in the 'users' collection
  final userDocStream = firestore
      .collection('users')
      .doc(authState.asData!.value!.uid)
      .snapshots();

  // Map the document snapshot to an AppUser object
  return userDocStream.map((snapshot) {
    if (snapshot.exists) {
      return AppUser.fromMap(snapshot.data()!);
    }
    return null;
  });
});

/// Provides just the [farmId] of the current user.
/// This is useful for other providers that only need the ID.
final currentFarmIdProvider = Provider<String?>((ref) {
  // Watch the userDataProvider
  final userData = ref.watch(userDataProvider);
  // Return the farmId from the user data, or null if not available
  return userData.asData?.value?.farmId;
});