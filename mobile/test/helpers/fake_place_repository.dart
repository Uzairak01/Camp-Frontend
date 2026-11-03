import 'package:camp/core/data/place_repository.dart';
import 'package:camp/features/navigation/domain/geocoding_service.dart';

/// In-memory [PlaceRepository] for tests; exposes its lists for assertions.
class FakePlaceRepository implements PlaceRepository {
  List<PlaceSearchResult> saved = [];
  List<PlaceSearchResult> recent = [];

  @override
  Future<List<PlaceSearchResult>> loadSavedPlaces() async => List.of(saved);

  @override
  Future<void> saveSavedPlaces(List<PlaceSearchResult> places) async {
    saved = List.of(places);
  }

  @override
  Future<void> deleteSavedPlace(String id) async {
    saved.removeWhere((p) => p.effectiveId == id);
  }

  @override
  Future<List<PlaceSearchResult>> loadRecentPlaces() async => List.of(recent);

  @override
  Future<void> saveRecentPlaces(List<PlaceSearchResult> places) async {
    recent = List.of(places);
  }

  @override
  Future<void> deleteRecentPlace(String id) async {
    recent.removeWhere((p) => p.effectiveId == id);
  }

  @override
  Future<void> clear() async {
    saved = [];
    recent = [];
  }

  @override
  Future<void> flush() async {}
}

