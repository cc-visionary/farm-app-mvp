import 'package:cloud_firestore/cloud_firestore.dart';
import '../../activity/data/activity_repository.dart';
import '../domain/purchase.dart';
import '../domain/purchase_line_item.dart';

/// Input shape for log-purchase: not persisted with this exact name,
/// just a value type for the repository method signature.
class PurchaseLineItemInput {
  PurchaseLineItemInput({
    required this.supplyId,
    required this.quantity,
    required this.unitCostPhp,
  });
  final String supplyId;
  final num quantity;
  final double unitCostPhp;
  double get lineTotalPhp => (quantity * unitCostPhp).toDouble();
}

class PurchaseRepository {
  PurchaseRepository(this._firestore, this._activity);
  final FirebaseFirestore _firestore;
  // Activity entry is written inline within the transaction; the repository
  // accepts an [ActivityRepository] for consistency with peer repositories
  // and future expansion, even though no method is invoked on it here.
  // ignore: unused_field
  final ActivityRepository _activity;

  CollectionReference<Map<String, dynamic>> _col(String farmId) =>
      _firestore.collection('farms').doc(farmId).collection('purchases');

  /// Atomically writes the purchase header, line items, supply_movements,
  /// and updates each supply's currentStock + weightedAvgUnitCostPhp.
  /// Uses runTransaction because weighted-avg needs the pre-purchase value.
  ///
  /// Throws [ArgumentError] when [lineItems] is empty.
  /// Throws [StateError] when any referenced supply does not exist.
  Future<String> logPurchase({
    required String farmId,
    required String vendorName,
    required Timestamp purchaseDate,
    required String? referenceNo,
    required List<PurchaseLineItemInput> lineItems,
    required String? receiptPhotoUrl,
    required String? notes,
    required String actorUserId,
    required String actorDisplayName,
  }) async {
    if (lineItems.isEmpty) {
      throw ArgumentError('At least one line item is required.');
    }
    final purchaseRef = _col(farmId).doc();
    final totalCost = lineItems.fold<double>(0, (s, i) => s + i.lineTotalPhp);

    await _firestore.runTransaction((tx) async {
      // Phase 1 — reads. Transactions require all reads before any writes.
      // Read each unique supply's current stock + weighted avg once.
      final supplyRefs = <String, DocumentReference<Map<String, dynamic>>>{};
      final currentStock = <String, num>{};
      final currentAvg = <String, double>{};
      for (final item in lineItems) {
        if (supplyRefs.containsKey(item.supplyId)) continue;
        final ref = _firestore
            .collection('farms')
            .doc(farmId)
            .collection('supplies')
            .doc(item.supplyId);
        final snap = await tx.get(ref);
        if (!snap.exists) {
          throw StateError('Supply ${item.supplyId} not found.');
        }
        supplyRefs[item.supplyId] = ref;
        currentStock[item.supplyId] =
            (snap.data()!['currentStock'] as num?) ?? 0;
        currentAvg[item.supplyId] =
            (snap.data()!['weightedAvgUnitCostPhp'] as num?)?.toDouble() ?? 0.0;
      }

      // Phase 2 — writes: purchase header, line items, movements, supply
      // updates, and a single activity entry summarizing the purchase.
      tx.set(purchaseRef, {
        'vendorName': vendorName.trim(),
        'purchaseDate': purchaseDate,
        if (referenceNo != null && referenceNo.trim().isNotEmpty)
          'referenceNo': referenceNo.trim(),
        'totalCostPhp': totalCost,
        if (receiptPhotoUrl != null) 'receiptPhotoUrl': receiptPhotoUrl,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        'createdBy': actorUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Aggregate per-supply increments for weighted-avg recomputation.
      // If the same supply appears multiple times in line items, sum the
      // qty and the (qty * unitCost) cost before recomputing the avg.
      final supplyAddedQty = <String, num>{};
      final supplyAddedCost = <String, double>{};
      for (final item in lineItems) {
        final lineRef = purchaseRef.collection('line_items').doc();
        tx.set(lineRef, {
          'supplyId': item.supplyId,
          'quantity': item.quantity,
          'unitCostPhp': item.unitCostPhp,
          'lineTotalPhp': item.lineTotalPhp,
          'createdAt': FieldValue.serverTimestamp(),
        });

        final movementRef = _firestore
            .collection('farms')
            .doc(farmId)
            .collection('supply_movements')
            .doc();
        tx.set(movementRef, {
          'supplyId': item.supplyId,
          'type': 'purchase',
          'quantity': item.quantity,
          'unitCostPhp': item.unitCostPhp,
          'relatedPurchaseId': purchaseRef.id,
          'createdBy': actorUserId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        supplyAddedQty[item.supplyId] =
            (supplyAddedQty[item.supplyId] ?? 0) + item.quantity;
        supplyAddedCost[item.supplyId] =
            (supplyAddedCost[item.supplyId] ?? 0) + item.lineTotalPhp;
      }

      // Now update each supply's currentStock + weightedAvgUnitCostPhp.
      for (final entry in supplyAddedQty.entries) {
        final supplyId = entry.key;
        final addedQty = entry.value;
        final addedCost = supplyAddedCost[supplyId]!;
        final prevStock = currentStock[supplyId]!;
        final prevAvg = currentAvg[supplyId]!;
        final newStock = prevStock + addedQty;
        final newAvg = newStock == 0
            ? 0.0
            : ((prevStock * prevAvg) + addedCost) / newStock;
        tx.update(supplyRefs[supplyId]!, {
          'currentStock': newStock,
          'weightedAvgUnitCostPhp': newAvg,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Activity entry: a single line summarizing the entire purchase.
      final activityRef = _firestore
          .collection('farms')
          .doc(farmId)
          .collection('activity')
          .doc();
      tx.set(activityRef, {
        'actorUserId': actorUserId,
        'actorDisplayName': actorDisplayName,
        'action': 'purchase_logged',
        'entityType': 'purchase',
        'entityId': purchaseRef.id,
        'summary':
            '$actorDisplayName logged purchase from ${vendorName.trim()} · ₱${totalCost.toStringAsFixed(0)}',
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
    return purchaseRef.id;
  }

  Stream<List<Purchase>> streamPurchases(String farmId) {
    return _col(farmId)
        .orderBy('purchaseDate', descending: true)
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) => Purchase.fromFirestore(d, farmId: farmId))
              .toList(),
        );
  }

  Stream<Purchase?> streamPurchaseById({
    required String farmId,
    required String purchaseId,
  }) {
    return _col(farmId)
        .doc(purchaseId)
        .snapshots()
        .map(
          (d) => d.exists ? Purchase.fromFirestore(d, farmId: farmId) : null,
        );
  }

  Stream<List<PurchaseLineItem>> streamLineItems({
    required String farmId,
    required String purchaseId,
  }) {
    return _col(farmId)
        .doc(purchaseId)
        .collection('line_items')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => PurchaseLineItem.fromFirestore(
                  d,
                  farmId: farmId,
                  purchaseId: purchaseId,
                ),
              )
              .toList(),
        );
  }
}
