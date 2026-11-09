import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/data/app_repositories.dart';
import '../../../core/data/place_repository.dart';
import '../../garage/controllers/active_bike_controller.dart';
import '../../garage/services/fuel_tracker_service.dart';
import '../../garage/services/tracking_diagnostics.dart';
import '../../settings/controllers/settings_controller.dart';
import '../domain/geocoding_service.dart';
import '../domain/location_service.dart';
import '../domain/motion_math.dart';
import '../domain/places_poi_service.dart';
import '../domain/route_progress.dart';
import '../domain/routing_service.dart';
import 'current_place_controller.dart';

/// Navigation workflow states.
enum NavigationState {
  /// State 1: Default interactive map overview with search and POI discovery.
  idle,

  /// State 2: Route inspection and departure preview before starting guidance.
  previewing,

  /// State 3: Active turn-by-turn guidance, speed tracking and maneuver prompts.
  navigating,

  /// Reached destination waypoint.
  arrived,
}

/// Lifecycle of a submit-only place search, driving the results panel.
enum PlaceSearchStatus {
  /// No search has been submitted (or it was cleared).
  idle,

  /// A request is in flight; show a progress indicator.
  loading,

  /// Results are available in [NavigationController.searchResults].
  results,

  /// The search succeeded but matched nothing.
  empty,

  /// The search failed (offline, timeout, server error).
  failed,
}

/// Central state controller managing map interaction, route calculation,
/// GPS position tracking, step advancement, and active guidance telemetry.
class NavigationController extends ChangeNotifier {
  NavigationController({
    LocationService? locationService,
    RoutingService? routingService,
    GeocodingService? geocodingService,
    PlacesPoiService? placesPoiService,
    ActiveBikeController? bikeController,
    PlaceRepository? placeRepository,
    CurrentPlaceController? currentPlaceController,
  })  : _placeRepositoryOverride = placeRepository,
        _locationService = locationService ?? const GeolocatorLocationService(),
        _routingService = routingService ?? OsrmRoutingService(),
        _geocodingService = geocodingService ?? NominatimGeocodingService(),
        _placesPoiService = placesPoiService ?? PlacesPoiService(),
        _bikeController = bikeController ?? ActiveBikeController.instance,
        _ownsCurrentPlaceController = currentPlaceController != null ||
            locationService != null ||
            geocodingService != null ||
            placeRepository != null,
        _currentPlaceController = currentPlaceController ??
            ((locationService != null ||
                    geocodingService != null ||
                    placeRepository != null)
                ? CurrentPlaceController(
                    locationService: locationService,
                    geocodingService: geocodingService,
                    placeRepository: placeRepository,
                  )
                : CurrentPlaceController.instance) {
    _currentPlaceController.addListener(_onCurrentPlaceChanged);
    SettingsController.instance.addLocationModeListener(
      restartPositionStreamIfActive,
    );
  }

  static NavigationController instance = NavigationController();

  final LocationService _locationService;
  final RoutingService _routingService;
  final GeocodingService _geocodingService;
  final PlacesPoiService _placesPoiService;
  final ActiveBikeController _bikeController;
  final PlaceRepository? _placeRepositoryOverride;
  final CurrentPlaceController _currentPlaceController;
  final bool _ownsCurrentPlaceController;

  void _onCurrentPlaceChanged() {
    notifyListeners();
  }

  /// Saved/recent places store. Resolved lazily so tests can swap
  /// [AppRepositories] after the controller is constructed.
  PlaceRepository get _placeRepository =>
      _placeRepositoryOverride ?? AppRepositories.instance.placeRepository;

  /// A saved place within this many metres of the rider names the location card.
  static const double savedPlaceMatchRadiusMeters = 150.0;

  /// Neutral label used when no saved name or neighbourhood label is available.
  static const String fallbackLocationLabel = 'Your location';

  /// Distance in meters to the destination coordinates within which the rider is considered arrived.
  static const double arrivalThresholdMeters = 30.0;

  /// Maximum horizontal accuracy in meters for a fix to be accepted as a good fix.
  static const double maxAccuracyMeters = MotionMath.maxAccuracyMeters;

  /// Exponential moving average smoothing factor (`alpha = 0.4`) for speedometer updates.
  static const double speedSmoothingAlpha = 0.4;

  /// Minimum age in seconds for a prior good fix used in calculated-speed fallback.
  static const double minCalcSpeedIntervalSeconds = 3.0;

  /// Minimum distance in meters from a prior good fix used in calculated-speed fallback.
  static const double minCalcSpeedDistanceMeters = 15.0;

  /// Maximum plausible motorcycle speed in km/h before a candidate value is ignored.
  static const double maxPlausibleSpeedKmh = 130.0;

  /// Maximum plausible speed change in m/s per second elapsed (`5 m/s²`).
  static const double maxPlausibleAccelMps2 = 5.0;

  /// Duration in seconds to hold the last valid speed when a fix fails plausibility or has no new estimate.
  static const double speedHoldDurationSeconds = 3.0;

  /// Duration in seconds without any valid speed estimate after which [currentSpeed] becomes `null` (`"--"`).
  static const double speedExpireDurationSeconds = 8.0;

  /// Window in seconds over which good fixes moving less than accuracy prove the rider is stationary (`0`).
  static const double stationaryWindowSeconds = 5.0;

  /// Elapsed time in seconds without a good fix (`accuracy <= 30 m`) before [gpsWeak] is set to `true`.
  static const double gpsWeakThresholdSeconds = 10.0;

  /// Minimum duration in seconds across consecutive off-route fixes before rerouting.
  static const double offRouteMinDurationSeconds = 8.0;

  /// Minimum number of consecutive off-route good fixes required before rerouting.
  static const int offRouteMinConsecutiveFixes = 3;

  /// Cooldown duration in seconds between reroute attempts.
  static const double rerouteCooldownSeconds = 30.0;

  /// Minimum rider speed in m/s (`2.0 m/s`) required to pass heading bearing constraints to OSRM.
  static const double rerouteBearingMinSpeedMps = 2.0;

  /// Minimum distance in meters (`20.0 m`) required between the last two good GPS fixes
  /// to derive a reliable compass heading for reroutes.
  static const double rerouteMinFixDistanceMeters = 20.0;

  /// OSRM start waypoint bearing tolerance in degrees (`45°`).
  static const double rerouteBearingToleranceDegrees = 45.0;

  /// OSRM start waypoint snapping radius in meters (`40 m`).
  static const double rerouteStartRadiusMeters = 40.0;

  /// Relaxed OSRM start waypoint snapping radius in meters (`100 m`) used on immediate retry.
  static const double rerouteRelaxedStartRadiusMeters = 100.0;

  // ── State ──────────────────────────────────────────────────────────────────
  NavigationState _state = NavigationState.idle;
  PositionData? _latestRawPosition;
  PositionData? _latestGoodPosition;
  DateTime? _firstRawFixTime;
  DateTime? _lastGoodFixWallTime;
  bool _gpsWeak = false;

  final List<PositionData> _recentGoodFixes = [];
  double? _smoothedSpeedMps;
  double? _lastPlausibleSpeedMps;
  int? _currentSpeedKmh;
  DateTime? _lastValidSpeedTime;
  DateTime? _lastValidSpeedWallTime;
  double? _currentHeading;
  StreamSubscription<PositionData>? _positionSub;

  PlaceSearchResult? _destination;
  final List<PlaceSearchResult> _stops = [];
  String _selectedMode = 'motorcycle'; // Motorcycle is the primary profile

  RouteResult? _route;
  List<double> _routeCumulativeDistances = const [];
  List<double> _stepEndDistances = const [];
  int _currentStepIndex = 0;
  double _alongRouteDistanceMeters = 0.0;
  double _distanceToNextManeuverMeters = 0.0;
  LatLng? _snappedPosition;
  double? _snappedHeading;

  double _remainingDistanceMeters = 0.0;
  double _remainingDurationSeconds = 0.0;
  DateTime? _eta;

