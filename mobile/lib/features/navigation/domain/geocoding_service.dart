import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_info.dart';
import 'place_label_builder.dart';

/// Public Nominatim server URL. Replace with dedicated Nominatim instance in production.
const String kNominatimBaseUrl = 'https://nominatim.openstreetmap.org';

/// Structured geocoding place search or reverse lookup result.
class PlaceSearchResult {
  const PlaceSearchResult({
    required this.name,
    required this.displayName,
    required this.location,
    this.category,
    this.id = '',
    this.createdAt,
    this.updatedAt,
  });

  factory PlaceSearchResult.fromJson(Map<String, dynamic> json) {
    final lat = (json['latitude'] as num?)?.toDouble() ?? 0.0;
    final lng = (json['longitude'] as num?)?.toDouble() ?? 0.0;
    final name = (json['name'] as String?) ?? '';
    final rawId = (json['id'] as String?) ?? '';
    final createdUtc = json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'] as String)?.toUtc()
        : DateTime.now().toUtc();
    final updatedUtc = json['updatedAt'] != null
        ? DateTime.tryParse(json['updatedAt'] as String)?.toUtc()
        : createdUtc;
    return PlaceSearchResult(
      id: rawId.isNotEmpty ? rawId : '${lat}_${lng}_$name',
      name: name,
      displayName: (json['displayName'] as String?) ?? name,
      location: LatLng(lat, lng),
      category: json['category'] as String?,
      createdAt: createdUtc,
      updatedAt: updatedUtc,
    );
  }

