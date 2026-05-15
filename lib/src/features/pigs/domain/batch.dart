import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../l10n/generated/app_localizations.dart';

enum BatchType {
  litter('litter', 'Litter'),
  growFinish('grow_finish', 'Grow-Finish'),
  nursery('nursery', 'Nursery');

  const BatchType(this.value, this.label);
  final String value;
  final String label;

  static BatchType fromString(String s) => BatchType.values.firstWhere(
        (b) => b.value == s,
        orElse: () => BatchType.growFinish,
      );
}

enum BatchStatus {
  active('active', 'Active'),
  sold('sold', 'Sold'),
  closed('closed', 'Closed');

  const BatchStatus(this.value, this.label);
  final String value;
  final String label;

  static BatchStatus fromString(String s) => BatchStatus.values.firstWhere(
        (b) => b.value == s,
        orElse: () => BatchStatus.active,
      );
}

class Batch {
  final String id;
  final String farmId;
  final String name;
  final BatchType type;
  final List<String> originPigIds;
  final List<String> pigIds;
  final int count;
  final String currentAreaId;
  final String? currentPenId;
  final BatchStatus status;
  final Timestamp startDate;
  final Timestamp? endDate;
  final String createdBy;
  final Timestamp createdAt;

  const Batch({
    required this.id,
    required this.farmId,
    required this.name,
    required this.type,
    required this.originPigIds,
    required this.pigIds,
    required this.count,
    required this.currentAreaId,
    required this.currentPenId,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.createdBy,
    required this.createdAt,
  });

  factory Batch.fromFirestore(
    DocumentSnapshot doc, {
    required String farmId,
  }) {
    final d = doc.data() as Map<String, dynamic>;
    return Batch(
      id: doc.id,
      farmId: farmId,
      name: d['name'] as String? ?? '',
      type: BatchType.fromString(d['type'] as String? ?? 'grow_finish'),
      originPigIds: List<String>.from(d['originPigIds'] ?? const <String>[]),
      pigIds: List<String>.from(d['pigIds'] ?? const <String>[]),
      count: d['count'] as int? ?? 0,
      currentAreaId: d['currentAreaId'] as String? ?? '',
      currentPenId: d['currentPenId'] as String?,
      status: BatchStatus.fromString(d['status'] as String? ?? 'active'),
      startDate: d['startDate'] as Timestamp? ?? Timestamp.now(),
      endDate: d['endDate'] as Timestamp?,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'type': type.value,
        'originPigIds': originPigIds,
        'pigIds': pigIds,
        'count': count,
        'currentAreaId': currentAreaId,
        if (currentPenId != null) 'currentPenId': currentPenId,
        'status': status.value,
        'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
        'createdBy': createdBy,
        'createdAt': createdAt,
      };
}

/// Localized human label for a [BatchType].
String localizedBatchType(AppLocalizations l, BatchType t) {
  switch (t) {
    case BatchType.litter:
      return l.batch_type_litter;
    case BatchType.growFinish:
      return l.batch_type_grow_finish;
    case BatchType.nursery:
      return l.batch_type_nursery;
  }
}

/// Localized human label for a [BatchStatus].
String localizedBatchStatus(AppLocalizations l, BatchStatus s) {
  switch (s) {
    case BatchStatus.active:
      return l.batch_status_active;
    case BatchStatus.sold:
      return l.batch_status_sold;
    case BatchStatus.closed:
      return l.batch_status_closed;
  }
}