  bool _isMuted = false;
  bool _isScreenCentered = true;
  bool _isCalculatingRoute = false;
  String? _routeError;

  bool _permissionDenied = false;
  bool _isLocationServiceEnabled = true;
  String? _trackingWarningMessage;

  String _currentLocationSubtitle = '';

  // Forward search (submit-only) state shown under the search bar.
  PlaceSearchStatus _searchStatus = PlaceSearchStatus.idle;
  List<PlaceSearchResult> _searchResults = const [];
  int _searchGeneration = 0;

  // Off-route & reroute tracking
  int _offRouteConsecutiveFixes = 0;
  DateTime? _offRouteFirstFixTime;
  bool _isOffRoute = false;
  bool _isReroutingInFlight = false;
  DateTime? _lastRerouteAttemptTime;
  DateTime? _lastRerouteAttemptWallTime;
  bool _isRerouteFailed = false;

  // Movement progression: true once rider reaches >= 1.4 m/s (5 km/h) for >= 3 continuous seconds.
  bool _hasStartedMoving = false;
  DateTime? _movingStartTime;

  // In-memory recents and saved places
  final List<PlaceSearchResult> _recentPlaces = [];
  final List<PlaceSearchResult> _savedPlaces = [];

  // POI Markers
  List<PoiMarker> _poiMarkers = [];
  PoiType? _activePoiFilter;
  PoiMarker? _selectedPoiMarker;

  // Map layer toggle: false = Standard OSM, true = OpenTopoMap
  bool _isTopoLayer = false;

  // ── Getters ────────────────────────────────────────────────────────────────
  NavigationState get state => _state;

  /// Most recent good GPS fix (`accuracy <= 30 m`) used for the map dot, speed,
  /// turn progression, and off-route checks.
  PositionData? get latestGoodPosition => _latestGoodPosition;

  /// Alias for [latestGoodPosition] so the map dot and all consumers use good fixes only.
  PositionData? get currentPosition => _latestGoodPosition;

  /// Active compass heading in degrees (`0..360`).
  ///
  /// When navigating and snapped to the route (`crossTrack <= max(30 m, accuracy)`),
  /// returns the matched route segment's bearing; otherwise returns the GPS heading.
  double? get currentHeading =>
      (_state == NavigationState.navigating && _snappedHeading != null)
          ? _snappedHeading
          : (_currentHeading ?? _latestGoodPosition?.heading);

  /// Snapped coordinate on the active route polyline when `crossTrack <= max(30 m, accuracy)`,
  /// or `null` when not snapped.
  LatLng? get snappedPosition => _snappedPosition;

  /// Whether no good GPS fix (`accuracy <= 30 m`) has arrived for more than 10 seconds.
  bool get gpsWeak {
    if (_gpsWeak) return true;
    final refTime = _latestGoodPosition?.timestamp ?? _firstRawFixTime;
    if (refTime != null && _latestRawPosition != null) {
      if (MotionMath.elapsedSecondsBetween(
            refTime,
            _latestRawPosition!.timestamp,
          ) >
          gpsWeakThresholdSeconds) {
        return true;
      }
    }
    if (_latestGoodPosition != null &&
        _lastGoodFixWallTime != null &&
        (_lastGoodFixWallTime!.difference(_latestGoodPosition!.timestamp))
                .abs() <
            const Duration(minutes: 1)) {
      if (MotionMath.elapsedSecondsBetween(
            _latestGoodPosition!.timestamp,
            DateTime.now(),
          ) >
          gpsWeakThresholdSeconds) {
        return true;
      }
    }
    return false;
  }

  /// Whether the rider has started moving during active guidance
  /// (speed >= 1.4 m/s / 5 km/h continuously for >= 3 seconds).
  ///
  /// Splits active navigation into:
  /// - READY state (`false`, before rider moves): identical to standard preview/dock layout.
  /// - RIDING state (`true`, once moving): switches to Google-Maps-style telemetry layout.
  /// Once true, remains true for the entire navigation session (stopping at red lights does not revert).
  /// Resets to false in [startNavigation] and [stopNavigation].
  bool get hasStartedMoving => _hasStartedMoving;

  /// Flag indicating that the last reroute attempt failed (e.g. offline/no internet connection).
  /// Controls the amber "No internet" alert banner in RIDING state.
  bool get isRerouteFailed => _isRerouteFailed;

  /// Default fallback map camera center (Lahore coordinates: 31.5204, 74.3587).
  ///
  /// IMPORTANT: Used strictly for positioning the map camera when device GPS is unavailable.
  /// It must NEVER be used as the rider's location, in distance/ETA calculations, or be saved.
  static const LatLng defaultFallbackCenter = LatLng(31.5204, 74.3587);

  /// Centering coordinate for the map camera view.
  ///
  /// Uses the snapped or raw good GPS fix if available, otherwise destination if set,
  /// and falls back to [defaultFallbackCenter] strictly to position the camera overview.
  LatLng get cameraCenter =>
      userLatLng ?? _destination?.location ?? defaultFallbackCenter;

  /// Displayed map dot coordinate of the rider, or null if no good GPS fix is available.
  ///
  /// When navigating and `crossTrack <= max(30 m, accuracy)`, returns the snapped
  /// point on the route polyline; otherwise returns the raw good position.
  /// When location is off, this is null and never falls back to Lahore coordinates.
  LatLng? get userLatLng =>
      (_state == NavigationState.navigating && _snappedPosition != null)
          ? _snappedPosition
          : _latestGoodPosition?.toLatLng();

  PlaceSearchResult? get destination => _destination;
  List<PlaceSearchResult> get stops => List.unmodifiable(_stops);
  String get selectedMode => _selectedMode;
  RouteResult? get route => _route;
  int get currentStepIndex => _currentStepIndex;
  double get remainingDistanceMeters => _remainingDistanceMeters;
  double get remainingDurationSeconds => _remainingDurationSeconds;
  DateTime? get eta => _eta;

  bool get isMuted => _isMuted;
  bool get isScreenCentered => _isScreenCentered;
  bool get isCalculatingRoute => _isCalculatingRoute;
  String? get routeError => _routeError;
  bool get permissionDenied => _permissionDenied;
  bool get isLocationServiceEnabled => _isLocationServiceEnabled;

  /// Name shown on the "YOUR LOCATION" card: delegated to the shared
  /// [CurrentPlaceController] singleton for uniform place naming across all screens.
  String get currentLocationName => _currentPlaceController.placeLabel;
  String get currentLocationSubtitle => _currentLocationSubtitle;

  /// Name of the nearest saved place within [savedPlaceMatchRadiusMeters] of the
  /// rider's real GPS fix, or null (also null when there is no fix).
  String? get savedPlaceNameNearRider {
    final here = _latestGoodPosition?.toLatLng();
    if (here == null) return null;
    PlaceSearchResult? best;
    double bestDistance = double.infinity;
    for (final place in _savedPlaces) {
      final d = MotionMath.distanceBetweenPoints(here, place.location);
      if (d <= savedPlaceMatchRadiusMeters && d < bestDistance) {
        best = place;
        bestDistance = d;
      }
    }
    return best?.name;
  }

  PlaceSearchStatus get searchStatus => _searchStatus;
  List<PlaceSearchResult> get searchResults => List.unmodifiable(_searchResults);

  List<PlaceSearchResult> get recentPlaces => List.unmodifiable(_recentPlaces);
  List<PlaceSearchResult> get savedPlaces => List.unmodifiable(_savedPlaces);

  List<PoiMarker> get poiMarkers => List.unmodifiable(_poiMarkers);
  PoiType? get activePoiFilter => _activePoiFilter;
  PoiMarker? get selectedPoiMarker => _selectedPoiMarker;
  bool get isTopoLayer => _isTopoLayer;

  /// Current step in turn-by-turn guidance with live countdown distance.
  RouteStep? get currentStep {
    if (_route == null || _route!.steps.isEmpty) return null;
    final idx = _currentStepIndex.clamp(0, _route!.steps.length - 1);
    final step = _route!.steps[idx];
    if (_state == NavigationState.navigating &&
        _stepEndDistances.length == _route!.steps.length) {
      return step.copyWith(distanceMeters: _distanceToNextManeuverMeters);
    }
    return step;
  }

