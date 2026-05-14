import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:farm_app/src/features/activity/data/activity_repository.dart';
import 'package:farm_app/src/features/expenses/data/expense_repository.dart';
import 'package:farm_app/src/features/expenses/domain/expense_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('createExpense writes doc and activity', () async {
    final f = FakeFirebaseFirestore();
    final repo = ExpenseRepository(f, ActivityRepository(f));

    final id = await repo.createExpense(
      farmId: 'f1',
      category: ExpenseCategory.utilities,
      description: 'May electricity',
      amountPhp: 8500,
      date: Timestamp.now(),
      actorUserId: 'u',
      actorDisplayName: 'J',
    );
    expect(id, isNotEmpty);

    final doc = await f
        .collection('farms')
        .doc('f1')
        .collection('expenses')
        .doc(id)
        .get();
    expect(doc.data()!['description'], 'May electricity');
    expect(doc.data()!['amountPhp'], 8500);
    expect(doc.data()!['category'], 'utilities');

    final activity = await f
        .collection('farms')
        .doc('f1')
        .collection('activity')
        .get();
    expect(
      activity.docs.where((d) => d.data()['action'] == 'expense_logged'),
      hasLength(1),
    );
  });

  test('rejects empty description', () async {
    final f = FakeFirebaseFirestore();
    final repo = ExpenseRepository(f, ActivityRepository(f));

    expect(
      () => repo.createExpense(
        farmId: 'f1',
        category: ExpenseCategory.other,
        description: '',
        amountPhp: 100,
        date: Timestamp.now(),
        actorUserId: 'u',
        actorDisplayName: 'J',
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('rejects non-positive amount', () async {
    final f = FakeFirebaseFirestore();
    final repo = ExpenseRepository(f, ActivityRepository(f));

    expect(
      () => repo.createExpense(
        farmId: 'f1',
        category: ExpenseCategory.other,
        description: 'X',
        amountPhp: 0,
        date: Timestamp.now(),
        actorUserId: 'u',
        actorDisplayName: 'J',
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
}
