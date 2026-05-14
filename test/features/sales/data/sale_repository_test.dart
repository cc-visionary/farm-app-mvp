import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:farm_app/src/features/activity/data/activity_repository.dart';
import 'package:farm_app/src/features/sales/data/sale_repository.dart';
import 'package:farm_app/src/features/sales/domain/payment_method.dart';
import 'package:farm_app/src/features/sales/domain/payment_status.dart';

void main() {
  Future<void> seedPig(
    FakeFirebaseFirestore f,
    String farmId,
    String pigId, {
    String tagId = 'P',
    String status = 'active',
  }) async {
    await f.collection('farms').doc(farmId).collection('pigs').doc(pigId).set({
      'tagId': tagId,
      'sex': 'female',
      'breed': 'X',
      'birthDate': Timestamp.now(),
      'stage': 'finisher',
      'status': status,
      'currentAreaId': 'a1',
      'createdBy': 'u',
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
  }

  test('logSale writes sale + line items + flips all pigs to sold (atomic)',
      () async {
    final f = FakeFirebaseFirestore();
    await seedPig(f, 'f1', 'p1', tagId: 'F-001');
    await seedPig(f, 'f1', 'p2', tagId: 'F-002');
    final repo = SaleRepository(f, ActivityRepository(f));

    final saleId = await repo.logSale(
      farmId: 'f1',
      buyerName: 'Mang Berto',
      buyerContact: '0917-555-1234',
      saleDate: Timestamp.now(),
      paymentMethod: PaymentMethod.cash,
      paymentStatus: PaymentStatus.paid,
      amountPaidPhp: null,
      lineItems: [
        SaleLineItemInput(
            pigId: 'p1',
            pigTagId: 'F-001',
            finalWeightKg: 90,
            pricePerKgPhp: 240),
        SaleLineItemInput(
            pigId: 'p2',
            pigTagId: 'F-002',
            finalWeightKg: 95,
            pricePerKgPhp: 240),
      ],
      notes: null,
      actorUserId: 'u1',
      actorDisplayName: 'Owner',
    );

    final sale = await f
        .collection('farms')
        .doc('f1')
        .collection('sales')
        .doc(saleId)
        .get();
    expect(sale.data()!['totalHeads'], 2);
    expect((sale.data()!['totalWeightKg'] as num).toDouble(), 185);
    expect(
      (sale.data()!['totalRevenuePhp'] as num).toDouble(),
      closeTo(90 * 240 + 95 * 240, 0.01),
    );

    final lines = await f
        .collection('farms')
        .doc('f1')
        .collection('sales')
        .doc(saleId)
        .collection('line_items')
        .get();
    expect(lines.docs, hasLength(2));

    final pig1 = await f
        .collection('farms')
        .doc('f1')
        .collection('pigs')
        .doc('p1')
        .get();
    final pig2 = await f
        .collection('farms')
        .doc('f1')
        .collection('pigs')
        .doc('p2')
        .get();
    expect(pig1.data()!['status'], 'sold');
    expect(pig2.data()!['status'], 'sold');

    final activity =
        await f.collection('farms').doc('f1').collection('activity').get();
    expect(
      activity.docs.where((d) => d.data()['action'] == 'sale_logged'),
      hasLength(1),
    );
  });

  test('rejects when one of the pigs is not active', () async {
    final f = FakeFirebaseFirestore();
    await seedPig(f, 'f1', 'p1');
    await seedPig(f, 'f1', 'p2', status: 'deceased');
    final repo = SaleRepository(f, ActivityRepository(f));

    expect(
      () => repo.logSale(
        farmId: 'f1',
        buyerName: 'X',
        buyerContact: null,
        saleDate: Timestamp.now(),
        paymentMethod: PaymentMethod.cash,
        paymentStatus: PaymentStatus.paid,
        amountPaidPhp: null,
        lineItems: [
          SaleLineItemInput(
              pigId: 'p1',
              pigTagId: 'P1',
              finalWeightKg: 90,
              pricePerKgPhp: 240),
          SaleLineItemInput(
              pigId: 'p2',
              pigTagId: 'P2',
              finalWeightKg: 95,
              pricePerKgPhp: 240),
        ],
        notes: null,
        actorUserId: 'u',
        actorDisplayName: 'O',
      ),
      throwsA(isA<StateError>()),
    );

    // Verify partial atomicity: nothing was written.
    final sales =
        await f.collection('farms').doc('f1').collection('sales').get();
    expect(sales.docs, isEmpty);
    final pig1 = await f
        .collection('farms')
        .doc('f1')
        .collection('pigs')
        .doc('p1')
        .get();
    expect(pig1.data()!['status'], 'active');
  });

  test('empty line items throws ArgumentError', () async {
    final f = FakeFirebaseFirestore();
    final repo = SaleRepository(f, ActivityRepository(f));
    expect(
      () => repo.logSale(
        farmId: 'f1',
        buyerName: 'X',
        buyerContact: null,
        saleDate: Timestamp.now(),
        paymentMethod: PaymentMethod.cash,
        paymentStatus: PaymentStatus.paid,
        amountPaidPhp: null,
        lineItems: const [],
        notes: null,
        actorUserId: 'u',
        actorDisplayName: 'O',
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
}
