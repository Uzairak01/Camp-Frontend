import 'last_known_place_model.dart';

/// Contract for persisting and retrieving the rider's last known place snapshot.
///
/// Follows the repository pattern used across CAMP to ensure tolerant storage
/// and clean testability without direct hardware or filesystem coupling.
abstract class LastKnownPlaceRepository {
  /// Loads the persisted [LastKnownPlace] snapshot from disk, or returns null if none exists.
  Future<LastKnownPlace?> loadLastKnownPlace();

  /// Persists the given [LastKnownPlace] snapshot to storage.
  Future<void> saveLastKnownPlace(LastKnownPlace place);

  /// Clears any persisted place snapshot.
  Future<void> clear();

  /// Flushes any pending writes to disk.
  Future<void> flush();
}

