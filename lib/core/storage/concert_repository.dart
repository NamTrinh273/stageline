import '../models/models.dart';

/// Platform-agnostic offline storage contract for concert [Setlist] packages.
abstract interface class ConcertRepository {
  /// Loads all saved setlists sorted by `updatedAt` descending.
  Future<List<Setlist>> loadAll();

  /// Loads a single setlist by [id], or `null` if not found.
  Future<Setlist?> loadById(String id);

  /// Persists [setlist] atomically to local offline storage.
  Future<void> save(Setlist setlist);

  /// Deletes the setlist with [id] if it exists.
  Future<void> delete(String id);
}
