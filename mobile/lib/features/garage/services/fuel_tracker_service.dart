import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../core/data/app_repositories.dart';
import '../../../core/data/in_progress_ride_model.dart';
import '../../../core/data/in_progress_ride_repository.dart';
import '../../maintenance/controllers/post_ride_report_controller.dart';
import '../../maintenance/domain/post_ride_report.dart';
import '../../navigation/domain/location_service.dart';
import '../../navigation/domain/motion_math.dart';
import '../../settings/controllers/settings_controller.dart';
import '../controllers/active_bike_controller.dart';
import '../domain/fuel_estimator.dart';
import 'fuel_notification_service.dart';
import 'tracking_diagnostics.dart';

/// Central singleton service tracking live motorcycle rides, accumulating distance,
/// updating the active bike's odometer and fuel estimate in real time, and alerting
/// riders on low fuel.
class FuelTrackerService extends ChangeNotifier with WidgetsBindingObserver {
  FuelTrackerService({
    LocationService? locationService,
    ActiveBikeController? bikeController,
    FuelNotificationService? notificationService,
    InProgressRideRepository? inProgressRideRepository,
  })  : _locationService = locationService ?? const GeolocatorLocationService(),
        _bikeController = bikeController ?? ActiveBikeController.instance,
        _notificationService =
            notificationService ?? FuelNotificationService(),
        _inProgressRideRepository = inProgressRideRepository ??
            AppRepositories.instance.inProgressRideRepository {
    WidgetsBinding.instance.addObserver(this);
    SettingsController.instance.addLocationModeListener(
      restartPositionStreamIfActive,
    );
  }

  /// Global singleton instance.
  static final FuelTrackerService instance = FuelTrackerService();

  /// Maximum horizontal accuracy in meters allowed for a location fix. Fixes with
  /// accuracy > 30 m are considered too inaccurate and rejected.
  static const double maxAccuracyMeters = MotionMath.maxAccuracyMeters;

  /// Minimum distance in meters between consecutive fixes to count as actual movement.
  /// Used to eliminate GPS jitter while stationary.
  static const double minDistanceMeters = 5.0;

  /// Minimum speed in meters per second (1 m/s = 3.6 km/h) below which movement is
  /// classified as stationary jitter.
  static const double minSpeedMps = 1.0;

  /// Maximum plausible speed in meters per second (~55.56 m/s = 200 km/h) above
  /// which a fix is rejected as an implausible GPS jump.
  static const double maxSpeedMps = 55.56;

  LocationService _locationService;
  ActiveBikeController _bikeController;
  FuelNotificationService _notificationService;
  InProgressRideRepository _inProgressRideRepository;

  StreamSubscription<PositionData>? _positionSubscription;
  Timer? _throttleSaveTimer;
  PositionData? _lastAcceptedPosition;

  bool _isRiding = false;
  double _rideDistanceKm = 0.0;
  double _appliedToOdometerKm = 0.0;
  double? _preRideOdometerKm;
  String? _rideBikeId;
  DateTime? _rideStartedAt;
  String? _routeTitle;
  String? _locationErrorMessage;
  bool _hasShownLowFuelNotification = false;
  bool _hasRequestedNotificationPermission = false;
  bool _hasUnsavedChanges = false;

  /// Tracks completed reports' applied odometer distances and pre-ride floors
  /// so discarding from the post-finish summary sheet removes the exact km.
  final Map<String, _FinishedRideOdometerRecord> _finishedReportRecords = {};

  /// Tracks ride/report keys that have already been discarded so a double discard
  /// never subtracts distance from the bike's odometer twice.
  final Set<String> _discardedRideKeys = {};

  // ── Getters ────────────────────────────────────────────────────────────────
  bool get isRiding => _isRiding;
  double get rideDistanceKm => _rideDistanceKm;

  /// Exact distance in kilometers added to the active bike's odometer during the current ride.
  double get appliedToOdometerKm => _appliedToOdometerKm;

  /// Odometer reading in kilometers captured immediately before the current ride started.
  double? get preRideOdometerKm => _preRideOdometerKm;

  DateTime? get rideStartedAt => _rideStartedAt;
  String? get routeTitle => _routeTitle;
  String? get locationErrorMessage => _locationErrorMessage;
  bool get hasShownLowFuelNotification => _hasShownLowFuelNotification;
  bool get notificationPermissionGranted =>
      _notificationService.notificationPermissionGranted;

  /// Returns the odometer distance in kilometers that was applied for [report].
  double appliedOdometerKmForReport(PostRideReport report) {
    return _finishedReportRecords[report.id]?.appliedKm ?? report.distanceKm;
  }

  /// Whether an in-app low fuel warning banner should be shown on the Active Rig card.
  bool get isLowFuelWarningActive {
    final bike = _bikeController.activeBike;
    if (bike == null) return false;
    final currentLiters = FuelEstimator.currentLiters(bike);
    final pct = FuelEstimator.percent(
      currentLiters,
      bike.fuelTankCapacityLiters,
    );
    return pct != null && pct < 15.0;
  }

