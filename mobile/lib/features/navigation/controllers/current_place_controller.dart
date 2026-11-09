import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/data/app_repositories.dart';
import '../../../core/data/last_known_place_model.dart';
import '../../../core/data/last_known_place_repository.dart';
import '../../../core/data/place_repository.dart';
import '../../settings/controllers/settings_controller.dart';
import '../domain/geocoding_service.dart';
import '../domain/location_service.dart';
import '../domain/motion_math.dart';

/// Status of the shared place resolution lifecycle.
enum CurrentPlaceStatus {
  /// Fresh, up-to-date place label matching current coordinates.
  fresh,

  /// Background refresh currently querying geocoder while keeping previous label.
  refreshing,

  /// Location services disabled, permission denied, or phone sensor unavailable.
  unavailable,
}

/// Shared central controller owning the rider's current place label and position.
///
/// Ensures Home, Emergency SOS, and Navigation Maps all display identical,
/// honest place names without duplicate Nominatim reverse-geocode requests or
/// disruptive "Locating..." flashes on screen transitions.
class CurrentPlaceController extends ChangeNotifier {
  /// Creates a [CurrentPlaceController] with optional injected dependencies.
  CurrentPlaceController({
    LocationService? locationService,
    GeocodingService? geocodingService,
    PlaceRepository? placeRepository,
    LastKnownPlaceRepository? lastKnownPlaceRepository,
  })  : _locationService = locationService ?? const GeolocatorLocationService(),
        _geocodingService = geocodingService ?? NominatimGeocodingService(),
        _placeRepository =
            placeRepository ?? AppRepositories.instance.placeRepository,
        _lastKnownPlaceRepository = lastKnownPlaceRepository ??
            AppRepositories.instance.lastKnownPlaceRepository {
    SettingsController.instance.addLocationModeListener(
      restartPositionStreamIfActive,
    );
  }

  /// Global singleton instance across the application.
  static CurrentPlaceController instance = CurrentPlaceController();

  /// Resets or replaces the singleton instance for testing.
  static void resetWith({
    LocationService? locationService,
    GeocodingService? geocodingService,
    PlaceRepository? placeRepository,
    LastKnownPlaceRepository? lastKnownPlaceRepository,
  }) {
    try {
      instance.dispose();
    } catch (_) {}
    instance = CurrentPlaceController(
      locationService: locationService,
      geocodingService: geocodingService,
      placeRepository: placeRepository,
      lastKnownPlaceRepository: lastKnownPlaceRepository,
    );
  }

  final LocationService _locationService;
  final GeocodingService _geocodingService;
  final PlaceRepository _placeRepository;
  final LastKnownPlaceRepository _lastKnownPlaceRepository;

  /// Neutral label used when no saved name or neighbourhood label is available.
  static const String fallbackLocationLabel = 'Your location';

  /// Maximum radius in meters within which a saved place overrides area names.
  static const double savedPlaceMatchRadiusMeters = 150.0;

  /// Minimum movement in meters required to trigger an automatic reverse-geocode refresh.
  static const double minMoveMetersForRefresh = 100.0;

  /// Stale duration after which a visible screen triggers a background refresh.
  static const Duration staleDuration = Duration(minutes: 5);

  PositionData? _lastKnownPosition;
  LatLng? _lastLabelledPoint;
  String? _lastPlaceLabel;
  DateTime? _labelTime;
  CurrentPlaceStatus _status = CurrentPlaceStatus.unavailable;

  bool _isLocationServiceEnabled = false;
  bool _isPermissionGranted = false;
  bool _isLastKnownFromCache = false;

  bool _isRefreshing = false;
  int _activeLookupToken = 0;
  bool _disposed = false;

  StreamSubscription<PositionData>? _positionSub;
  List<PlaceSearchResult> _savedPlaces = [];

  // ── Getters ────────────────────────────────────────────────────────────────

  /// Last known GPS or OS position data.
  PositionData? get lastKnownPosition => _lastKnownPosition;

  /// Raw resolved place label without hints, or null if never resolved.
  String? get lastPlaceLabel => _lastPlaceLabel;

