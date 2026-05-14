// lib/src/features/expenses/application/expense_providers.dart
//
// Riverpod wiring for the expenses feature. The repository depends on the
// shared firestoreProvider and activityRepositoryProvider so unit tests and
// the live app share the same composition root.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../activity/application/activity_providers.dart';
import '../data/expense_repository.dart';
import '../domain/expense.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => ExpenseRepository(
    ref.watch(firestoreProvider),
    ref.watch(activityRepositoryProvider),
  ),
);

final expensesStreamProvider =
    StreamProvider.family<List<Expense>, String>((ref, farmId) {
  return ref.watch(expenseRepositoryProvider).streamExpenses(farmId);
});

final expensesInRangeProvider = StreamProvider.family<
    List<Expense>,
    ({String farmId, Timestamp start, Timestamp end})>((ref, args) {
  return ref.watch(expenseRepositoryProvider).streamInRange(
        farmId: args.farmId,
        start: args.start,
        end: args.end,
      );
});

final expensesForBatchProvider = StreamProvider.family<
    List<Expense>,
    ({String farmId, String batchId})>((ref, args) {
  return ref.watch(expenseRepositoryProvider).streamForBatch(
        farmId: args.farmId,
        batchId: args.batchId,
      );
});
