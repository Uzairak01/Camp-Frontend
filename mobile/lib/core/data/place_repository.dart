import '../../features/navigation/domain/geocoding_service.dart';

abstract class PlaceRepository {
  Future<List<PlaceSearchResult>> loadSavedPlaces();
  Future<void> saveSavedPlaces(List<PlaceSearchResult> places);
  Future<void> deleteSavedPlace(String id);
  Future<List<PlaceSearchResult>> loadRecentPlaces();
  Future<void> saveRecentPlaces(List<PlaceSearchResult> places);
  Future<void> deleteRecentPlace(String id);
  Future<void> clear();
  Future<void> flush();
}