  /// Replaces `"Head out..."` departure phrasing with `"Continue on <road>"`
  /// (or `"Continue straight"`) for steps displayed after a reroute.
  static RouteStep _normalizeStepForReroute(RouteStep step) {
    final isDepart = step.maneuverType.toLowerCase() == 'depart';
    final startsWithHeadOut =
        step.instruction.toLowerCase().startsWith('head out');
    if (!isDepart && !startsWithHeadOut) {
      return step;
    }
    final cleanStreet = step.streetName.trim();
    final newInstruction = cleanStreet.isNotEmpty
        ? 'Continue on $cleanStreet'
        : 'Continue straight';
    return step.copyWith(
      maneuverType: isDepart ? 'continue' : step.maneuverType,
      instruction: newInstruction,
    );
  }

  /// Next step after current for previewing turn progression.
  RouteStep? get nextStep {
    if (_route == null || _route!.steps.isEmpty) return null;
    final nextIndex = _currentStepIndex + 1;
    if (nextIndex < _route!.steps.length) {
      return _route!.steps[nextIndex];
    }
    return null;
  }

  /// Current filtered, smoothed speed in km/h, or `null` when no trustworthy
  /// speed estimate is available (rendered as `"--"` by [formattedSpeed]).
  ///
  /// Pipeline (Batch S4-3c-1):
  /// (a) Uses reported speed when `> 0` on a good fix (`accuracy <= 30 m`).
  /// (b) Otherwise computes speed from good fixes only (`distance / seconds`
  ///     against the most recent good fix at least 3 s older and 15 m away).
  /// (c) Smooths valid estimates with an exponential moving average (`alpha = 0.4`).
  /// (d) Rejects implausible candidates (`> 130 km/h` or acceleration `> 5 m/s²`),
  ///     retaining the last valid speed for up to 3 seconds before dropping it.
  /// (e) Exposes `null` (`"--"`) when no valid estimate has arrived for 8 seconds,
  ///     except returns `0` when recent good fixes prove the rider is stationary
  ///     (moved less than the current fix's horizontal accuracy over >= 5 seconds).
  int? get currentSpeed {
    final latestGood = _latestGoodPosition;
    final speedKmh = _currentSpeedKmh;
    final validSpeedTime = _lastValidSpeedTime;
    if (latestGood == null || speedKmh == null || validSpeedTime == null) {
      return null;
    }

    final refFixTime = _latestRawPosition?.timestamp ?? latestGood.timestamp;
    var ageSeconds =
        MotionMath.elapsedSecondsBetween(validSpeedTime, refFixTime);

    final wallTime = _lastValidSpeedWallTime;
    if (wallTime != null &&
        wallTime.difference(validSpeedTime).inSeconds.abs() < 60) {
      final wallAge =
          MotionMath.elapsedSecondsBetween(wallTime, DateTime.now());
      if (wallAge > ageSeconds) {
        ageSeconds = wallAge;
      }
    }

    // (e) If no valid estimate has arrived for 8 seconds, expose null ("--").
    if (ageSeconds >= speedExpireDurationSeconds) {
      return null;
    }

    return speedKmh;
  }

  /// Formatted speed text for the speedometer badge (`"--"` when [currentSpeed] is `null`).
  String get formattedSpeed => currentSpeed?.toString() ?? '--';

  /// Speed unit label ('KM / H').
  String get speedUnitLabel => 'KM / H';

  /// Distance unit label.
  String get distanceUnitLabel => 'km';

  /// Formatted remaining distance string (e.g. "5.4 km").
  String get formattedRemainingDistance {
    final km = _remainingDistanceMeters / 1000.0;
    return '${km.toStringAsFixed(1)} km';
  }

