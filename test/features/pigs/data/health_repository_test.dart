import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:farm_app/src/features/activity/data/activity_repository.dart';
import 'package:farm_app/src/features/pigs/data/health_repository.dart';
import 'package:farm_app/src/features/pigs/domain/health_record.dart';
import 'package:farm_app/src/features/tasks/application/task_generator.dart';
import 'package:farm_app/src/features/tasks/data/task_repository.dart';
import 'package:flutter_test/flutter_test.dart';

({HealthRepository repo, FakeFirebaseFirestore firestore}) newRepo() {
  final f = FakeFirebaseFirestore();
  final activity = ActivityRepository(f);
  final gen = TaskGenerator(f, TaskRepository(f));
  return (repo: HealthRepository(f, activity, gen), firestore: f);
}

void main() {
  test(
    'logHealth with withdrawalEndDate generates withdrawal_end task + activity entry',
    () async {
      final t = newRepo();
      final end = Timestamp.fromMillisecondsSinceEpoch(1800000000000);
      final id = await t.repo.logHealth(
        farmId: 'f1',
        pigId: 'p1',
        tagId: 'PIG-1',
        areaId: 'a1',
        type: HealthEventType.vaccination,
        date: Timestamp.now(),
        productName: 'PRRS Vax',
        dosage: '2ml',
        route: HealthRoute.im,
        diagnosis: null,
        withdrawalEndDate: end,
        costPhp: 150,
        photoUrls: const ['https://example.com/p1.jpg'],
        notes: null,
        actorUserId: 'u1',
        actorDisplayName: 'Juan',
      );
      expect(id, isNotEmpty);

      // Health record persisted on the pig subcollection.
      final hr = await t.firestore
          .collection('farms')
          .doc('f1')
          .collection('pigs')
          .doc('p1')
          .collection('health_records')
          .doc(id)
          .get();
      expect(hr.exists, isTrue);
      expect(hr.data()!['type'], 'vaccination');
      expect(hr.data()!['productName'], 'PRRS Vax');
      expect(hr.data()!['route'], 'im');
      expect(hr.data()!['photoUrls'], ['https://example.com/p1.jpg']);

      // Withdrawal task auto-generated with deterministic ID.
      final tasksSnap = await t.firestore
          .collection('farms')
          .doc('f1')
          .collection('tasks')
          .get();
      final withdrawals = tasksSnap.docs.where(
        (d) => d.data()['type'] == 'withdrawal_end',
      );
      expect(withdrawals, hasLength(1));
      expect(withdrawals.single.id, 'hr_${id}_wd');
      expect(withdrawals.single.data()['relatedPigId'], 'p1');
      expect(
        (withdrawals.single.data()['dueDate'] as Timestamp).millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      );

      // Activity entry written atomically.
      final activity = await t.firestore
          .collection('farms')
          .doc('f1')
          .collection('activity')
          .get();
      expect(activity.docs, hasLength(1));
      expect(activity.docs.single.data()['action'], 'health_logged');
      expect(activity.docs.single.data()['entityId'], 'p1');
    },
  );

  test(
    'logHealth without withdrawalEndDate does NOT generate a withdrawal task',
    () async {
      final t = newRepo();
      await t.repo.logHealth(
        farmId: 'f1',
        pigId: 'p1',
        tagId: 'PIG-1',
        areaId: 'a1',
        type: HealthEventType.checkup,
        date: Timestamp.now(),
        productName: null,
        dosage: null,
        route: null,
        diagnosis: null,
        withdrawalEndDate: null,
        costPhp: null,
        photoUrls: const [],
        notes: null,
        actorUserId: 'u1',
        actorDisplayName: 'Juan',
      );
      final tasks = await t.firestore
          .collection('farms')
          .doc('f1')
          .collection('tasks')
          .get();
      expect(tasks.docs, isEmpty);

      // Activity still recorded even without withdrawal.
      final activity = await t.firestore
          .collection('farms')
          .doc('f1')
          .collection('activity')
          .get();
      expect(activity.docs, hasLength(1));
    },
  );
}
