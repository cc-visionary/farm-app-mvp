import 'package:cloud_firestore/cloud_firestore.dart';

import '../../activity/data/activity_repository.dart';
import '../domain/payment_method.dart';
import '../domain/payment_status.dart';
import '../domain/sale.dart';
import '../domain/sale_line_item.dart';

/// Input shape for log-sale: not persisted with this exact name,
/// just a value type for the repository method signature.
class SaleLineItemInput {
  SaleLineItemInput({
    required this.pigId,
    required this.pigTagId,
    required this.finalWeightKg,
    required this.pricePerKgPhp,
  });
  final String pigId;
  final String pigTagId;
  final double finalWeightKg;
  final double pricePerKgPhp;
  double get lineRevenuePhp => finalWeightKg * pricePerKgPhp;
}

class SaleRepository {
  SaleRepository(this._firestore, this._activity);
  final FirebaseFirestore _firestore;
  // Activity entry is written inline within the transaction; the repository
  // accepts an [ActivityRepository] for consistency with peer repositories
  // and future expansion, even though no method is invoked on it here.
  // ignore: unused_field
  final ActivityRepository _activity;

  CollectionReference<Map<String, dynamic>> _col(String farmId) =>
      _firestore.collection('farms').doc(farmId).collection('sales');

  /// Atomic: validates every pig is `active`, then writes sale header,
  /// line items, flips pigs to `sold`, and writes a single activity entry.
  ///
  /// Note: withdrawal_end task skipping is intentionally deferred — Firestore
  /// transactions don't support `.where()` reads, so we can't query for open
  /// tasks inside the transaction. Leave tasks open as a conservative MVP
  /// choice; future enhancement: trigger via Cloud Function.
  ///
  /// Throws [ArgumentError] when [lineItems] is empty.
  /// Throws [StateError] when any referenced pig is missing or has a status
  /// other than 'active'.
  Future<String> logSale({
    required String farmId,
    required String buyerName,
    required String? buyerContact,
    required Timestamp saleDate,
    required PaymentMethod paymentMethod,
    required PaymentStatus paymentStatus,
    required double? amountPaidPhp,
    required List<SaleLineItemInput> lineItems,
    required String? notes,
    required String actorUserId,
    required String actorDisplayName,
  }) async {
    if (lineItems.isEmpty) {
      throw ArgumentError('At least one line item is required.');
    }
    final saleRef = _col(farmId).doc();
    final totalHeads = lineItems.length;
    final totalWeight =
        lineItems.fold<double>(0, (s, i) => s + i.finalWeightKg);
    final totalRevenue =
        lineItems.fold<double>(0, (s, i) => s + i.lineRevenuePhp);

    await _firestore.runTransaction((tx) async {
      // Phase 1 — reads: confirm every pig is `active`.
      final pigRefs = <String, DocumentReference<Map<String, dynamic>>>{};
      for (final item in lineItems) {
        final ref = _firestore
            .collection('farms')
            .doc(farmId)
            .collection('pigs')
            .doc(item.pigId);
        final snap = await tx.get(ref);
        if (!snap.exists) {
          throw StateError('Pig ${item.pigTagId} not found.');
        }
        final status = snap.data()!['status'];
        if (status != 'active') {
          throw StateError(
              'Pig ${item.pigTagId} is not active (status=$status).');
        }
        pigRefs[item.pigId] = ref;
      }

      // Phase 2 — writes: header, line items, pig status flips, activity.
      tx.set(saleRef, {
        'buyerName': buyerName.trim(),
        if (buyerContact != null && buyerContact.trim().isNotEmpty)
          'buyerContact': buyerContact.trim(),
        'saleDate': saleDate,
        'totalHeads': totalHeads,
        'totalWeightKg': totalWeight,
        'totalRevenuePhp': totalRevenue,
        'paymentMethod': paymentMethod.value,
        'paymentStatus': paymentStatus.value,
        if (amountPaidPhp != null) 'amountPaidPhp': amountPaidPhp,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        'createdBy': actorUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      for (final item in lineItems) {
        final lineRef = saleRef.collection('line_items').doc();
        tx.set(lineRef, {
          'pigId': item.pigId,
          'pigTagId': item.pigTagId,
          'finalWeightKg': item.finalWeightKg,
          'pricePerKgPhp': item.pricePerKgPhp,
          'lineRevenuePhp': item.lineRevenuePhp,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.update(pigRefs[item.pigId]!, {
          'status': 'sold',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Activity entry: one line summarizing the entire sale.
      final activityRef = _firestore
          .collection('farms')
          .doc(farmId)
          .collection('activity')
          .doc();
      tx.set(activityRef, {
        'actorUserId': actorUserId,
        'actorDisplayName': actorDisplayName,
        'action': 'sale_logged',
        'entityType': 'sale',
        'entityId': saleRef.id,
        'summary':
            '$actorDisplayName logged sale of $totalHeads ${totalHeads == 1 ? "pig" : "pigs"} to ${buyerName.trim()} · ₱${totalRevenue.toStringAsFixed(0)}',
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
    return saleRef.id;
  }

  Stream<List<Sale>> streamSales(String farmId) {
    return _col(farmId)
        .orderBy('saleDate', descending: true)
        .snapshots()
        .map(
          (s) =>
              s.docs.map((d) => Sale.fromFirestore(d, farmId: farmId)).toList(),
        );
  }

  Stream<Sale?> streamSaleById({
    required String farmId,
    required String saleId,
  }) {
    return _col(farmId).doc(saleId).snapshots().map(
          (d) => d.exists ? Sale.fromFirestore(d, farmId: farmId) : null,
        );
  }

  Stream<List<SaleLineItem>> streamLineItems({
    required String farmId,
    required String saleId,
  }) {
    return _col(farmId)
        .doc(saleId)
        .collection('line_items')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => SaleLineItem.fromFirestore(
                  d,
                  farmId: farmId,
                  saleId: saleId,
                ),
              )
              .toList(),
        );
  }

  /// Stream sales whose saleDate falls in the given range — for profitability.
  Stream<List<Sale>> streamInRange({
    required String farmId,
    required Timestamp start,
    required Timestamp end,
  }) {
    return _col(farmId)
        .where('saleDate', isGreaterThanOrEqualTo: start)
        .where('saleDate', isLessThan: end)
        .snapshots()
        .map(
          (s) =>
              s.docs.map((d) => Sale.fromFirestore(d, farmId: farmId)).toList(),
        );
  }

  /// Finds the sale that contains this pig as a line item.
  /// Uses a collection-group query on line_items. Returns null if not found.
  Future<Sale?> findSaleForPig({
    required String farmId,
    required String pigId,
  }) async {
    final snap = await _firestore
        .collectionGroup('line_items')
        .where('pigId', isEqualTo: pigId)
        .limit(1)
        .get();
    for (final doc in snap.docs) {
      final saleRef = doc.reference.parent.parent;
      if (saleRef == null) continue;
      // Verify it's in the right farm.
      final parts = saleRef.path.split('/');
      if (parts[0] != 'farms' || parts[1] != farmId) continue;
      final saleSnap = await saleRef.get();
      if (saleSnap.exists) return Sale.fromFirestore(saleSnap, farmId: farmId);
    }
    return null;
  }
}