  /// Formatted remaining duration string (e.g. "11 min").
  String get formattedRemainingDuration {
    final minutes = (_remainingDurationSeconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remMins = minutes % 60;
    return remMins > 0 ? '${hours}h ${remMins}m' : '${hours}h';
  }

  /// Formatted ETA string (e.g. "09:52") in the phone's local time.
  String get formattedEta {
    final time = _eta ?? DateTime.now().add(Duration(seconds: _remainingDurationSeconds.round()));
    final localTime = time.toLocal();
    final hour = localTime.hour.toString().padLeft(2, '0');
    final minute = localTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Fuel consumption estimate based on route distance and active motorcycle spec.
  /// Returns null if activeBike has no fuelAverageKmPerLiter.
  String? get fuelEstimateDisplay {
    if (_route == null) return null;
    final activeBike = _bikeController.activeBike;
    final kmPerL = activeBike?.fuelAverageKmPerLiter;
    if (kmPerL == null || kmPerL <= 0) return null;

    final distanceKm = _route!.distanceKm;
    final liters = distanceKm / kmPerL;
    return '${liters.toStringAsFixed(2)} L';
  }

  /// Google Maps deep-link URL for opening navigation externally in two-wheeler mode.
  static String buildGoogleMapsUrl(LatLng destination) {
    return 'https://www.google.com/maps/dir/?api=1&destination=${destination.latitude.toStringAsFixed(6)},${destination.longitude.toStringAsFixed(6)}&travelmode=two-wheeler';
  }

  /// Deep-link URL pointing to destination, last route point, or current camera view center.
  String get googleMapsUrl {
    final dest = _destination?.location ??
        (_route?.polyline.isNotEmpty == true ? _route!.polyline.last : cameraCenter);
    return buildGoogleMapsUrl(dest);
  }

  bool _disposed = false;

  /// Whether the controller has been disposed.
  bool get isDisposed => _disposed;

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  // ── Initialization & Lifecycle ─────────────────────────────────────────────

  Future<void> initialize() async {
    if (_state == NavigationState.navigating) {
      return;
    }
    await checkLocationPermissionAndStart();
    if (_disposed) return;
    await loadPlaces();
    if (_disposed) return;
    await _currentPlaceController.initialize();
  }

  /// Loads saved and recent places from [PlaceRepository] into memory.
  /// Failures are logged and leave the in-memory lists untouched so the map
  /// stays usable.
  Future<void> loadPlaces() async {
    try {
      final saved = await _placeRepository.loadSavedPlaces();
      final recent = await _placeRepository.loadRecentPlaces();
      if (_disposed) return;
      _savedPlaces
        ..clear()
        ..addAll(saved);
      _recentPlaces
        ..clear()
        ..addAll(recent);
      notifyListeners();
    } catch (e) {
      debugPrint('NavigationController.loadPlaces failed: $e');
    }
  }

  /// Writes the in-memory saved/recent lists through [PlaceRepository].
  /// Best-effort: a storage error is logged, never thrown into the UI.
  Future<void> _persistPlaces() async {
    try {
      await _placeRepository.saveSavedPlaces(List.of(_savedPlaces));
      await _placeRepository.saveRecentPlaces(List.of(_recentPlaces));
    } catch (e) {
      debugPrint('NavigationController._persistPlaces failed: $e');
    }
  }

  /// Checks whether location services are enabled on device and verifies permissions.
  /// When location is off, updates state non-blockingly without triggering blocking dialogues.
  Future<void> checkLocationPermissionAndStart() async {
    final serviceEnabled = await _locationService.isLocationServiceEnabled();
    if (_disposed) return;
    _isLocationServiceEnabled = serviceEnabled;
    if (!serviceEnabled) {
      _currentLocationSubtitle = 'Location off';
      notifyListeners();
      // Early exit if device location is disabled: present non-blocking hint
      // rather than requesting permissions or showing blocking dialogues.
      return;
    }

    final hasPerm = await _locationService.checkPermission();
    if (_disposed) return;
    if (!hasPerm) {
      final granted = await _locationService.requestPermission();
      if (_disposed) return;
      _permissionDenied = !granted;
      if (!granted) {
        _currentLocationSubtitle = 'Location permission denied';
        notifyListeners();
        return;
      }
    }

    _permissionDenied = false;
    _currentLocationSubtitle = 'GPS Ready';
    notifyListeners();

    // Fetch single current position fix
    final initialPos = await _locationService.getCurrentPosition();
    if (_disposed) return;
    if (initialPos != null) {
      _latestRawPosition = initialPos;
      _firstRawFixTime ??= initialPos.timestamp;
      if (MotionMath.isGoodFix(initialPos)) {
        _latestGoodPosition = initialPos;
        _lastGoodFixWallTime = DateTime.now();
        _currentHeading = initialPos.heading;
      }
      notifyListeners();
    }

    startPositionStream();
  }

  void startPositionStream() {
    _positionSub?.cancel();
    final isNav = _state == NavigationState.navigating;
    _positionSub = _locationService
        .getPositionStream(
          highAccuracy: isNav,
          forceLocationManager:
              SettingsController.instance.gpsOnlyLocationProvider,
        )
        .listen(_handlePositionUpdate);
  }

  /// Restarts the active navigation GPS stream when the location provider mode changes.
  void restartPositionStreamIfActive() {
    if (_disposed || _positionSub == null) return;
    startPositionStream();
  }

  void stopPositionStream() {
    _positionSub?.cancel();
    _positionSub = null;
  }

  void _handlePositionUpdate(PositionData pos) {
    _latestRawPosition = pos;
    _firstRawFixTime ??= pos.timestamp;

    // Gate: only fixes with accuracy <= 30 m update the map dot, speed, turn progress, and off-route checks.
    if (!MotionMath.isGoodFix(pos)) {
      final refTime = _latestGoodPosition?.timestamp ?? _firstRawFixTime!;
      if (MotionMath.elapsedSecondsBetween(refTime, pos.timestamp) >
          gpsWeakThresholdSeconds) {
        _gpsWeak = true;
      }
      if (_lastValidSpeedTime != null &&
          MotionMath.elapsedSecondsBetween(_lastValidSpeedTime!, pos.timestamp) >=
              speedExpireDurationSeconds) {
        _smoothedSpeedMps = null;
        _lastPlausibleSpeedMps = null;
        _currentSpeedKmh = null;
      }
      _updateMovingState(pos.timestamp);
      notifyListeners();
      return;
    }

    final wasGoodPositionNull = _latestGoodPosition == null;
    _latestGoodPosition = pos;
    _lastGoodFixWallTime = DateTime.now();
    _gpsWeak = false;

    _updateSpeedFromGoodFix(pos);
    _updateMovingState(pos.timestamp);

    if (pos.heading != null && pos.heading! >= 0) {
      _currentHeading = pos.heading;
    }

    if (_state == NavigationState.navigating && _route != null) {
      _processNavigationStepProgression(pos);
    } else if (_state == NavigationState.previewing &&
        _destination != null &&
        (_route == null || wasGoodPositionNull) &&
        !_isCalculatingRoute) {
      calculateRoute();
    }

    notifyListeners();
    // Keep the shared current place controller in step with the rider's good movement.
    _currentPlaceController.updatePosition(pos);
  }

  /// Updates the filtered, smoothed speedometer state from a verified good fix (`accuracy <= 30 m`).
  void _updateSpeedFromGoodFix(PositionData pos) {
    final double? dtSinceLastValid = _lastValidSpeedTime != null
        ? MotionMath.elapsedSecondsBetween(_lastValidSpeedTime!, pos.timestamp)
        : null;

    if (dtSinceLastValid != null &&
        dtSinceLastValid >= speedExpireDurationSeconds) {
      _smoothedSpeedMps = null;
      _lastPlausibleSpeedMps = null;
      _currentSpeedKmh = null;
    }

    double? candidateMps;

    // (a) Reported speed if > 0 on a good fix
    if (pos.speed != null && pos.speed! > 0) {
      candidateMps = pos.speed!;
    }

    // (e) Stationary detection: moved less than the accuracy over >= 5 s of good fixes
    if (candidateMps == null && _isProvenStationary(pos)) {
      _smoothedSpeedMps = null;
      _lastPlausibleSpeedMps = null;
      _currentSpeedKmh = 0;
      _lastValidSpeedTime = pos.timestamp;
      _lastValidSpeedWallTime = DateTime.now();
      _appendGoodFix(pos);
      return;
    }

    // (b) Otherwise calculate from good fixes only: most recent good fix >= 3 s older and >= 15 m away
    if (candidateMps == null) {
      for (int i = _recentGoodFixes.length - 1; i >= 0; i--) {
        final prev = _recentGoodFixes[i];
        if (_lastValidSpeedTime != null &&
            prev.timestamp.isBefore(_lastValidSpeedTime!)) {
          break;
        }
        final dt = MotionMath.elapsedSeconds(prev, pos);
        final dist = MotionMath.distanceMeters(prev, pos);
        if (dt >= minCalcSpeedIntervalSeconds &&
            dist >= minCalcSpeedDistanceMeters) {
          candidateMps = dist / dt;
          break;
        }
      }
    }

    if (candidateMps != null) {
      // (d) Plausibility check: reject > 130 km/h or > 5 m/s change per second elapsed
      final bool exceedsMaxKmh = (candidateMps * 3.6) > maxPlausibleSpeedKmh;
      final bool exceedsMaxAccel = _lastPlausibleSpeedMps != null &&
          dtSinceLastValid != null &&
          dtSinceLastValid > 0 &&
          ((candidateMps - _lastPlausibleSpeedMps!).abs() / dtSinceLastValid) >
              maxPlausibleAccelMps2;

      if (exceedsMaxKmh || exceedsMaxAccel) {
        // Ignore implausible spike; keep the last value for up to 3 s, then drop it
        if (dtSinceLastValid == null ||
            dtSinceLastValid > speedHoldDurationSeconds) {
          _smoothedSpeedMps = null;
          _lastPlausibleSpeedMps = null;
          _currentSpeedKmh = null;
        }
      } else {
        // (c) Smooth with exponential moving average (alpha = 0.4)
        if (_smoothedSpeedMps == null) {
          _smoothedSpeedMps = candidateMps;
        } else {
          _smoothedSpeedMps = (speedSmoothingAlpha * candidateMps) +
              ((1.0 - speedSmoothingAlpha) * _smoothedSpeedMps!);
        }
        _lastPlausibleSpeedMps = candidateMps;
        _currentSpeedKmh = (_smoothedSpeedMps! * 3.6).round();
        _lastValidSpeedTime = pos.timestamp;
        _lastValidSpeedWallTime = DateTime.now();
      }
    } else {
      // No new valid estimate on this fix: keep last value for up to 3 s, then drop it
      if (dtSinceLastValid == null ||
          dtSinceLastValid > speedHoldDurationSeconds) {
        _smoothedSpeedMps = null;
        _lastPlausibleSpeedMps = null;
        _currentSpeedKmh = null;
      }
    }

    _appendGoodFix(pos);
  }

  /// Checks whether the recent good fixes prove the rider is stationary
  /// (moved less than [pos]'s accuracy over at least 5 seconds).
  bool _isProvenStationary(PositionData pos) {
    if (_recentGoodFixes.isEmpty) return false;
    final effectiveAccuracy = pos.accuracy ?? maxAccuracyMeters;
    int? refIndex;
    for (int i = _recentGoodFixes.length - 1; i >= 0; i--) {
      final dt = MotionMath.elapsedSeconds(_recentGoodFixes[i], pos);
      if (dt >= stationaryWindowSeconds) {
        refIndex = i;
        break;
      }
    }
    if (refIndex == null) return false;

    for (int i = refIndex; i < _recentGoodFixes.length; i++) {
      final dist = MotionMath.distanceMeters(_recentGoodFixes[i], pos);
      if (dist >= effectiveAccuracy) {
        return false;
      }
    }
    return true;
  }

  void _appendGoodFix(PositionData pos) {
    _recentGoodFixes.add(pos);
    while (_recentGoodFixes.length > 50) {
      _recentGoodFixes.removeAt(0);
    }
  }

  /// Evaluates whether the rider has started moving during active guidance.
  ///
  /// Flips [hasStartedMoving] to true once [currentSpeed] is >= 1.4 m/s (5 km/h)
  /// continuously for at least 3 seconds. A null speed ("--") or any lower value
  /// resets the 3-second timer. Once true, it remains true for that navigation
  /// session (stopping at red lights must NOT switch back).
  void _updateMovingState(DateTime timestamp) {
    if (_hasStartedMoving) return;
    final speed = currentSpeed;
    if (speed != null && speed >= 5) {
      if (_movingStartTime == null) {
        _movingStartTime = timestamp;
      } else {
        final elapsed =
            MotionMath.elapsedSecondsBetween(_movingStartTime!, timestamp);
        if (elapsed >= 3.0) {
          _hasStartedMoving = true;
        }
      }
    } else {
      _movingStartTime = null;
    }
  }

  // ── Navigation Engine Logic ────────────────────────────────────────────────

  void _initializeRouteMetrics(
    RouteResult route, {
    double initialAlongMeters = 0.0,
    int initialStepIndex = 0,
    DateTime? referenceTime,
  }) {
    _routeCumulativeDistances =
        RouteProgress.computeCumulativeDistances(route.polyline);
    _stepEndDistances = RouteProgress.computeStepEndDistances(
      polyline: route.polyline,
      cumulativeDistances: _routeCumulativeDistances,
      steps: route.steps,
    );
    _alongRouteDistanceMeters = initialAlongMeters;
    _currentStepIndex = route.steps.isEmpty
        ? 0
        : initialStepIndex.clamp(0, route.steps.length - 1);
    if (_stepEndDistances.isNotEmpty) {
      _distanceToNextManeuverMeters = math.max(
        0.0,
        _stepEndDistances[_currentStepIndex] - _alongRouteDistanceMeters,
      );
    } else if (route.steps.isNotEmpty) {
      _distanceToNextManeuverMeters =
          route.steps[_currentStepIndex].distanceMeters;
    } else {
      _distanceToNextManeuverMeters = 0.0;
    }
    _updateRemainingDistanceAndEtaFromProgress(referenceTime: referenceTime);
  }

  void _processNavigationStepProgression(PositionData pos) {
    if (_route == null || _route!.steps.isEmpty) return;

    final userLoc = pos.toLatLng();

    // 1. Check Arrival at Destination (within ~30m)
    final destLoc = _route!.polyline.isNotEmpty
        ? _route!.polyline.last
        : (_destination?.location ?? userLoc);
    final distanceToDest = MotionMath.distanceBetweenPoints(userLoc, destLoc);
    if (distanceToDest <= arrivalThresholdMeters) {
      _transitionToArrived();
      return;
    }

    // 2. Snap good fix onto route polyline with monotonic progress
    final snap = RouteProgress.snapToRoute(
      polyline: _route!.polyline,
      cumulativeDistances: _routeCumulativeDistances,
      point: userLoc,
      lastAlongRouteMeters: _alongRouteDistanceMeters,
    );

    final accuracy = pos.accuracy ?? 0.0;
    final snapThreshold =
        math.max(RouteProgress.minSnapCrossTrackMeters, accuracy);
    final offRouteThreshold =
        math.max(RouteProgress.minOffRouteCrossTrackMeters, 2.0 * accuracy);

    if (snap.crossTrackMeters <= snapThreshold) {
      _snappedPosition = snap.snappedPoint;
      _snappedHeading = snap.segmentBearingDegrees;
    } else {
      _snappedPosition = null;
      _snappedHeading = null;
    }

    // Advance along-route progress monotonically when not off-route
    if (snap.crossTrackMeters <= offRouteThreshold) {
      _alongRouteDistanceMeters = snap.alongRouteMeters;
    }

    // 3. Advance currentStepIndex when distance to next maneuver < 15 m or progress passes step end
    if (_stepEndDistances.length == _route!.steps.length) {
      final targetIndex = RouteProgress.findStepIndexAtAlongDistance(
        stepEndDistances: _stepEndDistances,
        alongRouteMeters: _alongRouteDistanceMeters,
      );
      if (targetIndex > _currentStepIndex) {
        _currentStepIndex = targetIndex;
      }
      _distanceToNextManeuverMeters = math.max(
        0.0,
        _stepEndDistances[_currentStepIndex] - _alongRouteDistanceMeters,
      );
    }

    // 4. Update remaining distance and ETA from along-route progress (not step lengths)
    _updateRemainingDistanceAndEtaFromProgress(referenceTime: pos.timestamp);

    // 5. Off-route check: cross-track > max(40 m, 2 * accuracy) on >= 3 consecutive good fixes spanning >= 8 s
    if (snap.crossTrackMeters > offRouteThreshold) {
      _offRouteFirstFixTime ??= pos.timestamp;
      _offRouteConsecutiveFixes++;
      final offRouteSpanSeconds = MotionMath.elapsedSecondsBetween(
        _offRouteFirstFixTime!,
        pos.timestamp,
      );

      if (_offRouteConsecutiveFixes >= offRouteMinConsecutiveFixes &&
          offRouteSpanSeconds >= offRouteMinDurationSeconds) {
        if (!_isOffRoute) {
          _isOffRoute = true;
          TrackingDiagnostics.instance.recordOffRouteStateChange(
            timestamp: pos.timestamp,
            isOffRoute: true,
            crossTrackMeters: snap.crossTrackMeters,
            accuracy: pos.accuracy,
            reason:
                'Off-route confirmed ($_offRouteConsecutiveFixes consecutive fixes over ${offRouteSpanSeconds.toStringAsFixed(1)}s, cross-track ${snap.crossTrackMeters.toStringAsFixed(1)}m > ${offRouteThreshold.toStringAsFixed(1)}m)',
          );
        }
        unawaited(_checkAndTriggerReroute(pos, snap.crossTrackMeters));
      }
    } else {
      if (_isOffRoute) {
        _isOffRoute = false;
        TrackingDiagnostics.instance.recordOffRouteStateChange(
          timestamp: pos.timestamp,
          isOffRoute: false,
          crossTrackMeters: snap.crossTrackMeters,
          accuracy: pos.accuracy,
          reason:
              'Returned on-route (cross-track ${snap.crossTrackMeters.toStringAsFixed(1)}m <= ${offRouteThreshold.toStringAsFixed(1)}m)',
        );
      }
      _offRouteConsecutiveFixes = 0;
      _offRouteFirstFixTime = null;
    }
  }

  void _updateRemainingDistanceAndEtaFromProgress({DateTime? referenceTime}) {
    if (_route == null) return;
    final totalPolyMeters = _routeCumulativeDistances.isNotEmpty
        ? _routeCumulativeDistances.last
        : 0.0;
    final totalRouteMeters =
        _route!.distanceMeters > 0 ? _route!.distanceMeters : totalPolyMeters;

    _remainingDistanceMeters =
        math.max(0.0, totalRouteMeters - _alongRouteDistanceMeters);

    if (totalRouteMeters > 0 && _route!.durationSeconds > 0) {
      final remainingFraction =
          (_remainingDistanceMeters / totalRouteMeters).clamp(0.0, 1.0);
      _remainingDurationSeconds = _route!.durationSeconds * remainingFraction;
    } else {
      _remainingDurationSeconds = 0.0;
    }

    final baseTime = referenceTime ?? DateTime.now();
    _eta = baseTime.add(Duration(seconds: _remainingDurationSeconds.round()));
  }

  Future<void> _checkAndTriggerReroute(
    PositionData pos,
    double crossTrackMeters,
  ) async {
    if (_isReroutingInFlight || _destination == null) return;

    // Enforce 30-second cooldown between reroute attempts
    if (_lastRerouteAttemptTime != null) {
      var elapsedSinceAttempt = MotionMath.elapsedSecondsBetween(
        _lastRerouteAttemptTime!,
        pos.timestamp,
      );
      if (elapsedSinceAttempt <= 0 && _lastRerouteAttemptWallTime != null) {
        elapsedSinceAttempt = MotionMath.elapsedSecondsBetween(
          _lastRerouteAttemptWallTime!,
          DateTime.now(),
        );
      }
      if (elapsedSinceAttempt < rerouteCooldownSeconds) {
        return;
      }
    }

    _isReroutingInFlight = true;
    _lastRerouteAttemptTime = pos.timestamp;
    _lastRerouteAttemptWallTime = DateTime.now();

    final currentLoc = pos.toLatLng();
    final speedMps = _smoothedSpeedMps ??
        ((pos.speed != null && pos.speed! > 0) ? pos.speed! : 0.0);

    // Derive reroute heading strictly from the last two good GPS fixes (accuracy <= 30 m)
    // that are at least 20 m apart. The phone never reports a reliable heading (often 0.0),
    // so we never use raw phone heading or a fake 0.0 fallback.
    PositionData? prevGoodFix;
    for (int i = _recentGoodFixes.length - 1; i >= 0; i--) {
      final candidateFix = _recentGoodFixes[i];
      if (identical(candidateFix, pos) ||
          candidateFix.timestamp.isAfter(pos.timestamp)) {
        continue;
      }
      if (!MotionMath.isGoodAccuracy(candidateFix.accuracy)) continue;
      final dist = MotionMath.distanceMeters(candidateFix, pos);
      if (dist >= rerouteMinFixDistanceMeters) {
        prevGoodFix = candidateFix;
        break;
      }
    }

    // Treat heading as unreliable if speed is under 2 m/s or no two good fixes >= 20 m apart exist.
    final double? rerouteHeading =
        (speedMps >= rerouteBearingMinSpeedMps && prevGoodFix != null)
            ? RouteProgress.bearingDegrees(prevGoodFix.toLatLng(), currentLoc)
            : null;
    final String headingSource =
        rerouteHeading != null ? 'from last good fixes' : 'none';

    // When unreliable: send NO bearing to OSRM (use radius only).
    final double? startBearing = rerouteHeading;
    final String attempt1Constraints = startBearing != null
        ? 'bearings=${startBearing.round()},${rerouteBearingToleranceDegrees.round()}, radiuses=${rerouteStartRadiusMeters.round()}m'
        : 'bearings=none, radiuses=${rerouteStartRadiusMeters.round()}m';
    final String attempt2Constraints =
        'bearings=none, radiuses=${rerouteRelaxedStartRadiusMeters.round()}m';

    try {
      final waypoints = [
        currentLoc,
        ..._stops.map((s) => s.location),
        _destination!.location,
      ];

      RouteResult? newRoute;
      String activeAttemptLabel = 'Attempt 1 ($attempt1Constraints)';
      String? attempt1FailureReason;

      // Attempt 1: Constrained reroute (bearings + 40 m radius)
      try {
        final candidate = await _routingService.getRoute(
          waypoints: waypoints,
          requestAlternatives: false,
          startBearingDegrees: startBearing,
          startBearingToleranceDegrees: rerouteBearingToleranceDegrees,
          startRadiusMeters: rerouteStartRadiusMeters,
        );
        if (_disposed) return;
        if (candidate.polyline.isEmpty || candidate.steps.isEmpty) {
          attempt1FailureReason = 'empty route returned';
        } else {
          newRoute = candidate;
        }
      } catch (e) {
        if (_disposed) return;
        attempt1FailureReason = e.toString().replaceAll('Exception: ', '');
      }

      // If Attempt 1 failed (NoSegment, empty route, or error), log it and retry ONCE
      // immediately with relaxed constraints (radiuses 100 m, no bearings).
      if (newRoute == null) {
        final fixAfterAttempt1 = _latestGoodPosition ?? pos;
        TrackingDiagnostics.instance.recordReroute(
          timestamp: fixAfterAttempt1.timestamp,
          crossTrackMeters: crossTrackMeters,
          accuracy: fixAfterAttempt1.accuracy,
          accepted: false,
          reason:
              'Attempt 1 ($attempt1Constraints) failed ($attempt1FailureReason); retrying with relaxed constraints ($attempt2Constraints)',
          heading: rerouteHeading,
          headingSource: headingSource,
        );

        activeAttemptLabel = 'Attempt 2 ($attempt2Constraints)';
        try {
          final retryCandidate = await _routingService.getRoute(
            waypoints: waypoints,
            requestAlternatives: false,
            startBearingDegrees: null,
            startRadiusMeters: rerouteRelaxedStartRadiusMeters,
          );
          if (_disposed) return;
          if (retryCandidate.polyline.isEmpty || retryCandidate.steps.isEmpty) {
            final latestFix = _latestGoodPosition ?? pos;
            _isRerouteFailed = true;
            notifyListeners();
            TrackingDiagnostics.instance.recordReroute(
              timestamp: latestFix.timestamp,
              crossTrackMeters: crossTrackMeters,
              accuracy: latestFix.accuracy,
              accepted: false,
              reason:
                  '$activeAttemptLabel discarded: routing service returned an empty route',
              heading: rerouteHeading,
              headingSource: headingSource,
            );
            return;
          }
          newRoute = retryCandidate;
        } catch (retryError) {
          if (_disposed) return;
          final latestFix = _latestGoodPosition ?? pos;
          _isRerouteFailed = true;
          notifyListeners();
          TrackingDiagnostics.instance.recordReroute(
            timestamp: latestFix.timestamp,
            crossTrackMeters: crossTrackMeters,
            accuracy: latestFix.accuracy,
            accepted: false,
            reason:
                '$activeAttemptLabel failed: ${retryError.toString().replaceAll('Exception: ', '')}',
            heading: rerouteHeading,
            headingSource: headingSource,
          );
          return;
        }
      }

      final latestFix = _latestGoodPosition ?? pos;
      final latestLoc = latestFix.toLatLng();

      // Snap the rider onto the new route and trim leading points so it starts at the snapped point
      final rawCumDist =
          RouteProgress.computeCumulativeDistances(newRoute.polyline);
      final rawSnap = RouteProgress.snapToRoute(
        polyline: newRoute.polyline,
        cumulativeDistances: rawCumDist,
        point: latestLoc,
        searchEntirePolyline: true,
      );
      final trimmedPolyline =
          RouteProgress.trimPolylineFromSnap(newRoute.polyline, rawSnap);

      // When heading is reliable, check if the first 150 m of the trimmed route
      // points > 120° away from the rider's heading (hook / U-turn spur).
      // When heading is unreliable, SKIP the hook check completely.
      if (rerouteHeading != null) {
        final hookAngle = RouteProgress.detectHookRouteAngleDegrees(
          polyline: trimmedPolyline,
          riderHeadingDegrees: rerouteHeading,
          checkDistanceMeters: 150.0,
          maxAngleDiffDegrees: 120.0,
        );
        if (hookAngle != null) {
          TrackingDiagnostics.instance.recordReroute(
            timestamp: latestFix.timestamp,
            crossTrackMeters: crossTrackMeters,
            accuracy: latestFix.accuracy,
            accepted: false,
            reason:
                '$activeAttemptLabel Hook/U-turn spur discarded: first 150 m deviates by ${hookAngle.toStringAsFixed(1)} deg (> 120 deg) from heading ${rerouteHeading.toStringAsFixed(1)} deg',
            heading: rerouteHeading,
            headingSource: headingSource,
          );
          return;
        }
      }

      // Normalize steps so post-reroute banner shows "Continue on <road>" or maneuver, never "Head out"
      final normalizedSteps = newRoute.steps
          .map(_normalizeStepForReroute)
          .toList(growable: false);

      // Determine starting step index from snapping onto the new route (not hardcoded 0)
      final rawStepEnds = RouteProgress.computeStepEndDistances(
        polyline: newRoute.polyline,
        cumulativeDistances: rawCumDist,
        steps: normalizedSteps,
      );
      final snappedStepIndex = RouteProgress.findStepIndexAtAlongDistance(
        stepEndDistances: rawStepEnds,
        alongRouteMeters: rawSnap.alongRouteMeters,
      );

      final trimmedCumDist =
          RouteProgress.computeCumulativeDistances(trimmedPolyline);
      final trimmedTotalMeters = trimmedCumDist.isNotEmpty
          ? trimmedCumDist.last
          : math.max(0.0, newRoute.distanceMeters - rawSnap.alongRouteMeters);
      final durationScale = newRoute.distanceMeters > 0
          ? (trimmedTotalMeters / newRoute.distanceMeters).clamp(0.0, 1.0)
          : 1.0;

      final acceptedRoute = newRoute.copyWith(
        polyline: trimmedPolyline,
        distanceMeters: trimmedTotalMeters,
        durationSeconds: newRoute.durationSeconds * durationScale,
        steps: normalizedSteps,
      );

      _isRerouteFailed = false;
      _route = acceptedRoute;
      _initializeRouteMetrics(
        acceptedRoute,
        initialAlongMeters: 0.0,
        initialStepIndex: snappedStepIndex,
        referenceTime: latestFix.timestamp,
      );

      final snapThreshold = math.max(
        RouteProgress.minSnapCrossTrackMeters,
        latestFix.accuracy ?? 0.0,
      );
      if (rawSnap.crossTrackMeters <= snapThreshold) {
        _snappedPosition = rawSnap.snappedPoint;
        _snappedHeading = rawSnap.segmentBearingDegrees;
      } else {
        _snappedPosition = null;
        _snappedHeading = null;
      }

      _isOffRoute = false;
      _offRouteConsecutiveFixes = 0;
      _offRouteFirstFixTime = null;

      TrackingDiagnostics.instance.recordReroute(
        timestamp: latestFix.timestamp,
        crossTrackMeters: crossTrackMeters,
        accuracy: latestFix.accuracy,
        accepted: true,
        reason:
            '$activeAttemptLabel Reroute accepted (trimmed to ${trimmedTotalMeters.toStringAsFixed(0)} m, starting at step $snappedStepIndex)',
        heading: rerouteHeading,
        headingSource: headingSource,
      );
      notifyListeners();
    } finally {
      _isReroutingInFlight = false;
    }
  }

  void _transitionToArrived() {
    _state = NavigationState.arrived;
    _disableWakelock();
    startPositionStream(); // Return to standard accuracy
    notifyListeners();
  }

  // ── Actions & State Transitions ────────────────────────────────────────────

  /// State 1 -> State 2: Prepare preview with given destination.
  Future<void> openRoutePreview(PlaceSearchResult destinationPlace) async {
    _destination = destinationPlace;
    _addRecentPlace(destinationPlace);
    _routeError = null;
    _state = NavigationState.previewing;
    notifyListeners();

    if (_latestGoodPosition == null) {
      try {
        final pos = await _locationService.getCurrentPosition();
        if (pos != null && !_disposed) {
          _latestRawPosition = pos;
          _firstRawFixTime ??= pos.timestamp;
          if (MotionMath.isGoodFix(pos)) {
            _latestGoodPosition = pos;
            _lastGoodFixWallTime = DateTime.now();
            _currentHeading = pos.heading;
          }
        }
      } catch (_) {}
    }

    await calculateRoute();
  }

  /// Recalculates route between current position, stops, and destination.
  /// When device location is off (_latestGoodPosition == null), distance and ETA
  /// cannot be computed and are NEVER calculated from the Lahore fallback center.
  Future<void> calculateRoute() async {
    if (_destination == null) return;

    // Strict safety check: fallback center must never be used as rider origin or in ETA/distance.
    if (_latestGoodPosition == null) {
      _isCalculatingRoute = false;
      _route = null;
      _remainingDistanceMeters = 0.0;
      _remainingDurationSeconds = 0.0;
      _eta = null;
      _routeError = 'Location unavailable. Turn on GPS to calculate route.';
      notifyListeners();
      return;
    }

    _isCalculatingRoute = true;
    _routeError = null;
    notifyListeners();

    try {
      final waypoints = [
        _latestGoodPosition!.toLatLng(),
        ..._stops.map((s) => s.location),
        _destination!.location,
      ];

      final res = await _routingService.getRoute(
        waypoints: waypoints,
        requestAlternatives: true,
      );
      if (_disposed) return;

      _route = res;
      _snappedPosition = null;
      _snappedHeading = null;
      _initializeRouteMetrics(
        res,
        initialAlongMeters: 0.0,
        initialStepIndex: 0,
      );
      _isCalculatingRoute = false;
      notifyListeners();
    } catch (e) {
      if (_disposed) return;
      _isCalculatingRoute = false;
      _routeError = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  /// Non-blocking warning message if ride tracking could not start when navigating.
  String? get trackingWarningMessage => _trackingWarningMessage;

  /// Dismisses any active tracking warning message.
  void clearTrackingWarning() {
    _trackingWarningMessage = null;
    notifyListeners();
  }

  /// State 2 -> State 3: Enter active guidance.
  /// Also starts live ride tracking via [FuelTrackerService] if no ride is running.
  Future<void> startNavigation() async {
    if (_route == null) return;
    _state = NavigationState.navigating;
    _hasStartedMoving = false;
    _movingStartTime = null;
    _isRerouteFailed = false;
    _offRouteConsecutiveFixes = 0;
    _offRouteFirstFixTime = null;
    _isOffRoute = false;
    _isReroutingInFlight = false;
    _lastRerouteAttemptTime = null;
    _lastRerouteAttemptWallTime = null;
    _initializeRouteMetrics(
      _route!,
      initialAlongMeters: 0.0,
      initialStepIndex: 0,
      referenceTime: _latestGoodPosition?.timestamp,
    );
    if (_latestGoodPosition != null && _route!.polyline.isNotEmpty) {
      final snap = RouteProgress.snapToRoute(
        polyline: _route!.polyline,
        cumulativeDistances: _routeCumulativeDistances,
        point: _latestGoodPosition!.toLatLng(),
        lastAlongRouteMeters: 0.0,
      );
      final snapThreshold = math.max(
        RouteProgress.minSnapCrossTrackMeters,
        _latestGoodPosition!.accuracy ?? 0.0,
      );
      if (snap.crossTrackMeters <= snapThreshold) {
        _snappedPosition = snap.snappedPoint;
        _snappedHeading = snap.segmentBearingDegrees;
        _alongRouteDistanceMeters = snap.alongRouteMeters;
        if (_stepEndDistances.isNotEmpty) {
          _distanceToNextManeuverMeters = math.max(
            0.0,
            _stepEndDistances[_currentStepIndex] - _alongRouteDistanceMeters,
          );
        }
      }
    }
    _isScreenCentered = true;
    _enableWakelock();
    startPositionStream(); // High accuracy
    notifyListeners();

    // Couple ride tracking with navigation
    final destinationTitle = _destination?.name;
    if (!FuelTrackerService.instance.isRiding) {
      final started = await FuelTrackerService.instance.startRide(
        routeTitle: destinationTitle,
      );
      if (!started && FuelTrackerService.instance.locationErrorMessage != null) {
        _trackingWarningMessage =
            FuelTrackerService.instance.locationErrorMessage;
        notifyListeners();
      }
    } else if (destinationTitle != null &&
        (FuelTrackerService.instance.routeTitle == null ||
            FuelTrackerService.instance.routeTitle!.isEmpty)) {
      FuelTrackerService.instance.setRouteTitle(destinationTitle);
    }
  }

  /// State 3 -> State 1: Exit navigation guidance.
  void stopNavigation() {
    _state = NavigationState.idle;
    _hasStartedMoving = false;
    _movingStartTime = null;
    _isRerouteFailed = false;
    _route = null;
    _routeCumulativeDistances = const [];
    _stepEndDistances = const [];
    _destination = null;
    _stops.clear();
    _currentStepIndex = 0;
    _alongRouteDistanceMeters = 0.0;
    _distanceToNextManeuverMeters = 0.0;
    _snappedPosition = null;
    _snappedHeading = null;
    _offRouteConsecutiveFixes = 0;
    _offRouteFirstFixTime = null;
    _isOffRoute = false;
    _isReroutingInFlight = false;
    _lastRerouteAttemptTime = null;
    _lastRerouteAttemptWallTime = null;
    _recentGoodFixes.clear();
    _smoothedSpeedMps = null;
    _lastPlausibleSpeedMps = null;
    _currentSpeedKmh = null;
    _lastValidSpeedTime = null;
    _lastValidSpeedWallTime = null;
    _disableWakelock();
    startPositionStream(); // Medium accuracy
    notifyListeners();
  }

  /// State 2 -> State 1: Back to default map view.
  void cancelRoutePreview() {
    _state = NavigationState.idle;
    _hasStartedMoving = false;
    _movingStartTime = null;
    _isRerouteFailed = false;
    _route = null;
    _destination = null;
    _stops.clear();
    notifyListeners();
  }

  /// Close the "You have arrived" sheet and reset to default map.
  void dismissArrived() {
    stopNavigation();
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    notifyListeners();
  }

  void recenterMap() {
    _isScreenCentered = true;
    notifyListeners();
  }

  void markUserPanned() {
    if (_isScreenCentered) {
      _isScreenCentered = false;
      notifyListeners();
    }
  }

  void toggleTopoLayer() {
    _isTopoLayer = !_isTopoLayer;
    notifyListeners();
  }

  void setMode(String mode) {
    if (_selectedMode == mode) return;
    _selectedMode = mode;
    calculateRoute();
  }

  /// Swaps start and destination endpoints.
  /// Only allowed when a real GPS fix is available; never swaps using the fallback center.
  void swapStartAndDestination() {
    if (_destination == null || _latestGoodPosition == null) return;
    // Swap start and destination endpoints using real rider GPS fix
    _destination = PlaceSearchResult(
      name: currentLocationName,
      displayName: _currentLocationSubtitle.isNotEmpty
          ? _currentLocationSubtitle
          : currentLocationName,
      location: _latestGoodPosition!.toLatLng(),
    );
    calculateRoute();
  }

  void addStop(PlaceSearchResult stop) {
    if (_stops.length < 2) {
      _stops.add(stop);
      calculateRoute();
    }
  }

  void removeStop(int index) {
    if (index >= 0 && index < _stops.length) {
      _stops.removeAt(index);
      calculateRoute();
    }
  }

  void toggleSavedPlace(PlaceSearchResult place) {
    final idx = _savedPlaces.indexWhere((p) => p.name == place.name);
    if (idx >= 0) {
      _savedPlaces.removeAt(idx);
    } else {
      _savedPlaces.add(place);
    }
    notifyListeners();
    unawaited(_persistPlaces());
  }

  /// Saves the rider's current GPS position under [name] (e.g. "Home") via
  /// [PlaceRepository]. A saved place already within
  /// [savedPlaceMatchRadiusMeters] is renamed instead of duplicated, so
  /// renaming the same spot twice keeps one entry. No-op without a GPS fix or
  /// with a blank name; returns whether a place was saved.
  Future<bool> saveCurrentLocationAs(String name) async {
    final trimmed = name.trim();
    final here = _latestGoodPosition?.toLatLng();
    if (trimmed.isEmpty || here == null) return false;

    final place = PlaceSearchResult(
      name: trimmed,
      // Keep the neighbourhood label as the address line under the name.
      displayName: _currentPlaceController.lastPlaceLabel ?? trimmed,
      location: here,
      category: 'saved',
    );

    final existing = _savedPlaces.indexWhere(
      (p) =>
          MotionMath.distanceBetweenPoints(here, p.location) <=
          savedPlaceMatchRadiusMeters,
    );
    if (existing >= 0) {
      // Reuse the id so the repository updates the record in place.
      _savedPlaces[existing] = place.copyWith(id: _savedPlaces[existing].id);
    } else {
      _savedPlaces.add(place);
    }
    notifyListeners();
    await _persistPlaces();
    await _currentPlaceController.reloadSavedPlaces();
    return true;
  }

  bool isPlaceSaved(PlaceSearchResult place) {
    return _savedPlaces.any((p) => p.name == place.name);
  }

  // ── POI Markers ────────────────────────────────────────────────────────────

  /// Toggles display of POI markers for the given [type].
  /// Does not fetch POIs if GPS fix is unavailable.
  Future<void> togglePoiFilter(PoiType type) async {
    if (_activePoiFilter == type) {
      _activePoiFilter = null;
      _poiMarkers = [];
      _selectedPoiMarker = null;
      notifyListeners();
      return;
    }

    _activePoiFilter = type;
    _selectedPoiMarker = null;
    notifyListeners();

    if (_latestGoodPosition == null) {
      _poiMarkers = [];
      notifyListeners();
      return;
    }

    final pos = _latestGoodPosition!.toLatLng();
    switch (type) {
      case PoiType.mechanic:
        _poiMarkers = _placesPoiService.fetchNearbyMechanics(
          pos,
          currentLocationName,
        );
        break;
      case PoiType.fuel:
        _poiMarkers = await _placesPoiService.fetchFuelStations(pos);
        break;
      case PoiType.restStop:
        _poiMarkers = await _placesPoiService.fetchRestStops(pos);
        break;
    }
    notifyListeners();
  }

  void selectPoiMarker(PoiMarker marker) {
    _selectedPoiMarker = marker;
    notifyListeners();
  }

  void clearSelectedPoiMarker() {
    _selectedPoiMarker = null;
    notifyListeners();
  }

  // ── Geocoding ──────────────────────────────────────────────────────────────

  /// Runs a forward place search for [query]. Called only when the rider
  /// submits (keyboard search key or search icon) - never while typing, per the
  /// Nominatim policy. A newer submit supersedes any older one: the older
  /// response is dropped so stale results can never overwrite fresh ones.
  /// Every outcome (results, empty, failure) is surfaced through [searchStatus].
  Future<void> submitSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final generation = ++_searchGeneration;
    _searchStatus = PlaceSearchStatus.loading;
    _searchResults = const [];
    notifyListeners();

    try {
      final results = await _geocodingService.search(trimmed, near: userLatLng);
      if (_disposed || generation != _searchGeneration) return;
      _searchResults = results;
      _searchStatus =
          results.isEmpty ? PlaceSearchStatus.empty : PlaceSearchStatus.results;
    } on GeocodingCancelledException {
      // A newer search owns the UI state now.
      return;
    } catch (e) {
      if (_disposed || generation != _searchGeneration) return;
      debugPrint('NavigationController.submitSearch failed: $e');
      _searchResults = const [];
      _searchStatus = PlaceSearchStatus.failed;
    }
    notifyListeners();
  }

  /// Clears search results and invalidates any in-flight search.
  void clearSearch() {
    _searchGeneration++;
    if (_searchStatus == PlaceSearchStatus.idle && _searchResults.isEmpty) {
      return;
    }
    _searchStatus = PlaceSearchStatus.idle;
    _searchResults = const [];
    notifyListeners();
  }

  // ── Wakelock Management ────────────────────────────────────────────────────

  void _enableWakelock() {
    try {
      WakelockPlus.enable().catchError((_) {});
    } catch (_) {}
  }

  void _disableWakelock() {
    try {
      WakelockPlus.disable().catchError((_) {});
    } catch (_) {}
  }

  void _addRecentPlace(PlaceSearchResult place) {
    _recentPlaces.removeWhere((p) => p.name == place.name);
    _recentPlaces.insert(0, place);
    if (_recentPlaces.length > 5) {
      _recentPlaces.removeLast();
    }
    // Recent searches persist through PlaceRepository.
    unawaited(_persistPlaces());
  }

  @override
  void dispose() {
    _disposed = true;
    SettingsController.instance.removeLocationModeListener(
      restartPositionStreamIfActive,
    );
    _currentPlaceController.removeListener(_onCurrentPlaceChanged);
    if (_ownsCurrentPlaceController) {
      _currentPlaceController.dispose();
    }
    _positionSub?.cancel();
    _positionSub = null;
    _disableWakelock();
    super.dispose();
  }
}
