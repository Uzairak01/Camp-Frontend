import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Supported Points of Interest categories.
enum PoiType {
  mechanic,
  fuel,
  restStop,
}

/// Normalized map POI marker.
class PoiMarker {
  const PoiMarker({
    required this.id,
    required this.name,
    required this.type,
    required this.location,
    this.subtitle,
    this.phone,
    this.rating,
  });

  final String id;
  final String name;
  final PoiType type;
  final LatLng location;
  final String? subtitle;
  final String? phone;
  final double? rating;

  @override
  String toString() => 'PoiMarker(name: $name, type: $type, loc: $location)';
}

/// Public Overpass API endpoint for OSM POI querying.
const String kOverpassBaseUrl = 'https://overpass-api.de/api/interpreter';

/// Service responsible for fetching Nearby Mechanics, Fuel stations, and Rest Stops.
class PlacesPoiService {
  PlacesPoiService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  final Map<String, List<PoiMarker>> _fuelCache = {};
  final Map<String, List<PoiMarker>> _restStopCache = {};

  /// Load mechanics from verified dataset around the given coordinates.
  List<PoiMarker> fetchNearbyMechanics(LatLng center, String centerName) {
    return const [];
  }

  /// Fetch fuel stations via OpenStreetMap Overpass API for the given center.
  Future<List<PoiMarker>> fetchFuelStations(LatLng center) async {
    final cacheKey =
        '${center.latitude.toStringAsFixed(2)},${center.longitude.toStringAsFixed(2)}';
    if (_fuelCache.containsKey(cacheKey)) {
      return _fuelCache[cacheKey]!;
    }

    final query = '''
[out:json][timeout:5];
node["amenity"="fuel"](around:20000,${center.latitude},${center.longitude});
out 10;
''';

    try {
      final uri = Uri.parse('$kOverpassBaseUrl?data=${Uri.encodeComponent(query)}');
      final response = await _httpClient.get(
        uri,
        headers: {
          'User-Agent': 'CAMP-App/1.0 (POI Search)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final elements = data['elements'] as List<dynamic>? ?? [];
        final markers = <PoiMarker>[];

        for (final el in elements) {
          final lat = (el['lat'] as num?)?.toDouble();
          final lon = (el['lon'] as num?)?.toDouble();
          if (lat == null || lon == null) continue;

          final tags = el['tags'] as Map<String, dynamic>? ?? {};
          final name = (tags['name'] as String?) ??
              (tags['brand'] as String?) ??
              'Fuel Station';

          markers.add(
            PoiMarker(
              id: 'fuel_${el['id']}',
              name: name,
              type: PoiType.fuel,
              location: LatLng(lat, lon),
              subtitle: tags['operator'] as String?,
            ),
          );
        }

        _fuelCache[cacheKey] = markers;
        return markers;
      }
    } catch (_) {}

    return const [];
  }

  /// Fetch rest stops via OpenStreetMap Overpass API for the given center.
  Future<List<PoiMarker>> fetchRestStops(LatLng center) async {
    final cacheKey =
        '${center.latitude.toStringAsFixed(2)},${center.longitude.toStringAsFixed(2)}';
    if (_restStopCache.containsKey(cacheKey)) {
      return _restStopCache[cacheKey]!;
    }

    final query = '''
[out:json][timeout:5];
(
  node["highway"="rest_area"](around:25000,${center.latitude},${center.longitude});
  node["tourism"="viewpoint"](around:25000,${center.latitude},${center.longitude});
);
out 10;
''';

    try {
      final uri = Uri.parse('$kOverpassBaseUrl?data=${Uri.encodeComponent(query)}');
      final response = await _httpClient.get(
        uri,
        headers: {
          'User-Agent': 'CAMP-App/1.0 (POI Search)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final elements = data['elements'] as List<dynamic>? ?? [];
        final markers = <PoiMarker>[];

        for (final el in elements) {
          final lat = (el['lat'] as num?)?.toDouble();
          final lon = (el['lon'] as num?)?.toDouble();
          if (lat == null || lon == null) continue;

          final tags = el['tags'] as Map<String, dynamic>? ?? {};
          final name = (tags['name'] as String?) ??
              (tags['tourism'] == 'viewpoint' ? 'Scenic Viewpoint' : 'Rest Area');

          markers.add(
            PoiMarker(
              id: 'rest_${el['id']}',
              name: name,
              type: PoiType.restStop,
              location: LatLng(lat, lon),
              subtitle: 'Rest stop & scenic overlook',
            ),
          );
        }

        _restStopCache[cacheKey] = markers;
        return markers;
      }
    } catch (_) {}

    return const [];
  }
}
