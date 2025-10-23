// lib/src/features/authentication/domain/user_model.dart

class AppUser {
  final String uid;
  final String email;
  final String? displayName;
  final String? farmId;

  AppUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.farmId,
  });

  // Method to check if the user has finished the setup process
  bool get hasCompletedSetup => farmId != null && farmId!.isNotEmpty;

  // Factory constructor to create a User from a Firestore document
  factory AppUser.fromMap(Map<String, dynamic> data) {
    return AppUser(
      uid: data['uid'],
      email: data['email'],
      displayName: data['displayName'],
      farmId: data['farmId'],
    );
  }

  // Method to convert a User object to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'farmId': farmId,
    };
  }
}
