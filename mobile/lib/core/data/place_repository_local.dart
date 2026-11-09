import '../../features/navigation/domain/geocoding_service.dart';
import '../storage/local_store.dart';
import 'place_repository.dart';

class PlaceRepositoryLocal implements PlaceRepository {
  PlaceRepositoryLocal([LocalStore? store]) : _explicitStore = store;

  final LocalStore? _explicitStore;
  LocalStore get _store => _explicitStore ?? LocalStore.instance;

  /// Known IDs of legacy demo seeded places.
  static const Set<String> seededPlaceIds = {
    'seed-place-1',
    'seed-place-2',
    'seed-place-3',
    'seed-place-4',
    'demo-place-1',
    'demo-place-2',
    'demo-place-3',
    'demo-place-4',
    'saved-place-mountain-pass',
    'saved-place-basecamp',
    'saved-place-high-camp',
    'saved-place-valley-rest',
    '48.5135_-120.6877_Timber Ridge Moto Outpost',
    '48.5262_-120.6542_Cascade Alpine Loop Summit',
    '48.4891_-120.2114_Bear Creek Pass Rd',
    '48.3712_-120.1553_Silver Creek Rest Area',
  };

  /// Known exact names of legacy demo seeded places.
  static const Set<String> seededPlaceNames = {
    'Basecamp',
    'Mountain Pass',
    'High Camp',
    'Valley Rest',
    'Timber Ridge Moto Outpost',
    'Cascade Alpine Loop Summit',
    'Bear Creek Pass Rd',
    'Silver Creek Rest Area',
  };

  /// Determines whether a place record matches the legacy demo seed places.
  /// Matches strictly by exact seed ID, or exact legacy seed prefix plus exact name.
  /// A real place named "Basecamp" or "Mountain Pass" saved by the rider must survive.
  static bool isSeededPlace(PlaceSearchResult place) {
    final trimmedId = place.id.trim();
    if (seededPlaceIds.contains(trimmedId)) return true;
    if ((trimmedId.startsWith('seed-') ||
            trimmedId.startsWith('demo-') ||
            trimmedId.startsWith('saved-place-')) &&
        seededPlaceNames.contains(place.name.trim())) {
      return true;
    }
    // Also if place matches exact demo location coordinates and demo name
    if (place.name.trim() == 'Timber Ridge Moto Outpost' &&
        place.location.latitude == 48.5135 &&
        place.location.longitude == -120.6877) {
      return true;
    }
    if (place.name.trim() == 'Cascade Alpine Loop Summit' &&
        place.location.latitude == 48.5262 &&
        place.location.longitude == -120.6542) {
      return true;
    }
    if (place.name.trim() == 'Bear Creek Pass Rd' &&
        place.location.latitude == 48.4891 &&
        place.location.longitude == -120.2114) {
      return true;
    }
    if (place.name.trim() == 'Silver Creek Rest Area' &&
        place.location.latitude == 48.3712 &&
        place.location.longitude == -120.1553) {
      return true;
    }
    return false;
  }

  @override
  Future<List<PlaceSearchResult>> loadSavedPlaces() async {
    final json = await _store.readJson(LocalStore.keySavedPlaces);
    if (json is! List) {
      return [];
    }

    bool needsMigration = false;
    final places = <PlaceSearchResult>[];

    for (int i = 0; i < json.length; i++) {
      final raw = json[i];
      if (raw is Map) {
        final map = raw is Map<String, dynamic> ? raw : raw.cast<String, dynamic>();
        final place = PlaceSearchResult.fromJson(map);

        // One-time cleanup: remove saved legacy demo places.
        // Places saved by the rider are never touched.
        if (isSeededPlace(place)) {
          needsMigration = true;
          continue;
        }

        if (place.id.isEmpty || map['id'] == null || (map['id'] as String).isEmpty) {
          needsMigration = true;
          places.add(place.copyWith(id: 'place_${DateTime.now().millisecondsSinceEpoch}_$i'));
        } else {
          if (map['createdAt'] == null || map['updatedAt'] == null) {
            needsMigration = true;
          }
          places.add(place);
        }
      }
    }

    if (needsMigration) {
      await saveSavedPlaces(places);
    }

    return places;
  }

  @override
  Future<void> saveSavedPlaces(List<PlaceSearchResult> places) async {
    final now = DateTime.now().toUtc();
    final updated = places.map((p) {
      return p.copyWith(
        id: p.effectiveId,
        createdAt: p.effectiveCreatedAt,
        updatedAt: now,
      );
    }).toList();

    await _store.writeJson(
      LocalStore.keySavedPlaces,
      updated.map((p) => p.toJson()).toList(),
    );
  }

  @override
  Future<void> deleteSavedPlace(String id) async {
    final current = await loadSavedPlaces();
    final filtered = current.where((p) => p.effectiveId != id).toList();
    await saveSavedPlaces(filtered);
  }

  @override
  Future<List<PlaceSearchResult>> loadRecentPlaces() async {
    final json = await _store.readJson(LocalStore.keyRecentPlaces);
    if (json is! List) {
      return [];
    }

    bool needsMigration = false;
    final places = <PlaceSearchResult>[];

    for (int i = 0; i < json.length; i++) {
      final raw = json[i];
      if (raw is Map) {
        final map = raw is Map<String, dynamic> ? raw : raw.cast<String, dynamic>();
        final place = PlaceSearchResult.fromJson(map);

        // One-time cleanup: remove saved legacy demo recent places.
        // Places searched by the rider are never touched.
        if (isSeededPlace(place)) {
          needsMigration = true;
          continue;
        }

        if (place.id.isEmpty || map['id'] == null || (map['id'] as String).isEmpty) {
          needsMigration = true;
          places.add(place.copyWith(id: 'recent_${DateTime.now().millisecondsSinceEpoch}_$i'));
        } else {
          if (map['createdAt'] == null || map['updatedAt'] == null) {
            needsMigration = true;
          }
          places.add(place);
        }
      }
    }

    if (needsMigration) {
      await saveRecentPlaces(places);
    }

    return places;
  }

  @override
  Future<void> saveRecentPlaces(List<PlaceSearchResult> places) async {
    final now = DateTime.now().toUtc();
    final updated = places.map((p) {
      return p.copyWith(
        id: p.effectiveId,
        createdAt: p.effectiveCreatedAt,
        updatedAt: now,
      );
    }).toList();

    await _store.writeJson(
      LocalStore.keyRecentPlaces,
      updated.map((p) => p.toJson()).toList(),
    );
  }

  @override
  Future<void> deleteRecentPlace(String id) async {
    final current = await loadRecentPlaces();
    final filtered = current.where((p) => p.effectiveId != id).toList();
    await saveRecentPlaces(filtered);
  }

  @override
  Future<void> clear() async {
    await _store.writeJson(LocalStore.keySavedPlaces, null);
    await _store.writeJson(LocalStore.keyRecentPlaces, null);
  }

  @override
  Future<void> flush() async {
    await _store.flush();
  }
}

PlaceRepository resolvePlaceRepository(dynamic source, [PlaceRepository? fallback]) {
  if (source is PlaceRepository) return source;
  if (source is LocalStore) return PlaceRepositoryLocal(source);
  return fallback ?? PlaceRepositoryLocal();
}