  /// Timestamp when the current place label was resolved.
  DateTime? get labelTime => _labelTime;

  /// Current resolution status (fresh, refreshing, or unavailable).
  CurrentPlaceStatus get status => _status;

  /// Whether device location services are enabled.
  bool get isLocationServiceEnabled => _isLocationServiceEnabled;

  /// Whether location permission has been granted.
  bool get isPermissionGranted => _isPermissionGranted;

  /// Whether location is completely unavailable (services disabled or permission denied).
  bool get isLocationOff => !_isLocationServiceEnabled || !_isPermissionGranted;

  /// Whether the currently displayed label is from a cold-start persistent cache.
  bool get isLastKnownFromCache => _isLastKnownFromCache;

  /// The single source of truth display label for all screens (Home, SOS, Maps).
  ///
  /// - Returns "Location off" when location services or permissions are disabled.
  /// - Returns "Locating..." ONLY on fresh cold starts with no cache before any fix.
  /// - Returns "Last known: [label]" when showing persisted cache before first fresh fix.
  /// - Returns "[label]" once fresh fix or cached in-memory label is available.
  /// - Never displays "Locating..." while refreshing an existing label.
  String get displayLabel {
    if (isLocationOff) {
      return 'Location off';
    }
    if (_lastPlaceLabel == null) {
      return 'Locating...';
    }
    if (_isLastKnownFromCache) {
      return 'Last known: $_lastPlaceLabel';
    }
    return _lastPlaceLabel!;
  }

  /// Clean place name without "Last known" prefix for map cards and headings.
  String get placeLabel {
    return _lastPlaceLabel ?? fallbackLocationLabel;
  }

  // ── Lifecycle & Initialization ─────────────────────────────────────────────

  /// Initializes the controller: restores persistent cache, reads OS last-known
  /// position for instant zero-latency rendering, checks permissions, and subscribes.
  Future<void> initialize() async {
    if (_disposed) return;

    // Step 1: Load saved places for 150m matching
    try {
      _savedPlaces = await _placeRepository.loadSavedPlaces();
    } catch (_) {
      _savedPlaces = [];
    }

    // Step 2: Restore persisted place snapshot for instant cold-start label
    try {
      final cached = await _lastKnownPlaceRepository
          .loadLastKnownPlace()
          .catchError((_) => null);
      if (cached != null && cached.label.trim().isNotEmpty) {
        _lastPlaceLabel = cached.label.trim();
        _labelTime = cached.timestamp;
        _lastLabelledPoint = LatLng(cached.latitude, cached.longitude);
        _lastKnownPosition = PositionData(
          latitude: cached.latitude,
          longitude: cached.longitude,
          heading: 0,
          speed: 0,
          accuracy: 0,
          timestamp: cached.timestamp,
        );
        _isLastKnownFromCache = true;
        _status = CurrentPlaceStatus.fresh;
        notifyListeners();
      }
    } catch (_) {}

    // Step 3: Check permission and location service status
    await checkPermissionAndStart();
  }

  /// Checks whether location service is enabled and permission is granted.
  /// Starts GPS position stream when allowed.
  Future<void> checkPermissionAndStart() async {
    if (_disposed) return;

    try {
      _isLocationServiceEnabled =
          await _locationService.isLocationServiceEnabled();
      _isPermissionGranted = await _locationService.checkPermission();
    } catch (_) {
      _isLocationServiceEnabled = false;
      _isPermissionGranted = false;
    }

    if (!_isLocationServiceEnabled || !_isPermissionGranted) {
      _status = CurrentPlaceStatus.unavailable;
      notifyListeners();
      return;
    }

    // OS last-known position provides immediate coordinates if available
    try {
      final osLast = await _locationService.getLastKnownPosition();
      if (osLast != null && _lastKnownPosition == null) {
        _lastKnownPosition = osLast;
        // If we don't have a label yet, check if there's a saved place near osLast
        final savedName = _findSavedPlaceNear(osLast.toLatLng());
        if (savedName != null) {
          _lastPlaceLabel = savedName;
          _lastLabelledPoint = osLast.toLatLng();
          _labelTime = DateTime.now();
          _isLastKnownFromCache = false;
          _status = CurrentPlaceStatus.fresh;
        }
      }
    } catch (_) {}

    // Start stream to receive ongoing fixes
    _startPositionStream();

    // Perform initial fix lookup if we don't have any label yet
    if (_lastPlaceLabel == null) {
      await _fetchInitialFix();
    } else {
      notifyListeners();
    }
  }

