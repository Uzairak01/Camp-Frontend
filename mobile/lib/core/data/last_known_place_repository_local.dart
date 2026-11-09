import '../storage/local_store.dart';
import 'last_known_place_model.dart';
import 'last_known_place_repository.dart';

/// Local persistence implementation for [LastKnownPlaceRepository] backed by [LocalStore].
///
/// Ensures the rider's last known place label, coordinates, and timestamp survive app restarts
/// for immediate cold-start display without showing "Locating...".
class LastKnownPlaceRepositoryLocal implements LastKnownPlaceRepository {
  /// Creates a [LastKnownPlaceRepositoryLocal] backed by [store] or [LocalStore.instance].
  LastKnownPlaceRepositoryLocal([LocalStore? store]) : _explicitStore = store;

  final LocalStore? _explicitStore;
  LocalStore get _store => _explicitStore ?? LocalStore.instance;

  /// Key under which the last known place JSON object is persisted in [LocalStore].
  static const String keyLastKnownPlace = 'camp_last_known_place';

  @override
  Future<LastKnownPlace?> loadLastKnownPlace() async {
    final json = await _store.readJson(keyLastKnownPlace);
    if (json is! Map) {
      return null;
    }
    final map = json is Map<String, dynamic> ? json : json.cast<String, dynamic>();
    return LastKnownPlace.fromJson(map);
  }

  @override
  Future<void> saveLastKnownPlace(LastKnownPlace place) async {
    await _store.writeJson(keyLastKnownPlace, place.toJson());
  }

  @override
  Future<void> clear() async {
    await _store.remove(keyLastKnownPlace);
  }

  @override
  Future<void> flush() async {
    await _store.flush();
  }
}