  /// Sets or updates the destination/route title for the currently active ride.
  void setRouteTitle(String title) {
    if (_routeTitle == title) return;
    _routeTitle = title;
    _persistInProgressRide();
    notifyListeners();
  }

  // ── Testing Hooks ──────────────────────────────────────────────────────────
  void setDependenciesForTesting({
    LocationService? locationService,
    ActiveBikeController? bikeController,
    FuelNotificationService? notificationService,
    InProgressRideRepository? inProgressRideRepository,
  }) {
    if (locationService != null) _locationService = locationService;
    if (bikeController != null) _bikeController = bikeController;
    if (notificationService != null) _notificationService = notificationService;
    if (inProgressRideRepository != null) {
      _inProgressRideRepository = inProgressRideRepository;
    }
  }

  void resetForTesting() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _throttleSaveTimer?.cancel();
    _throttleSaveTimer = null;
    _isRiding = false;
    _rideDistanceKm = 0.0;
    _appliedToOdometerKm = 0.0;
    _preRideOdometerKm = null;
    _rideBikeId = null;
    _rideStartedAt = null;
    _routeTitle = null;
    _locationErrorMessage = null;
    _hasShownLowFuelNotification = false;
    _hasRequestedNotificationPermission = false;
    _hasUnsavedChanges = false;
    _lastAcceptedPosition = null;
    _finishedReportRecords.clear();
    _discardedRideKeys.clear();
    TrackingDiagnostics.instance.recordTrackerState('stopped');
    notifyListeners();
  }

  // ── Ride Lifecycle ─────────────────────────────────────────────────────────

  /// Toggle start/stop ride status.
  Future<bool> toggleRide() async {
    if (_isRiding) {
      await stopRide();
      return false;
    } else {
      return await startRide();
    }
  }

  /// Start live ride distance tracking and fuel estimation.
  Future<bool> startRide({String? routeTitle}) async {
    if (_isRiding) return true;

    _locationErrorMessage = null;
    if (routeTitle != null && routeTitle.trim().isNotEmpty) {
      _routeTitle = routeTitle.trim();
    }

    final serviceEnabled = await _locationService.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _locationErrorMessage =
          'Location service is disabled. Please enable GPS in device settings.';
      notifyListeners();
      return false;
    }

    final hasPermission = await _locationService.checkPermission();
    if (!hasPermission) {
      final granted = await _locationService.requestPermission();
      if (!granted) {
        _locationErrorMessage =
            'Location permission is required for live ride and fuel tracking.';
        notifyListeners();
        return false;
      }
    }

    if (!_hasRequestedNotificationPermission) {
      _hasRequestedNotificationPermission = true;
      try {
        await _notificationService.requestPermission();
      } catch (_) {}
    }

    final bike = _bikeController.activeBike;
    if (bike != null) {
      final currentLiters = FuelEstimator.currentLiters(bike);
      final pct = FuelEstimator.percent(
        currentLiters,
        bike.fuelTankCapacityLiters,
      );
      if (pct != null && pct < 15.0) {
        _hasShownLowFuelNotification = true;
      }
    }

    _isRiding = true;
    _rideStartedAt = DateTime.now();
    _rideDistanceKm = 0.0;
    _appliedToOdometerKm = 0.0;
    _rideBikeId = bike?.id;
    _preRideOdometerKm = bike != null
        ? (bike.preciseOdometerKm ?? bike.odometerKm.toDouble())
        : null;
    _lastAcceptedPosition = null;
    TrackingDiagnostics.instance.recordTrackerState('started');

    _subscribeToPositionStream();

    _throttleSaveTimer?.cancel();
    _throttleSaveTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        _flushPendingBikeSave();
        _persistInProgressRide();
      },
    );

    _persistInProgressRide();
    notifyListeners();
    return true;
  }

  void _persistInProgressRide() {
    if (!_isRiding) return;
    final inProgress = InProgressRide(
      id: 'active-ride',
      startedAt: _rideStartedAt ?? DateTime.now(),
      distanceKm: _rideDistanceKm,
      appliedToOdometerKm: _appliedToOdometerKm,
      preRideOdometerKm: _preRideOdometerKm,
      bikeId: _rideBikeId ?? _bikeController.activeBike?.id,
      routeTitle: _routeTitle,
    );
    _inProgressRideRepository.saveInProgressRide(inProgress);
  }

  /// Stop live ride tracking and flush all pending state to persistent storage.
  Future<void> stopRide() async {
    if (!_isRiding) return;

    _isRiding = false;
    TrackingDiagnostics.instance.recordTrackerState('stopped');
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _throttleSaveTimer?.cancel();
    _throttleSaveTimer = null;
    _lastAcceptedPosition = null;

    await flush();
    notifyListeners();
  }

  /// Completes the active ride, persists the final odometer distance, stops tracking,
  /// clears in-progress persistence, and creates a [PostRideReport] via
  /// [PostRideReportController] with source = 'tracked'.
  ///
  /// If the tracked distance is under 0.1 km ("too short to record"), subtracts
  /// the distance applied to the bike's odometer (never below the pre-ride value),
  /// does not create a report, and returns null.
  Future<PostRideReport?> finishRide() async {
    final wasRiding = _isRiding;
    final distance = _rideDistanceKm;
    final appliedKm = _appliedToOdometerKm;
    final preRideOdo = _preRideOdometerKm;
    final started = _rideStartedAt ?? DateTime.now();
    final ended = DateTime.now();
    final durationHours = ended.difference(started).inSeconds / 3600.0;
    final title = _routeTitle ?? '';
    final bikeId =
        _rideBikeId ?? _bikeController.activeBike?.id ?? 'unknown-bike';

    // Stop stream and periodic timer synchronously first so nothing re-saves after clear.
    _isRiding = false;
    _throttleSaveTimer?.cancel();
    _throttleSaveTimer = null;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _lastAcceptedPosition = null;
    if (wasRiding) {
      TrackingDiagnostics.instance.recordTrackerState('stopped');
    }

    _rideDistanceKm = 0.0;
    _appliedToOdometerKm = 0.0;
    _preRideOdometerKm = null;
    _rideBikeId = null;
    _routeTitle = null;
    _rideStartedAt = null;
    await _inProgressRideRepository.clear();

    if (distance < 0.1) {
      // Ride too short to record: revert any distance added to the bike's odometer.
      _subtractDistanceFromBike(
        bikeId: bikeId,
        kmToRemove: appliedKm,
        minOdometerKm: preRideOdo,
      );
      await flush();
      notifyListeners();
      return null;
    }

    // Reconcile and persist the final distance on the bike before completing the ride.
    _reconcileBikeOdometerWithApplied(
      bikeId: bikeId,
      preRideOdometerKm: preRideOdo,
      appliedToOdometerKm: appliedKm,
    );
    await flush();
    notifyListeners();

    final report = PostRideReport(
      id: 'rep-${DateTime.now().millisecondsSinceEpoch}',
      bikeId: bikeId,
      date: started,
      startedAt: started,
      endedAt: ended,
      distanceKm: double.parse(distance.toStringAsFixed(1)),
      durationHours: double.parse(durationHours.toStringAsFixed(2)),
      routeTitle: title,
      terrainTags: const [],
      source: 'tracked',
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );

    _finishedReportRecords[report.id] = _FinishedRideOdometerRecord(
      appliedKm: appliedKm,
      preRideOdometerKm: preRideOdo,
      bikeId: bikeId,
    );

    PostRideReportController.instance.addReport(report);
    return report;
  }

  /// Resumes an unfinished ride from [savedRide] by restoring distance,
  /// [InProgressRide.appliedToOdometerKm], pre-ride odometer floor, start time,
  /// and route title into memory and restarting the GPS stream without resetting
  /// accumulated distance or double-applying odometer distance.
  Future<bool> resumeRide(InProgressRide savedRide) async {
    _locationErrorMessage = null;

    final serviceEnabled = await _locationService.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _locationErrorMessage =
          'Location service is disabled. Please enable GPS in device settings.';
      notifyListeners();
      return false;
    }

    final hasPermission = await _locationService.checkPermission();
    if (!hasPermission) {
      final granted = await _locationService.requestPermission();
      if (!granted) {
        _locationErrorMessage =
            'Location permission is required for live ride and fuel tracking.';
        notifyListeners();
        return false;
      }
    }

    if (!_hasRequestedNotificationPermission) {
      _hasRequestedNotificationPermission = true;
      try {
        await _notificationService.requestPermission();
      } catch (_) {}
    }

    final targetBikeId = savedRide.bikeId ?? _bikeController.activeBike?.id;
    final bike = (targetBikeId != null
            ? _bikeController.getBikeById(targetBikeId)
            : null) ??
        _bikeController.activeBike;
    if (bike != null) {
      final currentLiters = FuelEstimator.currentLiters(bike);
      final pct = FuelEstimator.percent(
        currentLiters,
        bike.fuelTankCapacityLiters,
      );
      if (pct != null && pct < 15.0) {
        _hasShownLowFuelNotification = true;
      }
    }

    _positionSubscription?.cancel();
    _throttleSaveTimer?.cancel();

    _isRiding = true;
    _rideDistanceKm = savedRide.distanceKm;
    _appliedToOdometerKm = savedRide.appliedToOdometerKm;
    _rideBikeId = targetBikeId;
    if (savedRide.preRideOdometerKm != null) {
      _preRideOdometerKm = savedRide.preRideOdometerKm;
      // Ensure bike odometer matches preRideOdometerKm + appliedToOdometerKm
      // without double-applying or losing distance if app was killed before flush.
      _reconcileBikeOdometerWithApplied(
        bikeId: targetBikeId,
        preRideOdometerKm: _preRideOdometerKm,
        appliedToOdometerKm: _appliedToOdometerKm,
      );
    } else if (bike != null) {
      final currentPreciseOdo =
          bike.preciseOdometerKm ?? bike.odometerKm.toDouble();
      _preRideOdometerKm =
          math.max(0.0, currentPreciseOdo - _appliedToOdometerKm);
    } else {
      _preRideOdometerKm = null;
    }

    _rideStartedAt = savedRide.startedAt;
    _routeTitle = (savedRide.routeTitle != null &&
            savedRide.routeTitle!.trim().isNotEmpty)
        ? savedRide.routeTitle!.trim()
        : null;
    _lastAcceptedPosition = null;

    TrackingDiagnostics.instance.recordTrackerState(
      'resumed',
      'Restored ${savedRide.distanceKm.toStringAsFixed(1)} km (applied ${savedRide.appliedToOdometerKm.toStringAsFixed(1)} km)',
      savedRide.distanceKm * 1000.0,
    );

    _subscribeToPositionStream();

    _throttleSaveTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        _flushPendingBikeSave();
        _persistInProgressRide();
      },
    );

    _persistInProgressRide();
    notifyListeners();
    return true;
  }

  /// Internal helper that stops the active tracker and resets all in-memory ride state
  /// prior to clearing persistent in-progress storage.
  Future<void> _stopAndResetInMemoryState() async {
    _isRiding = false;
    _throttleSaveTimer?.cancel();
    _throttleSaveTimer = null;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _rideDistanceKm = 0.0;
    _appliedToOdometerKm = 0.0;
    _preRideOdometerKm = null;
    _rideBikeId = null;
    _rideStartedAt = null;
    _routeTitle = null;
    _lastAcceptedPosition = null;
    TrackingDiagnostics.instance.recordTrackerState('stopped');
  }

  /// Completes an unfinished ride recovered from persistent storage after an app kill.
  /// Stops any active tracker and resets in-memory state before clearing the repository.
  ///
  /// If [savedRide.distanceKm] < 0.1 km ("too short to record"), subtracts
  /// [savedRide.appliedToOdometerKm] from the bike's odometer (never below pre-ride value)
  /// and returns null. Otherwise reconciles & persists the final odometer distance and
  /// generates a [PostRideReport] with source = 'tracked'.
  Future<PostRideReport?> finishSavedRide(InProgressRide savedRide) async {
    final inMemoryPreRideOdo = _preRideOdometerKm;
    final inMemoryAppliedKm = _appliedToOdometerKm;
    final inMemoryBikeId = _rideBikeId;

    await _stopAndResetInMemoryState();
    await _inProgressRideRepository.clear();

    final effectiveBikeId = savedRide.bikeId ??
        inMemoryBikeId ??
        _bikeController.activeBike?.id ??
        'unknown-bike';
    final effectivePreRideOdo = savedRide.preRideOdometerKm ?? inMemoryPreRideOdo;
    final effectiveAppliedKm = savedRide.appliedToOdometerKm > 0
        ? savedRide.appliedToOdometerKm
        : (inMemoryAppliedKm > 0 ? inMemoryAppliedKm : savedRide.distanceKm);

    if (savedRide.distanceKm < 0.1) {
      _subtractDistanceFromBike(
        bikeId: effectiveBikeId,
        kmToRemove: effectiveAppliedKm,
        minOdometerKm: effectivePreRideOdo,
      );
      await flush();
      notifyListeners();
      return null;
    }

    _reconcileBikeOdometerWithApplied(
      bikeId: effectiveBikeId,
      preRideOdometerKm: effectivePreRideOdo,
      appliedToOdometerKm: effectiveAppliedKm,
    );
    await flush();
    notifyListeners();

    final ended = DateTime.now();
    final durationHours =
        ended.difference(savedRide.startedAt).inSeconds / 3600.0;
    final report = PostRideReport(
      id: 'rep-${DateTime.now().millisecondsSinceEpoch}',
      bikeId: effectiveBikeId,
      date: savedRide.startedAt,
      startedAt: savedRide.startedAt,
      endedAt: ended,
      distanceKm: double.parse(savedRide.distanceKm.toStringAsFixed(1)),
      durationHours: double.parse(durationHours.toStringAsFixed(2)),
      routeTitle: savedRide.routeTitle ?? '',
      terrainTags: const [],
      source: 'tracked',
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );

    _finishedReportRecords[report.id] = _FinishedRideOdometerRecord(
      appliedKm: effectiveAppliedKm,
      preRideOdometerKm: effectivePreRideOdo,
      bikeId: effectiveBikeId,
    );

    PostRideReportController.instance.addReport(report);
    return report;
  }

  String _buildRideKey(InProgressRide ride) =>
      'ride:${ride.id}:${ride.startedAt.toUtc().millisecondsSinceEpoch}';

  /// Discards an active or unfinished ride recovered from persistent storage without
  /// creating a report, and subtracts the exact distance added to the bike's odometer
  /// during the ride (never below the pre-ride odometer value).
  ///
  /// Idempotent: calling [discardSavedRide] multiple times for the same ride will
  /// never subtract distance from the odometer more than once, and cancels the
  /// periodic save timer before clearing storage so the discarded ride is never re-saved.
  Future<void> discardSavedRide([InProgressRide? savedRide]) async {
    final wasRiding = _isRiding;
    final inMemoryAppliedKm = _appliedToOdometerKm;
    final inMemoryPreRideOdo = _preRideOdometerKm;
    final inMemoryBikeId = _rideBikeId;
    final inMemoryStartedAt = _rideStartedAt;

    // Synchronously stop the tracker and cancel the 30-second periodic timer
    // before any await so no timer tick can re-save the discarded ride.
    await _stopAndResetInMemoryState();

    final repoRide = await _inProgressRideRepository.loadInProgressRide();
    await _inProgressRideRepository.clear();

    final targetRide = savedRide ?? repoRide;
    final String? rideKey = targetRide != null
        ? _buildRideKey(targetRide)
        : (inMemoryStartedAt != null
            ? 'ride:active-ride:${inMemoryStartedAt.toUtc().millisecondsSinceEpoch}'
            : null);

    // Guard against double-discard: if already discarded, or if nothing was active/saved.
    if (rideKey != null && _discardedRideKeys.contains(rideKey)) {
      await flush();
      notifyListeners();
      return;
    }
    if (!wasRiding &&
        inMemoryAppliedKm <= 0 &&
        repoRide == null &&
        savedRide == null) {
      await flush();
      notifyListeners();
      return;
    }

    if (rideKey != null) {
      _discardedRideKeys.add(rideKey);
    }

    final double kmToRemove = wasRiding
        ? inMemoryAppliedKm
        : (targetRide?.appliedToOdometerKm ?? inMemoryAppliedKm);
    final double? floorOdo =
        inMemoryPreRideOdo ?? targetRide?.preRideOdometerKm;
    final String? targetBikeId = inMemoryBikeId ??
        targetRide?.bikeId ??
        _bikeController.activeBike?.id;

    _subtractDistanceFromBike(
      bikeId: targetBikeId,
      kmToRemove: kmToRemove,
      minOdometerKm: floorOdo,
    );
    await flush();
    notifyListeners();
  }

  /// Discards a just-finished tracked ride from the summary sheet, removing [report]
  /// from [PostRideReportController] and subtracting the ride's applied odometer
  /// distance (never below the pre-ride odometer value).
  ///
  /// Idempotent: calling [discardFinishedRideReport] twice for the same [report]
  /// will not subtract distance a second time.
  Future<void> discardFinishedRideReport(PostRideReport report) async {
    final reportKey = 'report:${report.id}';
    if (_discardedRideKeys.contains(reportKey)) {
      return;
    }
    _discardedRideKeys.add(reportKey);

    PostRideReportController.instance.removeReport(report.id);

    final record = _finishedReportRecords.remove(report.id);
    final kmToRemove = record?.appliedKm ?? report.distanceKm;
    final floorOdo = record?.preRideOdometerKm;
    final targetBikeId = record?.bikeId ?? report.bikeId;

    _subtractDistanceFromBike(
      bikeId: targetBikeId,
      kmToRemove: kmToRemove,
      minOdometerKm: floorOdo,
    );
    await flush();
    notifyListeners();
  }

  /// Applies [distanceKm] to the target bike's odometer with double precision.
  void applyDistanceToBike({
    required String? bikeId,
    required double distanceKm,
  }) {
    if (distanceKm <= 0) return;
    final bike = (bikeId != null ? _bikeController.getBikeById(bikeId) : null) ??
        _bikeController.activeBike;
    if (bike == null) return;

    final currentPreciseOdo =
        bike.preciseOdometerKm ?? bike.odometerKm.toDouble();
    final newPreciseOdo = currentPreciseOdo + distanceKm;
    final baseOdo = bike.fuelLevelOdometerKm ?? currentPreciseOdo;
    final updatedBike = bike.copyWith(
      odometerKm: newPreciseOdo.round(),
      preciseOdometerKm: newPreciseOdo,
      fuelLevelOdometerKm: baseOdo,
      lastUpdated: DateTime.now(),
    );
    _bikeController.updateBike(updatedBike);
    _hasUnsavedChanges = true;
  }

  /// Subtracts [kmToRemove] from the target bike's odometer, clamping so the
  /// odometer never drops below [minOdometerKm] (or 0.0).
  void subtractDistanceFromBike({
    required String? bikeId,
    required double kmToRemove,
    double? minOdometerKm,
  }) {
    _subtractDistanceFromBike(
      bikeId: bikeId,
      kmToRemove: kmToRemove,
      minOdometerKm: minOdometerKm,
    );
  }

  /// Subtracts [kmToRemove] from the target bike's odometer, clamping so the
  /// odometer never drops below [minOdometerKm] (the pre-ride odometer reading)
  /// or 0.0.
  void _subtractDistanceFromBike({
    required String? bikeId,
    required double kmToRemove,
    required double? minOdometerKm,
  }) {
    if (kmToRemove <= 0) return;
    final bike = (bikeId != null ? _bikeController.getBikeById(bikeId) : null) ??
        _bikeController.activeBike;
    if (bike == null) return;

    final currentPreciseOdo =
        bike.preciseOdometerKm ?? bike.odometerKm.toDouble();
    final floorOdo = math.max(0.0, minOdometerKm ?? 0.0);
    final effectiveFloor = math.min(currentPreciseOdo, floorOdo);
    final rawNewOdo = currentPreciseOdo - kmToRemove;
    // Full precision; snap to the floor when within float noise so a discard
    // returns exactly to the pre-ride odometer with no drift.
    double clampedPreciseOdo =
        rawNewOdo.clamp(effectiveFloor, currentPreciseOdo).toDouble();
    if ((clampedPreciseOdo - effectiveFloor).abs() <= 1e-9) {
      clampedPreciseOdo = effectiveFloor;
    }

    final updatedBike = bike.copyWith(
      odometerKm: clampedPreciseOdo.round(),
      preciseOdometerKm: clampedPreciseOdo,
    );
    _bikeController.updateBike(updatedBike);
    _hasUnsavedChanges = true;
  }

  /// Ensures the bike's odometer reflects `preRideOdometerKm + appliedToOdometerKm`
  /// as the single source of truth without double-applying or losing distance.
  void _reconcileBikeOdometerWithApplied({
    required String? bikeId,
    required double? preRideOdometerKm,
    required double appliedToOdometerKm,
  }) {
    if (preRideOdometerKm == null || appliedToOdometerKm < 0) return;
    final bike = (bikeId != null ? _bikeController.getBikeById(bikeId) : null) ??
        _bikeController.activeBike;
    if (bike == null) return;

    // Full precision expected value; tolerance only absorbs float noise.
    final expectedPreciseOdo = preRideOdometerKm + appliedToOdometerKm;
    final currentPreciseOdo =
        bike.preciseOdometerKm ?? bike.odometerKm.toDouble();
    if ((currentPreciseOdo - expectedPreciseOdo).abs() > 1e-9) {
      final baseOdo = bike.fuelLevelOdometerKm ?? preRideOdometerKm;
      final updatedBike = bike.copyWith(
        odometerKm: expectedPreciseOdo.round(),
        preciseOdometerKm: expectedPreciseOdo,
        fuelLevelOdometerKm: baseOdo,
      );
      _bikeController.updateBike(updatedBike);
      _hasUnsavedChanges = true;
    }
  }

  void _subscribeToPositionStream() {
    _positionSubscription?.cancel();
    _positionSubscription = _locationService
        .getPositionStream(
          highAccuracy: true,
          enableForegroundNotification: true,
          forceLocationManager:
              SettingsController.instance.gpsOnlyLocationProvider,
        )
        .listen(handlePositionUpdate);
  }

  /// Restarts the active tracker GPS stream when the location provider mode changes.
  void restartPositionStreamIfActive() {
    if (!_isRiding) return;
    _subscribeToPositionStream();
  }

  // ── Position Processing & Distance Filtering ───────────────────────────────

  /// Process incoming location fix and accumulate valid movement.
  ///
  /// Evaluates movement strictly against [_lastAcceptedPosition] (baseline is never
  /// updated on rejected fixes, allowing small steps to accumulate until threshold).
  void handlePositionUpdate(PositionData position) {
    final prevAccepted = _lastAcceptedPosition;
    final double? distFromPrev = prevAccepted != null
        ? MotionMath.distanceMeters(prevAccepted, position)
        : null;
    final double? elapsedSec = prevAccepted != null
        ? MotionMath.elapsedSeconds(prevAccepted, position)
        : null;
    final double? calcSpeedFromPrev = prevAccepted != null
        ? MotionMath.calculatedSpeedMpsOrZero(prevAccepted, position)
        : null;
    final bool hasValidReportedSpeed =
        position.speed != null && position.speed! >= minSpeedMps;

    if (!_isRiding) {
      TrackingDiagnostics.instance.recordFix(
        timestamp: position.timestamp,
        previousAcceptedTimestamp: prevAccepted?.timestamp,
        elapsedSeconds: elapsedSec,
        distanceFromPreviousAcceptedMeters: distFromPrev,
        previousAccuracy: prevAccepted?.accuracy,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        speed: position.speed,
        reportedSpeedValid: hasValidReportedSpeed,
        calculatedSpeed: calcSpeedFromPrev,
        accepted: false,
        reason: 'Not navigating (ride not started / stopped)',
      );
      return;
    }

    // 1. Ignore fixes with accuracy > maxAccuracyMeters (30 m)
    if (!MotionMath.isGoodFix(position, maxAccuracy: maxAccuracyMeters)) {
      TrackingDiagnostics.instance.recordFix(
        timestamp: position.timestamp,
        previousAcceptedTimestamp: prevAccepted?.timestamp,
        elapsedSeconds: elapsedSec,
        distanceFromPreviousAcceptedMeters: distFromPrev,
        previousAccuracy: prevAccepted?.accuracy,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        speed: position.speed,
        reportedSpeedValid: hasValidReportedSpeed,
        calculatedSpeed: calcSpeedFromPrev,
        accepted: false,
        reason:
            'Accuracy filter (> ${maxAccuracyMeters.toStringAsFixed(0)} m: ${position.accuracy!.toStringAsFixed(1)} m)',
      );
      return;
    }

    // Baseline fix establishing initial coordinate
    if (prevAccepted == null) {
      _lastAcceptedPosition = position;
      TrackingDiagnostics.instance.recordFix(
        timestamp: position.timestamp,
        previousAcceptedTimestamp: null,
        elapsedSeconds: 0.0,
        distanceFromPreviousAcceptedMeters: 0.0,
        previousAccuracy: null,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        speed: position.speed,
        reportedSpeedValid: hasValidReportedSpeed,
        calculatedSpeed: 0.0,
        accepted: true,
        reason: 'Baseline fix (starting point, 0 m accumulated)',
        segmentMeters: 0.0,
      );
      return;
    }

    final distMeters = distFromPrev!;
    final timeElapsedSeconds = elapsedSec!;
    final double calcSpeed = calcSpeedFromPrev!;

    // 2. Reject if dist < minDistanceMeters (5 m)
    if (distMeters < minDistanceMeters) {
      TrackingDiagnostics.instance.recordFix(
        timestamp: position.timestamp,
        previousAcceptedTimestamp: prevAccepted.timestamp,
        elapsedSeconds: timeElapsedSeconds,
        distanceFromPreviousAcceptedMeters: distMeters,
        previousAccuracy: prevAccepted.accuracy,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        speed: position.speed,
        reportedSpeedValid: hasValidReportedSpeed,
        calculatedSpeed: calcSpeed,
        accepted: false,
        reason:
            'Minimum distance filter (< ${minDistanceMeters.toStringAsFixed(0)} m: ${distMeters.toStringAsFixed(1)} m)',
      );
      return;
    }

    // 3. Movement / Speed evaluation:
    // - If reported speed >= minSpeedMps (1.0 m/s): treat as moving and proceed.
    // - Otherwise (reported speed null, 0.0, or < 1.0 m/s), reported speed is unreliable:
    //   accept only if calcSpeed >= minSpeedMps AND dist >= max(minDistanceMeters, position.accuracy).
    if (!hasValidReportedSpeed) {
      final double effectiveAccuracy = position.accuracy ?? 0.0;
      final double requiredDist =
          math.max(minDistanceMeters, effectiveAccuracy);
      final bool isMovingByCalc =
          calcSpeed >= minSpeedMps && distMeters >= requiredDist;

      if (!isMovingByCalc) {
        TrackingDiagnostics.instance.recordFix(
          timestamp: position.timestamp,
          previousAcceptedTimestamp: prevAccepted.timestamp,
          elapsedSeconds: timeElapsedSeconds,
          distanceFromPreviousAcceptedMeters: distMeters,
          previousAccuracy: prevAccepted.accuracy,
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          speed: position.speed,
          reportedSpeedValid: hasValidReportedSpeed,
          calculatedSpeed: calcSpeed,
          accepted: false,
          reason:
              'Stationary: moved ${distMeters.toStringAsFixed(1)} m, accuracy ${effectiveAccuracy.toStringAsFixed(1)} m',
        );
        return;
      }
    }

    // 4. Ignore implausible jumps (speed > maxSpeedMps = ~200 km/h)
    if (position.speed != null && position.speed! > maxSpeedMps) {
      TrackingDiagnostics.instance.recordFix(
        timestamp: position.timestamp,
        previousAcceptedTimestamp: prevAccepted.timestamp,
        elapsedSeconds: timeElapsedSeconds,
        distanceFromPreviousAcceptedMeters: distMeters,
        previousAccuracy: prevAccepted.accuracy,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        speed: position.speed,
        reportedSpeedValid: hasValidReportedSpeed,
        calculatedSpeed: calcSpeed,
        accepted: false,
        reason:
            'Jump filter (reported speed > ${maxSpeedMps.toStringAsFixed(1)} m/s: ${position.speed!.toStringAsFixed(1)} m/s)',
      );
      return;
    }
    if (timeElapsedSeconds > 0 && calcSpeed > maxSpeedMps) {
      TrackingDiagnostics.instance.recordFix(
        timestamp: position.timestamp,
        previousAcceptedTimestamp: prevAccepted.timestamp,
        elapsedSeconds: timeElapsedSeconds,
        distanceFromPreviousAcceptedMeters: distMeters,
        previousAccuracy: prevAccepted.accuracy,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        speed: position.speed,
        reportedSpeedValid: hasValidReportedSpeed,
        calculatedSpeed: calcSpeed,
        accepted: false,
        reason:
            'Jump filter (calculated speed > ${maxSpeedMps.toStringAsFixed(1)} m/s: ${calcSpeed.toStringAsFixed(1)} m/s)',
      );
      return;
    }

    // Valid movement segment accepted — update baseline position
    _lastAcceptedPosition = position;
    final segmentKm = distMeters / 1000.0;
    _rideDistanceKm += segmentKm;

    TrackingDiagnostics.instance.recordFix(
      timestamp: position.timestamp,
      previousAcceptedTimestamp: prevAccepted.timestamp,
      elapsedSeconds: timeElapsedSeconds,
      distanceFromPreviousAcceptedMeters: distMeters,
      previousAccuracy: prevAccepted.accuracy,
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      speed: position.speed,
      reportedSpeedValid: hasValidReportedSpeed,
      calculatedSpeed: calcSpeed,
      accepted: true,
      reason: 'Accepted (+${distMeters.toStringAsFixed(1)} m)',
      segmentMeters: distMeters,
    );

    _applyDistanceToActiveBike(segmentKm);
  }

  void _applyDistanceToActiveBike(double segmentKm) {
    final bike = (_rideBikeId != null
            ? _bikeController.getBikeById(_rideBikeId!)
            : null) ??
        _bikeController.activeBike;
    if (bike == null) {
      _persistInProgressRide();
      notifyListeners();
      return;
    }

    _rideBikeId ??= bike.id;
    final currentPreciseOdo =
        bike.preciseOdometerKm ?? bike.odometerKm.toDouble();
    _preRideOdometerKm ??= currentPreciseOdo;

    // Full double precision: no per-fix rounding, so short segments (e.g. 30 m)
    // accumulate instead of being lost. Only the whole-km display value is rounded.
    final newPreciseOdo = currentPreciseOdo + segmentKm;
    if (segmentKm > 0) {
      _appliedToOdometerKm += segmentKm;
    }
    final baseOdo = bike.fuelLevelOdometerKm ?? currentPreciseOdo;

    // Update bike with advanced odometer; fuelRemainingLiters is NOT decremented per GPS fix.
    // The fuel level follows the odometer formula:
    // currentLiters = clamp(fuelRemainingLiters - (currentOdometer - fuelLevelOdometerKm) / fuelAverageKmPerLiter, 0, tankCapacity)
    final updatedBike = bike.copyWith(
      odometerKm: newPreciseOdo.round(),
      preciseOdometerKm: newPreciseOdo,
      fuelLevelOdometerKm: baseOdo,
    );

    _bikeController.updateBike(updatedBike);
    _hasUnsavedChanges = true;
    _persistInProgressRide();

    // Check low-fuel crossing below 15% using computed current liters
    final currentLiters = FuelEstimator.currentLiters(updatedBike);
    final pct = FuelEstimator.percent(
      currentLiters,
      updatedBike.fuelTankCapacityLiters,
    );
    final range = FuelEstimator.rangeKm(
      currentLiters,
      updatedBike.fuelAverageKmPerLiter,
    );

    if (pct != null && pct < 15.0) {
      if (!_hasShownLowFuelNotification) {
        _hasShownLowFuelNotification = true;
        if (range != null && SettingsController.instance.notificationsEnabled) {
          _notificationService.showLowFuelAlert(rangeKm: range.round());
        }
      }
    } else if (pct != null && pct >= 15.0) {
      _hasShownLowFuelNotification = false;
    }

    notifyListeners();
  }

  /// Resets the low fuel single-trigger notification flag (e.g. after a refill).
  void resetLowFuelFlag() {
    _hasShownLowFuelNotification = false;
    notifyListeners();
  }

  // ── Persistence & Lifecycle ────────────────────────────────────────────────

  void _flushPendingBikeSave() {
    if (_hasUnsavedChanges) {
      _hasUnsavedChanges = false;
      _bikeController.save();
    }
  }

  /// Explicitly flushes any pending writes to persistent storage.
  Future<void> flush() async {
    _hasUnsavedChanges = false;
    await _bikeController.save();
    await _bikeController.flush();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    TrackingDiagnostics.instance.recordLifecycleChange(state.name);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _persistInProgressRide();
      flush();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SettingsController.instance.removeLocationModeListener(
      restartPositionStreamIfActive,
    );
    _positionSubscription?.cancel();
    _throttleSaveTimer?.cancel();
    flush();
    super.dispose();
  }
}

/// Internal value record capturing the exact odometer delta and pre-ride floor
/// for a finished ride report so post-finish discard can revert it accurately.
class _FinishedRideOdometerRecord {
  const _FinishedRideOdometerRecord({
    required this.appliedKm,
    required this.preRideOdometerKm,
    required this.bikeId,
  });

  final double appliedKm;
  final double? preRideOdometerKm;
  final String bikeId;
}