  Future<void> _fetchInitialFix() async {
    try {
      final pos = await _locationService.getCurrentPosition();
      if (pos != null && !_disposed) {
        await updatePosition(pos, isFreshFix: true);
      }
    } catch (_) {}
  }

  void _startPositionStream() {
    _positionSub?.cancel();
    try {
      _positionSub = _locationService
          .getPositionStream(
            highAccuracy: false,
            forceLocationManager:
                SettingsController.instance.gpsOnlyLocationProvider,
          )
          .listen((pos) {
        updatePosition(pos, isFreshFix: true);
      }, onError: (_) {});
    } catch (_) {}
  }

  /// Restarts the active position stream when the location provider mode changes.
  void restartPositionStreamIfActive() {
    if (_disposed || _positionSub == null) return;
    _startPositionStream();
  }

  /// Informs the controller that saved places were created or modified.
  Future<void> reloadSavedPlaces() async {
    try {
      _savedPlaces = await _placeRepository.loadSavedPlaces();
      if (_lastKnownPosition != null) {
        final pos = _lastKnownPosition!.toLatLng();
        final savedName = _findSavedPlaceNear(pos);
        if (savedName != null && savedName != _lastPlaceLabel) {
          _lastPlaceLabel = savedName;
          _lastLabelledPoint = pos;
          _labelTime = DateTime.now();
          _isLastKnownFromCache = false;
          _status = CurrentPlaceStatus.fresh;
          _persistCurrentPlace();
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  // ── Position Updates & Refresh Logic ───────────────────────────────────────

  /// Processes a new position fix from the stream or callers.
  ///
  /// Evaluates the refresh rules:
  /// 1. Rider moved > 100 m from last labelled position, OR
  /// 2. Label is older than 5 minutes AND a screen using it is visible.
  Future<void> updatePosition(
    PositionData pos, {
    bool isFreshFix = false,
  }) async {
    if (_disposed) return;

    _lastKnownPosition = pos;
    _isLocationServiceEnabled = true;
    _isPermissionGranted = true;

    // Check if we should refresh the label (only on verified good fixes)
    final here = pos.toLatLng();
    final isGood = MotionMath.isGoodFix(pos);
    final shouldRefresh = isGood && _shouldRefreshLabel(here, isFreshFix);

    if (shouldRefresh) {
      await _refreshLabelFor(here, isFreshFix);
    } else {
      notifyListeners();
    }
  }

  bool _shouldRefreshLabel(LatLng here, bool isFreshFix) {
    // If no label has ever been resolved, we must resolve one
    if (_lastPlaceLabel == null || _lastLabelledPoint == null) {
      return true;
    }

    // If currently displaying cold-start persistent cache, replace with fresh fix
    if (_isLastKnownFromCache && isFreshFix) {
      return true;
    }

    // Refresh rule 1: moved more than 100 m from last labelled position
    final distance = MotionMath.distanceBetweenPoints(_lastLabelledPoint!, here);
    if (distance > minMoveMetersForRefresh) {
      return true;
    }

    // Refresh rule 2: older than 5 minutes AND a screen is visible (listening)
    if (_labelTime != null && hasListeners) {
      final age = DateTime.now().difference(_labelTime!);
      if (age >= staleDuration) {
        return true;
      }
    }

    return false;
  }

  LatLng? _pendingRefreshLocation;
  bool _pendingIsFreshFix = false;

  /// Triggers a background refresh for [location].
  ///
  /// Adheres strictly to requirements:
  /// - Keeps showing previous label while refresh runs (no "Locating..." text).
  /// - Only one request at a time.
  /// - Cancels stale lookups if a newer position fix arrives.
  Future<void> _refreshLabelFor(LatLng location, bool isFreshFix) async {
    if (_isRefreshing) {
      _pendingRefreshLocation = location;
      _pendingIsFreshFix = isFreshFix;
      return;
    }

    final token = ++_activeLookupToken;
    _isRefreshing = true;
    _status = CurrentPlaceStatus.refreshing;
    notifyListeners();

    try {
      // 1. Saved place within 150 m wins first
      final savedName = _findSavedPlaceNear(location);
      String? resolvedLabel = savedName;

      // 2. If no saved place within 150m, query reverse geocoding
      if (resolvedLabel == null) {
        final reverseResult = await _geocodingService.reverseGeocode(location);
        if (_disposed || token != _activeLookupToken) return;

        // PlaceLabelBuilder was used by GeocodingService to build name
        resolvedLabel = reverseResult?.name;
      }

      // 3. Fallback when geocoder returned null or POI-only
      resolvedLabel ??= 'Your location';

      if (_disposed || token != _activeLookupToken) return;

      _lastPlaceLabel = resolvedLabel;
      _lastLabelledPoint = location;
      _labelTime = DateTime.now();
      _isLastKnownFromCache = false;
      _status = CurrentPlaceStatus.fresh;

      _persistCurrentPlace();
      notifyListeners();
    } catch (_) {
      // On network failure, retain previous label if available, fallback to "Your location"
      if (_disposed || token != _activeLookupToken) return;
      _lastPlaceLabel ??= 'Your location';
      _status = CurrentPlaceStatus.fresh;
      notifyListeners();
    } finally {
      _isRefreshing = false;
      if (_pendingRefreshLocation != null && !_disposed) {
        final nextLoc = _pendingRefreshLocation!;
        final nextFresh = _pendingIsFreshFix;
        _pendingRefreshLocation = null;
        _pendingIsFreshFix = false;
        await _refreshLabelFor(nextLoc, nextFresh);
      }
    }
  }

  String? _findSavedPlaceNear(LatLng here) {
    PlaceSearchResult? best;
    double bestDist = double.infinity;
    for (final place in _savedPlaces) {
      final d = MotionMath.distanceBetweenPoints(here, place.location);
      if (d <= savedPlaceMatchRadiusMeters && d < bestDist) {
        best = place;
        bestDist = d;
      }
    }
    return best?.name;
  }

  void _persistCurrentPlace() {
    if (_lastPlaceLabel == null || _lastLabelledPoint == null) return;
    try {
      final now = DateTime.now().toUtc();
      final snapshot = LastKnownPlace(
        id: 'last_known_place',
        label: _lastPlaceLabel!,
        latitude: _lastLabelledPoint!.latitude,
        longitude: _lastLabelledPoint!.longitude,
        timestamp: _labelTime?.toUtc() ?? now,
        createdAt: now,
        updatedAt: now,
      );
      _lastKnownPlaceRepository.saveLastKnownPlace(snapshot).catchError((_) {});
    } catch (_) {}
  }

  // ── Location Off Hint ──────────────────────────────────────────────────────

  /// Displays the identical non-blocking hint as Maps with direct "Open Settings" shortcut.
  Future<void> showLocationOffHint(BuildContext context) async {
    final isOff = !_isLocationServiceEnabled;
    final message = isOff
        ? 'Location services are disabled on your device.'
        : 'Location permission was denied. Tap to allow.';

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: const Color(0xFF1E293B),
        action: SnackBarAction(
          label: 'Open Settings',
          textColor: const Color(0xFFF59E0B),
          onPressed: () async {
            if (isOff) {
              await _locationService.openLocationSettings();
            } else {
              await _locationService.openAppSettings();
            }
            await checkPermissionAndStart();
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    SettingsController.instance.removeLocationModeListener(
      restartPositionStreamIfActive,
    );
    _positionSub?.cancel();
    super.dispose();
  }
}
