import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:farm_app/src/features/expenses/domain/expense.dart';
import 'package:farm_app/src/features/expenses/domain/expense_category.dart';
import 'package:farm_app/src/features/inventory/domain/supply.dart';
import 'package:farm_app/src/features/inventory/domain/supply_category.dart';
import 'package:farm_app/src/features/inventory/domain/supply_movement.dart';
import 'package:farm_app/src/features/pigs/domain/health_record.dart';
import 'package:farm_app/src/features/profitability/application/batch_cost_calculator.dart';

Supply _supply(String id, SupplyCategory cat, double avg) => Supply(
      id: id,
      farmId: 'f',
      name: 'X',
      category: cat,
      unit: SupplyUnit.sack,
      unitsPerPackage: null,
      lowStockThreshold: null,
      currentStock: 0,
      weightedAvgUnitCostPhp: avg,
      notes: null,
      createdBy: 'u',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );

SupplyMovement _consumption({
  required String supplyId,
  required num qty,
  required String batchId,
  String? healthRecordId,
}) =>
    SupplyMovement(
      id: 'm',
      farmId: 'f',
      supplyId: supplyId,
      type: MovementType.consumption,
      quantity: -qty,
      unitCostPhp: null,
      relatedPurchaseId: null,
      relatedPenId: null,
      relatedBatchId: batchId,
      relatedHealthRecordId: healthRecordId,
      notes: null,
      createdBy: 'u',
      createdAt: Timestamp.now(),
    );

HealthRecord _health({
  required String id,
  required String pigId,
  double cost = 0,
}) =>
    HealthRecord(
      id: id,
      farmId: 'f',
      pigId: pigId,
      type: HealthEventType.vaccination,
      date: Timestamp.now(),
      productName: null,
      dosage: null,
      route: null,
      diagnosis: null,
      withdrawalEndDate: null,
      costPhp: cost == 0 ? null : cost,
      photoUrls: const [],
      notes: null,
      createdBy: 'u',
      createdAt: Timestamp.now(),
    );

Expense _expense({
  required ExpenseCategory category,
  required double amount,
  String? batchId,
}) =>
    Expense(
      id: 'e',
      farmId: 'f',
      category: category,
      description: 'X',
      amountPhp: amount,
      date: Timestamp.now(),
      relatedBatchId: batchId,
      relatedEquipmentId: null,
      relatedPigId: null,
      relatedAreaId: null,
      receiptPhotoUrl: null,
      notes: null,
      createdBy: 'u',
      createdAt: Timestamp.now(),
    );

void main() {
  test('feed consumption attributed to batch', () {
    final supplies = {'s1': _supply('s1', SupplyCategory.feed, 1650.0)};
    final movements = [
      _consumption(supplyId: 's1', qty: 2, batchId: 'b1'),
      _consumption(supplyId: 's1', qty: 1, batchId: 'b2'),
    ];
    final r = BatchCostCalculator.forBatch(
      batchId: 'b1',
      movements: movements,
      suppliesById: supplies,
      healthRecords: const [],
      batchMemberPigIds: const {},
      expenses: const [],
    );
    expect(r.feedCostPhp, 2 * 1650);
    expect(r.totalCostPhp, 2 * 1650);
  });

  test('medicine: health record cost included when no matching movement', () {
    final supplies = {'s1': _supply('s1', SupplyCategory.medicine, 50.0)};
    final movements = <SupplyMovement>[];
    final health = [_health(id: 'h1', pigId: 'p1', cost: 200)];
    final r = BatchCostCalculator.forBatch(
      batchId: 'b1',
      movements: movements,
      suppliesById: supplies,
      healthRecords: health,
      batchMemberPigIds: {'p1'},
      expenses: const [],
    );
    expect(r.medicineCostPhp, 200);
  });

  test('medicine: movement cost wins over health-record costPhp (no double-count)',
      () {
    final supplies = {'s1': _supply('s1', SupplyCategory.medicine, 50.0)};
    final movements = [
      _consumption(
        supplyId: 's1',
        qty: 4,
        batchId: 'b1',
        healthRecordId: 'h1',
      ),
    ];
    final health = [_health(id: 'h1', pigId: 'p1', cost: 200)];
    final r = BatchCostCalculator.forBatch(
      batchId: 'b1',
      movements: movements,
      suppliesById: supplies,
      healthRecords: health,
      batchMemberPigIds: {'p1'},
      expenses: const [],
    );
    // 4 × 50 = 200 from movement; health record cost is SKIPPED.
    expect(r.medicineCostPhp, 200);
  });

  test('expenses by category attributed', () {
    final r = BatchCostCalculator.forBatch(
      batchId: 'b1',
      movements: const [],
      suppliesById: const {},
      healthRecords: const [],
      batchMemberPigIds: const {},
      expenses: [
        _expense(category: ExpenseCategory.labor, amount: 5000, batchId: 'b1'),
        _expense(
            category: ExpenseCategory.utilities, amount: 2000, batchId: 'b1'),
        _expense(
            category: ExpenseCategory.labor,
            amount: 9999,
            batchId: 'b2'), // wrong batch
      ],
    );
    expect(r.laborCostPhp, 5000);
    expect(r.utilitiesCostPhp, 2000);
    expect(r.totalCostPhp, 7000);
  });
}
