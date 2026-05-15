import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../l10n/generated/app_localizations.dart';

enum AreaPurpose {
  breeding('breeding', 'Breeding'),
  gestation('gestation', 'Gestation'),
  farrowing('farrowing', 'Farrowing'),
  nursery('nursery', 'Nursery'),
  growFinish('grow_finish', 'Grow-Finish'),
  quarantine('quarantine', 'Quarantine'),
  boarPen('boar_pen', 'Boar Pen'),
  isolation('isolation', 'Isolation'),
  other('other', 'Other');

  const AreaPurpose(this.value, this.label);
  final String value;
  final String label;

  static AreaPurpose fromString(String s) =>
      AreaPurpose.values.firstWhere(
        (p) => p.value == s,
        orElse: () => AreaPurpose.other,
      );

  /// Ordering used by Farm Layout and grouped lists.
  int get sortOrder => AreaPurpose.values.indexOf(this);
}

class Area {
  final String id;
  final String farmId;
  final String name;
  final AreaPurpose purpose;
  final String? notes;
  final Timestamp createdAt;

  const Area({
    required this.id,
    required this.farmId,
    required this.name,
    required this.purpose,
    required this.notes,
    required this.createdAt,
  });

  factory Area.fromFirestore(DocumentSnapshot doc, {required String farmId}) {
    final d = doc.data() as Map<String, dynamic>;
    return Area(
      id: doc.id,
      farmId: farmId,
      name: d['name'] as String? ?? '(unnamed)',
      purpose: AreaPurpose.fromString(d['purpose'] as String? ?? 'other'),
      notes: d['notes'] as String?,
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'purpose': purpose.value,
    if (notes != null) 'notes': notes,
    'createdAt': createdAt,
  };
}

String localizedAreaPurpose(AppLocalizations l, AreaPurpose p) {
  switch (p) {
    case AreaPurpose.breeding:
      return l.area_purpose_breeding;
    case AreaPurpose.gestation:
      return l.area_purpose_gestation;
    case AreaPurpose.farrowing:
      return l.area_purpose_farrowing;
    case AreaPurpose.nursery:
      return l.area_purpose_nursery;
    case AreaPurpose.growFinish:
      return l.area_purpose_grow_finish;
    case AreaPurpose.quarantine:
      return l.area_purpose_quarantine;
    case AreaPurpose.boarPen:
      return l.area_purpose_boar_pen;
    case AreaPurpose.isolation:
      return l.area_purpose_isolation;
    case AreaPurpose.other:
      return l.area_purpose_other;
  }
}
