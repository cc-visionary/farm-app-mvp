// lib/src/features/authentication/domain/user_model.dart

class AppUser {
  final String uid;
  final String email;
  final String? displayName;

  AppUser({required this.uid, required this.email, this.displayName});

  // Factory constructor to create a User from a Firestore document
  factory AppUser.fromMap(Map<String, dynamic> data) {
    return AppUser(
      uid: data['uid'],
      email: data['email'],
      displayName: data['displayName'],
    );
  }

  // Method to convert a User object to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
    };
  }
}