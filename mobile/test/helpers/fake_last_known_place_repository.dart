import 'package:camp/core/data/last_known_place_model.dart';
import 'package:camp/core/data/last_known_place_repository.dart';

/// Fake in-memory implementation of [LastKnownPlaceRepository] for testing.
class FakeLastKnownPlaceRepository implements LastKnownPlaceRepository {
  /// Creates a [FakeLastKnownPlaceRepository] with optional initial cached place.
  FakeLastKnownPlaceRepository({this.cachedPlace});

  /// In-memory stored place snapshot.
  LastKnownPlace? cachedPlace;

  /// Counter of save operations.
  int saveCount = 0;

  @override
  Future<LastKnownPlace?> loadLastKnownPlace() async {
    return cachedPlace;
  }

  @override
  Future<void> saveLastKnownPlace(LastKnownPlace place) async {
    saveCount++;
    cachedPlace = place;
  }

  @override
  Future<void> clear() async {
    cachedPlace = null;
  }

  @override
  Future<void> flush() async {}
}

