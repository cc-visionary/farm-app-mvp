import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:farm_app/src/features/inventory/domain/supply.dart';
import 'package:farm_app/src/features/inventory/domain/supply_category.dart';
import 'package:farm_app/src/features/inventory/domain/supply_movement.dart';
import 'package:farm_app/src/features/profitability/application/profitability_calculator.dart';
import 'package:farm_app/src/features/sales/domain/payment_method.dart';
import 'package:farm_app/src/features/sales/domain/payment_status.dart';
import 'package:farm_app/src/features/sales/domain/sale.dart';

Sale _sale({required DateTime date, required double revenue}) => Sale(
      id: 's',
      farmId: 'f',
      buyerName: 'X',
      buyerContact: null,
      saleDate: Timestamp.fromDate(date),
      totalHeads: 1,
      totalWeightKg: 90,
      totalRevenuePhp: revenue,
      paymentMethod: PaymentMethod.cash,
      paymentStatus: PaymentStatus.paid,
      amountPaidPhp: null,
      notes: null,
      createdBy: 'u',
      createdAt: Timestamp.now(),
    );

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
  required DateTime at,
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
      relatedBatchId: null,
      relatedHealthRecordId: null,
      notes: null,
      createdBy: 'u',
      createdAt: Timestamp.fromDate(at),
    );

void main() {
  test('period P&L sums revenue and feed cost in range', () {
    final start = DateTime(2026, 5, 1);
    final end = DateTime(2026, 6, 1);
    final r = ProfitabilityCalculator.forPeriod(
      start: Timestamp.fromDate(start),
      end: Timestamp.fromDate(end),
      sales: [
        _sale(date: DateTime(2026, 5, 10), revenue: 50000),
        _sale(date: DateTime(2026, 5, 20), revenue: 25000),
        _sale(date: DateTime(2026, 4, 15), revenue: 999999), // before period
      ],
      movements: [
        _consumption(supplyId: 's1', qty: 5, at: DateTime(2026, 5, 12)),
      ],
      suppliesById: {'s1': _supply('s1', SupplyCategory.feed, 1650.0)},
      healthRecords: const [],
      expenses: const [],
    );
    expect(r.revenuePhp, 75000);
    expect(r.feedCostPhp, 5 * 1650);
    expect(r.totalCostPhp, 5 * 1650);
    expect(r.grossProfitPhp, 75000 - 5 * 1650);
    expect(r.marginPct, closeTo((75000 - 5 * 1650) / 75000 * 100, 0.01));
  });

  test('zero revenue yields 0 margin (not NaN)', () {
    final r = ProfitabilityCalculator.forPeriod(
      start: Timestamp.fromDate(DateTime(2026, 1, 1)),
      end: Timestamp.fromDate(DateTime(2026, 12, 31)),
      sales: const [],
      movements: const [],
      suppliesById: const {},
      healthRecords: const [],
      expenses: const [],
    );
    expect(r.marginPct, 0);
    expect(r.grossProfitPhp, 0);
  });
}
