import 'package:cloud_firestore/cloud_firestore.dart';

enum PigSex {
  male('male', 'Male'),
  female('female', 'Female');

  const PigSex(this.value, this.label);
  final String value;
  final String label;
  static PigSex fromString(String s) =>
      PigSex.values.firstWhere((e) => e.value == s, orElse: () => PigSex.female);
}

enum PigStage {
  suckling('suckling', 'Suckling'),
  weaner('weaner', 'Weaner'),
  grower('grower', 'Grower'),
  finisher('finisher', 'Finisher'),
  gilt('gilt', 'Gilt'),
  sow('sow', 'Sow'),
  boar('boar', 'Boar');

  const PigStage(this.value, this.label);
  final String value;
  final String label;
  static PigStage fromString(String s) => PigStage.values
      .firstWhere((e) => e.value == s, orElse: () => PigStage.grower);
}

enum PigStatus {
  active('active', 'Active'),
  sold('sold', 'Sold'),
  culled('culled', 'Culled'),
  deceased('deceased', 'Deceased');

  const PigStatus(this.value, this.label);
  final String value;
  final String label;
  static PigStatus fromString(String s) => PigStatus.values
      .firstWhere((e) => e.value == s, orElse: () => PigStatus.active);
}

class Pig {
  final String id;
  final String farmId;
  final String tagId;
  final PigSex sex;
  final String breed;
  final Timestamp birthDate;
  final String? sireId;
  final String? damId;
  final PigStage stage;
  final PigStatus status;
  final String currentAreaId;
  final String? currentPenId;
  final double? currentWeight;
  final Timestamp? weightUpdatedAt;
  final String? photoUrl;
  final String? notes;
  final String createdBy;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  const Pig({
    required this.id,
    required this.farmId,
    required this.tagId,
    required this.sex,
    required this.breed,
    required this.birthDate,
    required this.sireId,
    required this.damId,
    required this.stage,
    required this.status,
    required this.currentAreaId,
    required this.currentPenId,
    required this.currentWeight,
    required this.weightUpdatedAt,
    required this.photoUrl,
    required this.notes,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Pig.fromFirestore(DocumentSnapshot doc, {required String farmId}) {
    final d = doc.data() as Map<String, dynamic>;
    return Pig(
      id: doc.id,
      farmId: farmId,
      tagId: d['tagId'] as String? ?? '(unknown)',
      sex: PigSex.fromString(d['sex'] as String? ?? 'female'),
      breed: d['breed'] as String? ?? '',
      birthDate: d['birthDate'] as Timestamp? ?? Timestamp.now(),
      sireId: d['sireId'] as String?,
      damId: d['damId'] as String?,
      stage: PigStage.fromString(d['stage'] as String? ?? 'grower'),
      status: PigStatus.fromString(d['status'] as String? ?? 'active'),
      currentAreaId: d['currentAreaId'] as String? ?? '',
      currentPenId: d['currentPenId'] as String?,
      currentWeight: (d['currentWeight'] as num?)?.toDouble(),
      weightUpdatedAt: d['weightUpdatedAt'] as Timestamp?,
      photoUrl: d['photoUrl'] as String?,
      notes: d['notes'] as String?,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: d['updatedAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'tagId': tagId,
        'sex': sex.value,
        'breed': breed,
        'birthDate': birthDate,
        if (sireId != null) 'sireId': sireId,
        if (damId != null) 'damId': damId,
        'stage': stage.value,
        'status': status.value,
        'currentAreaId': currentAreaId,
        if (currentPenId != null) 'currentPenId': currentPenId,
        if (currentWeight != null) 'currentWeight': currentWeight,
        if (weightUpdatedAt != null) 'weightUpdatedAt': weightUpdatedAt,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (notes != null) 'notes': notes,
        'createdBy': createdBy,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  String ageString(DateTime now) {
    final diff = now.difference(birthDate.toDate());
    final days = diff.inDays;
    if (days >= 365) return '${days ~/ 365} yr';
    if (days >= 30) return '${days ~/ 30} mo';
    if (days >= 7) return '${days ~/ 7} wk';
    return '$days d';
  }

  bool get isBreeder =>
      stage == PigStage.sow || stage == PigStage.gilt || stage == PigStage.boar;
}
