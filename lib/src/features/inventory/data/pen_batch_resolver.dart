import '../../pigs/domain/pig.dart';

class PenBatchResolver {
  PenBatchResolver._();

  /// Given a pen ID and the full list of pigs in the farm, returns the
  /// "primary batch" for that pen — the batch with the most active pigs
  /// currently in the pen. Returns null if no pig in the pen has a batch.
  ///
  /// Ties are broken by alphabetical batch ID for deterministic output.
  static String? primaryBatchForPen({
    required String penId,
    required List<Pig> pigs,
  }) {
    final counts = <String, int>{};
    for (final p in pigs) {
      if (p.currentPenId != penId) continue;
      if (p.status != PigStatus.active) continue;
      if (p.currentBatchId == null) continue;
      counts[p.currentBatchId!] = (counts[p.currentBatchId!] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    final entries = counts.entries.toList()
      ..sort((a, b) {
        final cmp = b.value.compareTo(a.value);
        return cmp != 0 ? cmp : a.key.compareTo(b.key);
      });
    return entries.first.key;
  }
}