  final String id;
  final String name;
  final String displayName;
  final LatLng location;
  final String? category;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get effectiveId => id.isNotEmpty ? id : '${location.latitude}_${location.longitude}_$name';
  /// Short secondary line for result lists: the display name without its
  /// leading segment (when that segment just repeats [name]), capped at three
  /// segments. Empty when there is nothing more to show.
  String get shortAddress {
    final parts = displayName
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isNotEmpty && parts.first == name.trim()) parts.removeAt(0);
    return parts.take(3).join(', ');
  }

  DateTime get effectiveCreatedAt => createdAt ?? DateTime.utc(2026, 1, 1);
  DateTime get effectiveUpdatedAt => updatedAt ?? effectiveCreatedAt;

  PlaceSearchResult copyWith({
    String? id,
    String? name,
    String? displayName,
    LatLng? location,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PlaceSearchResult(
      id: id ?? this.id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      location: location ?? this.location,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': effectiveId,
      'name': name,
      'displayName': displayName,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'category': category,
      'createdAt': effectiveCreatedAt.toIso8601String(),
      'updatedAt': (updatedAt ?? DateTime.now().toUtc()).toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaceSearchResult &&
          runtimeType == other.runtimeType &&
          effectiveId == other.effectiveId &&
          name == other.name &&
          location.latitude == other.location.latitude &&
          location.longitude == other.location.longitude;

  @override
  int get hashCode => effectiveId.hashCode ^ name.hashCode ^ location.latitude.hashCode ^ location.longitude.hashCode;

  @override
  String toString() => 'PlaceSearchResult(id: $effectiveId, name: $name, location: $location)';
}



/// Thrown when a geocoding request could not be completed (no network,
/// timeout, non-200 status or an unreadable body).
///
/// Services throw instead of returning an empty list so the UI can tell a
/// failed search ("Couldn't search...") apart from a search with no matches.
class GeocodingException implements Exception {
  const GeocodingException(this.message);

  final String message;

  @override
  String toString() => 'GeocodingException: $message';
}

/// Thrown by a service when a newer search superseded this one before its
/// network call started. Callers should silently drop it (it is not a failure).
class GeocodingCancelledException implements Exception {
  const GeocodingCancelledException();

  @override
  String toString() => 'GeocodingCancelledException';
}

/// Abstract geocoding service contract.
abstract class GeocodingService {
  /// Forward search: query -> matching places.
  ///
  /// [near] biases (but does not restrict) results toward the rider's area.
  /// Throws [GeocodingException] on failure and [GeocodingCancelledException]
  /// when superseded by a newer search.
  Future<List<PlaceSearchResult>> search(String query, {LatLng? near});

  /// Reverse lookup: coordinates -> neighbourhood-level place label.
  ///
  /// Returns null when the lookup succeeded but produced nothing useful.
  /// Throws [GeocodingException] when the lookup itself failed.
  Future<PlaceSearchResult?> reverseGeocode(LatLng location);
}

/// Production OpenStreetMap Nominatim implementation.
/// Adheres strictly to Nominatim usage policy:
/// - Custom descriptive User-Agent
/// - Rate limited: at most one request per second, one at a time
/// - No autocomplete: callers search only on explicit submit
/// - Stale searches are cancelled before they hit the network
/// - In-memory caching of successful lookups
class NominatimGeocodingService implements GeocodingService {
  NominatimGeocodingService({
    this.baseUrl = kNominatimBaseUrl,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Identifies this app to Nominatim as its usage policy requires.
  ///
  /// The Nominatim Usage Policy (https://operations.osmfoundation.org/policies/nominatim/)
  /// strictly requires a valid HTTP User-Agent identifying the application and
  /// providing a valid, reachable email address or contact info. If an app sends
  /// a fake, blank, or generic contact, OSM sysadmins may block the requests or IP range.
  static const String userAgent =
      'CAMP-App/1.0 (contact: ${AppInfo.supportEmail})';

  /// Half-width, in degrees, of the viewbox placed around the rider (~28 km).
  static const double viewboxHalfSpanDegrees = 0.25;

  /// Reverse-geocode zoom: 17 resolves to street/neighbourhood level rather
  /// than a building or the nearest unrelated point of interest (zoom 18).
  static const int reverseZoom = 17;

  final String baseUrl;
  final http.Client _httpClient;

  final Map<String, List<PlaceSearchResult>> _searchCache = {};
  final Map<String, PlaceSearchResult> _reverseCache = {};

  DateTime? _lastRequestTime;
  Completer<void>? _activeRequestLock;

  /// Monotonic id of the latest search; older queued searches are cancelled.
  int _latestSearchToken = 0;

  /// Builds the forward-search URI: Pakistan-only, viewbox-biased (not bounded)
  /// around [near] so local names like "androon lahore" rank first.
  Uri buildSearchUri(String query, {LatLng? near}) {
    final params = <String, String>{
      'q': query,
      'format': 'json',
      'limit': '8',
      'addressdetails': '1',
      'countrycodes': 'pk',
    };
    if (near != null) {
      const d = viewboxHalfSpanDegrees;
      // Nominatim viewbox order: left(lon),top(lat),right(lon),bottom(lat).
      params['viewbox'] = [
        (near.longitude - d).toStringAsFixed(6),
        (near.latitude + d).toStringAsFixed(6),
        (near.longitude + d).toStringAsFixed(6),
        (near.latitude - d).toStringAsFixed(6),
      ].join(',');
    }
    return Uri.parse(baseUrl).replace(path: '/search', queryParameters: params);
  }

  /// Builds the reverse-lookup URI for [location] at [reverseZoom].
  Uri buildReverseUri(LatLng location) {
    return Uri.parse(baseUrl).replace(
      path: '/reverse',
      queryParameters: {
        'lat': location.latitude.toStringAsFixed(6),
        'lon': location.longitude.toStringAsFixed(6),
        'format': 'json',
        'zoom': '$reverseZoom',
        'addressdetails': '1',
      },
    );
  }

  @override
  Future<List<PlaceSearchResult>> search(String query, {LatLng? near}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    // The cache key includes the coarse rider area because it changes ranking.
    final area = near == null
        ? ''
        : '${near.latitude.toStringAsFixed(1)},${near.longitude.toStringAsFixed(1)}';
    final cacheKey = '${trimmed.toLowerCase()}|$area';
    final cached = _searchCache[cacheKey];
    if (cached != null) return cached;

    final token = ++_latestSearchToken;

    return _enqueueRequest(() async {
      // A newer search was issued while this one waited its turn: skip the
      // network call entirely.
      if (token != _latestSearchToken) {
        throw const GeocodingCancelledException();
      }
      final body = await _get(buildSearchUri(trimmed, near: near));
      if (token != _latestSearchToken) {
        throw const GeocodingCancelledException();
      }

      final List<dynamic> data;
      try {
        data = json.decode(body) as List<dynamic>;
      } catch (_) {
        throw const GeocodingException('Unreadable search response');
      }

      final results = <PlaceSearchResult>[];
      for (final item in data) {
        if (item is! Map<String, dynamic>) continue;
        final lat = double.tryParse(item['lat']?.toString() ?? '');
        final lon = double.tryParse(item['lon']?.toString() ?? '');
        if (lat == null || lon == null) continue;

        final displayName = (item['display_name'] as String?) ?? trimmed;
        // Prefer Nominatim's own (local, possibly Urdu) name; otherwise the
        // first segment of the display name.
        final rawName = (item['name'] as String?)?.trim() ?? '';
        final firstPart = displayName.split(',').first.trim();
        final name = rawName.isNotEmpty
            ? rawName
            : (firstPart.isNotEmpty ? firstPart : trimmed);

        results.add(
          PlaceSearchResult(
            name: name,
            displayName: displayName,
            location: LatLng(lat, lon),
            category: item['type'] as String?,
          ),
        );
      }

      _searchCache[cacheKey] = results;
      return results;
    });
  }

  @override
  Future<PlaceSearchResult?> reverseGeocode(LatLng location) async {
    // Cache by coordinates rounded to 3 decimal places (~110m resolution)
    final cacheKey =
        '${location.latitude.toStringAsFixed(3)},${location.longitude.toStringAsFixed(3)}';
    final cached = _reverseCache[cacheKey];
    if (cached != null) return cached.copyWith(location: location);

    return _enqueueRequest(() async {
      final body = await _get(buildReverseUri(location));

      final Map<String, dynamic> map;
      try {
        map = json.decode(body) as Map<String, dynamic>;
      } catch (_) {
        throw const GeocodingException('Unreadable reverse response');
      }

      final address = map['address'];
      final label = PlaceLabelBuilder.build(
        address is Map<String, dynamic> ? address : null,
      );
      // Nothing useful (e.g. only an unrelated POI): let the caller fall back.
      if (label == null) return null;

      final result = PlaceSearchResult(
        name: label,
        displayName: (map['display_name'] as String?) ?? label,
        location: location,
      );
      _reverseCache[cacheKey] = result;
      return result;
    });
  }

  /// Performs a GET with the policy-compliant headers and returns the body.
  /// Any transport, timeout or non-200 failure becomes a [GeocodingException].
  Future<String> _get(Uri uri) async {
    final http.Response response;
    try {
      response = await _httpClient.get(
        uri,
        headers: {'User-Agent': userAgent, 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      throw GeocodingException('Request failed: $e');
    } finally {
      // Stamp every real network attempt (even failures) for the 1 req/s gap.
      _lastRequestTime = DateTime.now();
    }
    if (response.statusCode != 200) {
      throw GeocodingException('HTTP ${response.statusCode}');
    }
    return response.body;
  }

  /// Sequential queue runner with min 1 second between network requests.
  Future<T> _enqueueRequest<T>(Future<T> Function() action) async {
    while (_activeRequestLock != null) {
      await _activeRequestLock!.future;
    }

    final lock = Completer<void>();
    _activeRequestLock = lock;

    try {
      if (_lastRequestTime != null) {
        final elapsed = DateTime.now().difference(_lastRequestTime!);
        const minGap = Duration(milliseconds: 1000);
        if (elapsed < minGap) {
          await Future<void>.delayed(minGap - elapsed);
        }
      }

      return await action();
    } finally {
      _activeRequestLock = null;
      lock.complete();
    }
  }
}
