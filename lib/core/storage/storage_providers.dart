import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'concert_repository.dart';
import 'local_json_concert_repository.dart';

/// Provides the offline [ConcertRepository] implementation.
final concertRepositoryProvider = Provider<ConcertRepository>((ref) {
  return LocalJsonConcertRepository();
});

/// Reactive list of saved concert [Setlist]s backed by [concertRepositoryProvider].
final setlistsProvider = AsyncNotifierProvider<SetlistsNotifier, List<Setlist>>(
  SetlistsNotifier.new,
);

class SetlistsNotifier extends AsyncNotifier<List<Setlist>> {
  @override
  Future<List<Setlist>> build() {
    return ref.watch(concertRepositoryProvider).loadAll();
  }

  Future<void> saveSetlist(Setlist setlist) async {
    final repo = ref.read(concertRepositoryProvider);
    final updated = setlist.copyWith(updatedAt: DateTime.now().toUtc());
    await repo.save(updated);
    ref.invalidateSelf();
    await future;
  }

  Future<void> deleteSetlist(String id) async {
    final repo = ref.read(concertRepositoryProvider);
    await repo.delete(id);
    ref.invalidateSelf();
    await future;
  }
}
