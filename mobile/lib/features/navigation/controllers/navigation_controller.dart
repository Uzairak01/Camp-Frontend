import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/data/app_repositories.dart';
import '../../../core/data/place_repository.dart';
import '../../garage/controllers/active_bike_controller.dart';
import '../../garage/services/fuel_tracker_service.dart';
import '../domain/geocoding_service.dart';
import '../domain/location_service.dart';
import '../domain/places_poi_service.dart';
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

  static const Distance _distanceCalc = Distance();

  /// A saved place within this many metres of the rider names the location card.
  static const double savedPlaceMatchRadiusMeters = 150.0;

  /// Neutral label used when no saved name or neighbourhood label is available.
  static const String fallbackLocationLabel = 'Your location';

  // ── State ──────────────────────────────────────────────────────────────────
  NavigationState _state = NavigationState.idle;
  PositionData? _currentPosition;
  PositionData? _previousPosition;
  int _lastGoodSpeedKmh = 0;
  DateTime? _lastGoodSpeedTime;
  double? _currentHeading;
  StreamSubscription<PositionData>? _positionSub;

  PlaceSearchResult? _destination;
  final List<PlaceSearchResult> _stops = [];
  String _selectedMode = 'motorcycle'; // Motorcycle is the primary profile

  RouteResult? _route;
  int _currentStepIndex = 0;
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

  // Off-route tracking
  int _offRouteConsecutiveFixes = 0;
  DateTime? _lastRerouteTime;

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
  PositionData? get currentPosition => _currentPosition;
  double? get currentHeading => _currentHeading ?? _currentPosition?.heading;

  /// Default fallback map camera center (Lahore coordinates: 31.5204, 74.3587).
  ///
  /// IMPORTANT: Used strictly for positioning the map camera when device GPS is unavailable.
  /// It must NEVER be used as the rider's location, in distance/ETA calculations, or be saved.
  static const LatLng defaultFallbackCenter = LatLng(31.5204, 74.3587);

  /// Centering coordinate for the map camera view.
  ///
  /// Uses active GPS fix if available, otherwise destination if set, and falls back
  /// to [defaultFallbackCenter] strictly to position the camera overview.
  LatLng get cameraCenter =>
      _currentPosition?.toLatLng() ?? _destination?.location ?? defaultFallbackCenter;

  /// Real GPS coordinates of the rider, or null if GPS fix is unavailable.
  ///
  /// When location is off, this is null and never falls back to Lahore coordinates.
  LatLng? get userLatLng => _currentPosition?.toLatLng();

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
    final here = _currentPosition?.toLatLng();
    if (here == null) return null;
    PlaceSearchResult? best;
    double bestDistance = double.infinity;
    for (final place in _savedPlaces) {
      final d = _distanceCalc.as(LengthUnit.Meter, here, place.location);
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

  /// Current step in turn-by-turn guidance.
  RouteStep? get currentStep {
    if (_route == null || _route!.steps.isEmpty) return null;
    if (_currentStepIndex >= _route!.steps.length) {
      return _route!.steps.last;
    }
    return _route!.steps[_currentStepIndex];
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

  /// Previous GPS fix stored for speed fallback calculation when the device
  /// omits or reports 0 for speed.
  PositionData? get previousPosition => _previousPosition;

  /// Current speed in km/h.
  ///
  /// Uses the GPS-reported speed when positive. When the reported speed is null
  /// or `<= 0`, falls back to `distance(previous fix, current fix) / dt` if the
  /// time gap is between 1 and 10 seconds (inclusive) and the distance moved is
  /// at least the current fix's horizontal accuracy. Retains the last good
  /// positive speed for up to 3 seconds to prevent display flicker; otherwise
  /// returns 0.
  int get currentSpeed {
    final pos = _currentPosition;
    if (pos == null) return 0;

    final computed = _computeFixSpeedKmh(pos, _previousPosition);
    if (computed != null && computed > 0) {
      return computed;
    }

    // Hold the last good value for up to 3 seconds to prevent speedometer flicker
    if (_lastGoodSpeedKmh > 0 && _lastGoodSpeedTime != null) {
      final elapsedMs =
          pos.timestamp.difference(_lastGoodSpeedTime!).inMilliseconds;
      if (elapsedMs >= 0 && elapsedMs <= 3000) {
        return _lastGoodSpeedKmh;
      }
    }

    return 0;
  }

  /// Evaluates speed in km/h for [current] using reported speed or distance/time
  /// fallback from [previous]. Returns null if neither yields a valid moving speed.
  int? _computeFixSpeedKmh(PositionData current, PositionData? previous) {
    final rawSpeedMs = current.speed;
    if (rawSpeedMs != null && rawSpeedMs > 0) {
      return (rawSpeedMs * 3.6).round();
    }

    if (previous == null) return null;

    final dtSeconds =
        current.timestamp.difference(previous.timestamp).inMilliseconds /
            1000.0;
    if (dtSeconds < 1.0 || dtSeconds > 10.0) {
      return null;
    }

    final distMeters = _distanceCalc.as(
      LengthUnit.Meter,
      previous.toLatLng(),
      current.toLatLng(),
    );
    final minRequiredAccuracy = current.accuracy ?? 0.0;
    if (distMeters <= 0 || distMeters < minRequiredAccuracy) {
      return null;
    }

    final calcSpeedMs = distMeters / dtSeconds;
    return (calcSpeedMs * 3.6).round();
  }

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

  /// Formatted ETA string (e.g. "09:52").
  String get formattedEta {
    final time = _eta ?? DateTime.now().add(Duration(seconds: _remainingDurationSeconds.round()));
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
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
      _currentPosition = initialPos;
      _currentHeading = initialPos.heading;
      notifyListeners();
    }

    startPositionStream();
  }

  void startPositionStream() {
    _positionSub?.cancel();
    final isNav = _state == NavigationState.navigating;
    _positionSub = _locationService
        .getPositionStream(highAccuracy: isNav)
        .listen(_handlePositionUpdate);
  }

  void stopPositionStream() {
    _positionSub?.cancel();
    _positionSub = null;
  }

  void _handlePositionUpdate(PositionData pos) {
    final wasPositionNull = _currentPosition == null;
    _previousPosition = _currentPosition;
    _currentPosition = pos;

    // Update last good speed cache when this fix produces a positive speed.
    // A negative GPS speed is an invalid reading rather than a momentary
    // stationary fix, so it must not leave a stale value on the speedometer.
    final fixSpeedKmh = _computeFixSpeedKmh(pos, _previousPosition);
    if (fixSpeedKmh != null && fixSpeedKmh > 0) {
      _lastGoodSpeedKmh = fixSpeedKmh;
      _lastGoodSpeedTime = pos.timestamp;
    } else if (pos.speed != null && pos.speed! < 0) {
      _lastGoodSpeedKmh = 0;
      _lastGoodSpeedTime = null;
    }

    if (pos.heading != null && pos.heading! >= 0) {
      _currentHeading = pos.heading;
    }

    if (_state == NavigationState.navigating && _route != null) {
      _processNavigationStepProgression(pos);
    } else if (_state == NavigationState.previewing &&
        _destination != null &&
        (_route == null || wasPositionNull) &&
        !_isCalculatingRoute) {
      calculateRoute();
    }

    notifyListeners();
    // Keep the shared current place controller in step with the rider's movement.
    _currentPlaceController.updatePosition(pos);
  }

  // ── Navigation Engine Logic ────────────────────────────────────────────────

  void _processNavigationStepProgression(PositionData pos) {
    if (_route == null || _route!.steps.isEmpty) return;

    final userLoc = pos.toLatLng();

    // 1. Check Arrival at Destination (within ~30m)
    final destLoc = _route!.polyline.isNotEmpty ? _route!.polyline.last : (_destination?.location ?? userLoc);
    final distanceToDest = _distanceCalc.as(LengthUnit.Meter, userLoc, destLoc);
    if (distanceToDest <= 30.0) {
      _transitionToArrived();
      return;
    }

    // 2. Advance Step when within ~30m of the next maneuver point
    if (_currentStepIndex < _route!.steps.length - 1) {
      final nextManeuver = _route!.steps[_currentStepIndex + 1];
      final distToManeuver =
          _distanceCalc.as(LengthUnit.Meter, userLoc, nextManeuver.location);

      if (distToManeuver <= 30.0) {
        _currentStepIndex++;
      }
    }

    // 3. Update remaining metrics along polyline
    _updateRemainingDistanceAndEta(userLoc);

    // 4. Off-Route Check (>50m away from polyline for multiple consecutive fixes)
    final distToPolyline = _distanceToPolyline(userLoc, _route!.polyline);
    if (distToPolyline > 50.0) {
      _offRouteConsecutiveFixes++;
      if (_offRouteConsecutiveFixes >= 3) {
        _checkAndTriggerReroute(userLoc);
      }
    } else {
      _offRouteConsecutiveFixes = 0;
    }
  }

  void _updateRemainingDistanceAndEta(LatLng userLoc) {
    if (_route == null || _route!.polyline.isEmpty) return;

    // Sum remaining polyline distance from closest point forward
    final poly = _route!.polyline;
    int closestIdx = 0;
    double minD = double.infinity;
    for (int i = 0; i < poly.length; i++) {
      final d = _distanceCalc.as(LengthUnit.Meter, userLoc, poly[i]);
      if (d < minD) {
        minD = d;
        closestIdx = i;
      }
    }

    double remDist = 0.0;
    for (int i = closestIdx; i < poly.length - 1; i++) {
      remDist += _distanceCalc.as(LengthUnit.Meter, poly[i], poly[i + 1]);
    }

    _remainingDistanceMeters = remDist;
    // Estimate remaining seconds based on route average speed
    if (_route!.distanceMeters > 0) {
      final avgSpeed = _route!.distanceMeters / math.max(1.0, _route!.durationSeconds);
      _remainingDurationSeconds = remDist / math.max(1.0, avgSpeed);
    }
    _eta = DateTime.now().add(Duration(seconds: _remainingDurationSeconds.round()));
  }

  /// Calculates shortest perpendicular distance in meters from [point] to [polyline].
  static double calculateDistanceToPolyline(LatLng point, List<LatLng> polyline) {
    if (polyline.isEmpty) return double.infinity;
    if (polyline.length == 1) {
      return _distanceCalc.as(LengthUnit.Meter, point, polyline.first);
    }

    double minDistance = double.infinity;
    for (int i = 0; i < polyline.length - 1; i++) {
      final d = _distanceToSegmentMeters(point, polyline[i], polyline[i + 1]);
      if (d < minDistance) {
        minDistance = d;
      }
    }
    return minDistance;
  }

  double _distanceToPolyline(LatLng point, List<LatLng> polyline) {
    return calculateDistanceToPolyline(point, polyline);
  }

  static double _distanceToSegmentMeters(LatLng p, LatLng a, LatLng b) {
    // Project p onto line segment ab using equirectangular projection
    final latP = p.latitudeInRad;
    final lonP = p.longitudeInRad;
    final latA = a.latitudeInRad;
    final lonA = a.longitudeInRad;
    final latB = b.latitudeInRad;
    final lonB = b.longitudeInRad;

    final cosMeanLat = math.cos((latA + latB) / 2);
    final dx = (lonB - lonA) * cosMeanLat;
    final dy = latB - latA;
    final segLenSq = dx * dx + dy * dy;

    if (segLenSq == 0) {
      return _distanceCalc.as(LengthUnit.Meter, p, a);
    }

    final px = (lonP - lonA) * cosMeanLat;
    final py = latP - latA;
    final t = math.max(0.0, math.min(1.0, (px * dx + py * dy) / segLenSq));

    final projLat = latA + t * (latB - latA);
    final projLon = lonA + t * (lonB - lonA);

    return _distanceCalc.as(
      LengthUnit.Meter,
      p,
      LatLng(projLat * (180 / math.pi), projLon * (180 / math.pi)),
    );
  }

  Future<void> _checkAndTriggerReroute(LatLng currentLoc) async {
    final now = DateTime.now();
    if (_lastRerouteTime != null && now.difference(_lastRerouteTime!).inSeconds < 10) {
      return; // Throttled to once every 10s
    }

    _lastRerouteTime = now;
    _offRouteConsecutiveFixes = 0;

    if (_destination == null) return;

    try {
      final waypoints = [currentLoc, ..._stops.map((s) => s.location), _destination!.location];
      final newRoute = await _routingService.getRoute(
        waypoints: waypoints,
        requestAlternatives: false,
      );
      if (_disposed) return;

      // Only replace route and reset step index when a valid new route is actually received.
      if (newRoute.polyline.isEmpty || newRoute.steps.isEmpty) {
        return;
      }

      _route = newRoute;
      _currentStepIndex = 0;
      _remainingDistanceMeters = newRoute.distanceMeters;
      _remainingDurationSeconds = newRoute.durationSeconds;
      _eta = DateTime.now().add(Duration(seconds: newRoute.durationSeconds.round()));
      notifyListeners();
    } catch (_) {
      // Retain existing route, polyline, and _currentStepIndex unchanged if re-routing fails.
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

    if (_currentPosition == null) {
      try {
        final pos = await _locationService.getCurrentPosition();
        if (pos != null && !_disposed) {
          _currentPosition = pos;
          _currentHeading = pos.heading;
        }
      } catch (_) {}
    }

    await calculateRoute();
  }

  /// Recalculates route between current position, stops, and destination.
  /// When device location is off (_currentPosition == null), distance and ETA
  /// cannot be computed and are NEVER calculated from the Lahore fallback center.
  Future<void> calculateRoute() async {
    if (_destination == null) return;

    // Strict safety check: fallback center must never be used as rider origin or in ETA/distance.
    if (_currentPosition == null) {
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
        _currentPosition!.toLatLng(),
        ..._stops.map((s) => s.location),
        _destination!.location,
      ];

      final res = await _routingService.getRoute(
        waypoints: waypoints,
        requestAlternatives: true,
      );
      if (_disposed) return;

      _route = res;
      _remainingDistanceMeters = res.distanceMeters;
      _remainingDurationSeconds = res.durationSeconds;
      _currentStepIndex = 0;
      _eta = DateTime.now().add(Duration(seconds: res.durationSeconds.round()));
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
    _currentStepIndex = 0;
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
    _route = null;
    _destination = null;
    _stops.clear();
    _currentStepIndex = 0;
    _lastGoodSpeedKmh = 0;
    _lastGoodSpeedTime = null;
    _disableWakelock();
    startPositionStream(); // Medium accuracy
    notifyListeners();
  }

  /// State 2 -> State 1: Back to default map view.
  void cancelRoutePreview() {
    _state = NavigationState.idle;
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
    if (_destination == null || _currentPosition == null) return;
    // Swap start and destination endpoints using real rider GPS fix
    _destination = PlaceSearchResult(
      name: currentLocationName,
      displayName: _currentLocationSubtitle.isNotEmpty
          ? _currentLocationSubtitle
          : currentLocationName,
      location: _currentPosition!.toLatLng(),
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
    final here = _currentPosition?.toLatLng();
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
          _distanceCalc.as(LengthUnit.Meter, here, p.location) <=
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

    if (_currentPosition == null) {
      _poiMarkers = [];
      notifyListeners();
      return;
    }

    final pos = _currentPosition!.toLatLng();
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
