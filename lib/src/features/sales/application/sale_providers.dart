import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../activity/application/activity_providers.dart';
import '../data/sale_repository.dart';
import '../domain/sale.dart';
import '../domain/sale_line_item.dart';

final saleRepositoryProvider = Provider<SaleRepository>(
  (ref) => SaleRepository(
    ref.watch(firestoreProvider),
    ref.watch(activityRepositoryProvider),
  ),
);

final salesStreamProvider =
    StreamProvider.family<List<Sale>, String>((ref, farmId) {
  return ref.watch(saleRepositoryProvider).streamSales(farmId);
});

final saleByIdProvider =
    StreamProvider.family<Sale?, ({String farmId, String saleId})>((ref, args) {
  return ref.watch(saleRepositoryProvider).streamSaleById(
        farmId: args.farmId,
        saleId: args.saleId,
      );
});

final saleLineItemsProvider = StreamProvider.family<
    List<SaleLineItem>,
    ({String farmId, String saleId})>((ref, args) {
  return ref.watch(saleRepositoryProvider).streamLineItems(
        farmId: args.farmId,
        saleId: args.saleId,
      );
});

final saleForPigProvider =
    FutureProvider.family<Sale?, ({String farmId, String pigId})>((ref, args) {
  return ref.read(saleRepositoryProvider).findSaleForPig(
        farmId: args.farmId,
        pigId: args.pigId,
      );
});
