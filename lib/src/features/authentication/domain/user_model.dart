class AppUser {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String? lastSelectedFarmId;

  const AppUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.lastSelectedFarmId,
  });

  factory AppUser.fromMap(Map<String, dynamic> data) => AppUser(
    uid: data['uid'] as String,
    email: data['email'] as String,
    displayName: data['displayName'] as String?,
    photoUrl: data['photoUrl'] as String?,
    lastSelectedFarmId: data['lastSelectedFarmId'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'displayName': displayName,
    'photoUrl': photoUrl,
    'lastSelectedFarmId': lastSelectedFarmId,
  };

  AppUser copyWith({
    String? displayName,
    String? photoUrl,
    String? lastSelectedFarmId,
  }) => AppUser(
    uid: uid,
    email: email,
    displayName: displayName ?? this.displayName,
    photoUrl: photoUrl ?? this.photoUrl,
    lastSelectedFarmId: lastSelectedFarmId ?? this.lastSelectedFarmId,
  );
}
