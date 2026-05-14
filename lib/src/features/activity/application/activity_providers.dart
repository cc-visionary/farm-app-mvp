import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/activity_repository.dart';
import '../domain/activity_entry.dart';

final firestoreProvider = Provider<FirebaseFirestore>((_) => FirebaseFirestore.instance);

final activityRepositoryProvider = Provider<ActivityRepository>(
  (ref) => ActivityRepository(ref.watch(firestoreProvider)),
);

final recentActivityProvider =
    StreamProvider.family<List<ActivityEntry>, String>((ref, farmId) {
  return ref.watch(activityRepositoryProvider).streamRecent(farmId, limit: 50);
});
