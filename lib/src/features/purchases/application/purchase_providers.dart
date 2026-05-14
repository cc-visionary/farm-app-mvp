import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../activity/application/activity_providers.dart';
import '../data/purchase_repository.dart';
import '../domain/purchase.dart';
import '../domain/purchase_line_item.dart';

final purchaseRepositoryProvider = Provider<PurchaseRepository>(
  (ref) => PurchaseRepository(
    ref.watch(firestoreProvider),
    ref.watch(activityRepositoryProvider),
  ),
);

final purchasesStreamProvider =
    StreamProvider.family<List<Purchase>, String>((ref, farmId) {
  return ref.watch(purchaseRepositoryProvider).streamPurchases(farmId);
});

final purchaseByIdProvider = StreamProvider.family<
    Purchase?,
    ({String farmId, String purchaseId})>((ref, args) {
  return ref.watch(purchaseRepositoryProvider).streamPurchaseById(
        farmId: args.farmId,
        purchaseId: args.purchaseId,
      );
});

final purchaseLineItemsProvider = StreamProvider.family<
    List<PurchaseLineItem>,
    ({String farmId, String purchaseId})>((ref, args) {
  return ref.watch(purchaseRepositoryProvider).streamLineItems(
        farmId: args.farmId,
        purchaseId: args.purchaseId,
      );
});
