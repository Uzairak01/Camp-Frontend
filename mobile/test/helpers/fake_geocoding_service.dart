import 'package:camp/features/navigation/domain/geocoding_service.dart';
import 'package:latlong2/latlong.dart';

/// Fake implementation of [GeocodingService] for testing.
///
/// Records every call so tests can assert when (and with what bias) the
/// controller hits the geocoder, and can be told to fail or stall.
class FakeGeocodingService implements GeocodingService {
  FakeGeocodingService({
    this.searchResults,
    this.reverseResult,
    this.searchError,
    this.reverseError,
    this.reverseEmpty = false,
  });

  /// When true, [reverseGeocode] returns null (nothing useful found).
  bool reverseEmpty;

  List<PlaceSearchResult>? searchResults;
  PlaceSearchResult? reverseResult;

  /// When set, [search] throws this instead of returning results.
  Object? searchError;

  /// When set, [reverseGeocode] throws this instead of returning a result.
  Object? reverseError;

  /// Queries received by [search], in order.
  final List<String> searchQueries = [];

  /// `near` biases received by [search], in order.
  final List<LatLng?> searchNears = [];

  /// Number of [reverseGeocode] calls.
  int reverseCalls = 0;

  @override
  Future<List<PlaceSearchResult>> search(String query, {LatLng? near}) async {
    searchQueries.add(query);
    searchNears.add(near);
    if (searchError != null) throw searchError!;
    if (searchResults != null) return searchResults!;
    return [
      PlaceSearchResult(
        name: query,
        displayName: '$query, Test Region',
        location: const LatLng(35.0, 74.0),
      ),
    ];
  }

  @override
  Future<PlaceSearchResult?> reverseGeocode(LatLng location) async {
    reverseCalls++;
    if (reverseError != null) throw reverseError!;
    // "Lookup succeeded but nothing useful" (e.g. only an unrelated POI).
    if (reverseEmpty) return null;
    return reverseResult ??
        PlaceSearchResult(
          name: 'Current location',
          displayName: 'Current location, Mountain Pass',
          location: location,
        );
  }
}
