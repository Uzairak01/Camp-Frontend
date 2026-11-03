import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/data/app_repositories.dart';
import '../../../core/data/in_progress_ride_model.dart';
import '../../../core/data/in_progress_ride_repository.dart';
import '../../maintenance/controllers/post_ride_report_controller.dart';
import '../../maintenance/domain/post_ride_report.dart';
import '../../navigation/domain/location_service.dart';
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
  }

  /// Global singleton instance.
  static final FuelTrackerService instance = FuelTrackerService();

  /// Maximum horizontal accuracy in meters allowed for a location fix. Fixes with
  /// accuracy > 30 m are considered too inaccurate and rejected.
  static const double maxAccuracyMeters = 30.0;

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
  DateTime? _rideStartedAt;
  String? _routeTitle;
  String? _locationErrorMessage;
  bool _hasShownLowFuelNotification = false;
  bool _hasRequestedNotificationPermission = false;
  bool _hasUnsavedChanges = false;

  // ── Getters ────────────────────────────────────────────────────────────────
  bool get isRiding => _isRiding;
  double get rideDistanceKm => _rideDistanceKm;
  DateTime? get rideStartedAt => _rideStartedAt;
  String? get routeTitle => _routeTitle;
  String? get locationErrorMessage => _locationErrorMessage;
  bool get hasShownLowFuelNotification => _hasShownLowFuelNotification;
  bool get notificationPermissionGranted =>
      _notificationService.notificationPermissionGranted;

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
    _throttleSaveTimer?.cancel();
    _isRiding = false;
    _rideDistanceKm = 0.0;
    _rideStartedAt = null;
    _routeTitle = null;
    _locationErrorMessage = null;
    _hasShownLowFuelNotification = false;
    _hasRequestedNotificationPermission = false;
    _hasUnsavedChanges = false;
    _lastAcceptedPosition = null;
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
    _lastAcceptedPosition = null;
    TrackingDiagnostics.instance.recordTrackerState('started');

    _positionSubscription = _locationService
        .getPositionStream(
          highAccuracy: true,
          enableForegroundNotification: true,
        )
        .listen(handlePositionUpdate);

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
      bikeId: _bikeController.activeBike?.id,
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

  /// Completes the active ride, stops tracking, clears in-progress persistence,
  /// and creates a [PostRideReport] via [PostRideReportController] with source = 'tracked'.
  /// If the tracked distance is under 0.1 km, does not create a report and returns null.
  Future<PostRideReport?> finishRide() async {
    final wasRiding = _isRiding;
    final distance = _rideDistanceKm;
    final started = _rideStartedAt ?? DateTime.now();
    final ended = DateTime.now();
    final durationHours = ended.difference(started).inSeconds / 3600.0;
    final title = _routeTitle ?? '';
    final bikeId = _bikeController.activeBike?.id ?? 'unknown-bike';

    if (wasRiding) {
      await stopRide();
    }
    await _inProgressRideRepository.clear();
    _routeTitle = null;
    _rideStartedAt = null;

    if (distance < 0.1) {
      return null;
    }

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

    PostRideReportController.instance.addReport(report);
    return report;
  }

  /// Resumes an unfinished ride from [savedRide] by restoring distance, start time,
  /// and route title into memory and restarting the GPS stream without resetting
  /// accumulated distance to zero.
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

    _positionSubscription?.cancel();
    _throttleSaveTimer?.cancel();

    _isRiding = true;
    _rideDistanceKm = savedRide.distanceKm;
    _rideStartedAt = savedRide.startedAt;
    _routeTitle = (savedRide.routeTitle != null &&
            savedRide.routeTitle!.trim().isNotEmpty)
        ? savedRide.routeTitle!.trim()
        : null;
    _lastAcceptedPosition = null;

    TrackingDiagnostics.instance.recordTrackerState(
      'resumed',
      'Restored ${savedRide.distanceKm.toStringAsFixed(1)} km',
      savedRide.distanceKm * 1000.0,
    );

    _positionSubscription = _locationService
        .getPositionStream(
          highAccuracy: true,
          enableForegroundNotification: true,
        )
        .listen(handlePositionUpdate);

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
    await stopRide();
    _throttleSaveTimer?.cancel();
    _throttleSaveTimer = null;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _isRiding = false;
    _rideDistanceKm = 0.0;
    _rideStartedAt = null;
    _routeTitle = null;
    _lastAcceptedPosition = null;
  }

  /// Completes an unfinished ride recovered from persistent storage after an app kill.
  /// Stops any active tracker and resets in-memory state before clearing the repository.
  /// Generates a [PostRideReport] with source = 'tracked' if distance >= 0.1 km.
  Future<PostRideReport?> finishSavedRide(InProgressRide savedRide) async {
    await _stopAndResetInMemoryState();
    await _inProgressRideRepository.clear();
    notifyListeners();

    if (savedRide.distanceKm < 0.1) {
      return null;
    }

    final ended = DateTime.now();
    final durationHours =
        ended.difference(savedRide.startedAt).inSeconds / 3600.0;
    final report = PostRideReport(
      id: 'rep-${DateTime.now().millisecondsSinceEpoch}',
      bikeId: savedRide.bikeId ??
          _bikeController.activeBike?.id ??
          'unknown-bike',
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

    PostRideReportController.instance.addReport(report);
    return report;
  }

  /// Discards an unfinished ride recovered from persistent storage without creating a report.
  /// Stops any active tracker and resets in-memory state before clearing the repository.
  Future<void> discardSavedRide() async {
    await _stopAndResetInMemoryState();
    await _inProgressRideRepository.clear();
    notifyListeners();
  }

  // ── Position Processing & Distance Filtering ───────────────────────────────

  /// Process incoming location fix and accumulate valid movement.
  ///
  /// Evaluates movement strictly against [_lastAcceptedPosition] (baseline is never
  /// updated on rejected fixes, allowing small steps to accumulate until threshold).
  void handlePositionUpdate(PositionData position) {
    if (!_isRiding) {
      TrackingDiagnostics.instance.recordFix(
        timestamp: position.timestamp,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        speed: position.speed,
        accepted: false,
        reason: 'Not navigating (ride not started / stopped)',
      );
      return;
    }

    // 1. Ignore fixes with accuracy > maxAccuracyMeters (30 m)
    if (position.accuracy != null && position.accuracy! > maxAccuracyMeters) {
      TrackingDiagnostics.instance.recordFix(
        timestamp: position.timestamp,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        speed: position.speed,
        accepted: false,
        reason:
            'Accuracy filter (> ${maxAccuracyMeters.toStringAsFixed(0)} m: ${position.accuracy!.toStringAsFixed(1)} m)',
      );
      return;
    }

    // Baseline fix establishing initial coordinate
    if (_lastAcceptedPosition == null) {
      _lastAcceptedPosition = position;
      TrackingDiagnostics.instance.recordFix(
        timestamp: position.timestamp,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        speed: position.speed,
        calculatedSpeed: 0.0,
        accepted: true,
        reason: 'Baseline fix (starting point, 0 m accumulated)',
        segmentMeters: 0.0,
      );
      return;
    }

    final distMeters = Geolocator.distanceBetween(
      _lastAcceptedPosition!.latitude,
      _lastAcceptedPosition!.longitude,
      position.latitude,
      position.longitude,
    );

    final timeElapsedSeconds = position.timestamp
            .difference(_lastAcceptedPosition!.timestamp)
            .inMilliseconds /
        1000.0;

    final double calcSpeed =
        timeElapsedSeconds > 0 ? distMeters / timeElapsedSeconds : 0.0;

    // 2. Reject if dist < minDistanceMeters (5 m)
    if (distMeters < minDistanceMeters) {
      TrackingDiagnostics.instance.recordFix(
        timestamp: position.timestamp,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        speed: position.speed,
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
    final bool hasValidReportedSpeed =
        position.speed != null && position.speed! >= minSpeedMps;
    if (!hasValidReportedSpeed) {
      final double effectiveAccuracy = position.accuracy ?? 0.0;
      final double requiredDist =
          math.max(minDistanceMeters, effectiveAccuracy);
      final bool isMovingByCalc =
          calcSpeed >= minSpeedMps && distMeters >= requiredDist;

      if (!isMovingByCalc) {
        TrackingDiagnostics.instance.recordFix(
          timestamp: position.timestamp,
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          speed: position.speed,
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
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        speed: position.speed,
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
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        speed: position.speed,
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
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      speed: position.speed,
      calculatedSpeed: calcSpeed,
      accepted: true,
      reason: 'Accepted (+${distMeters.toStringAsFixed(1)} m)',
      segmentMeters: distMeters,
    );

    _applyDistanceToActiveBike(segmentKm);
  }

  void _applyDistanceToActiveBike(double segmentKm) {
    final bike = _bikeController.activeBike;
    if (bike == null) return;

    final currentPreciseOdo =
        bike.preciseOdometerKm ?? bike.odometerKm.toDouble();
    final newPreciseOdo =
        double.parse((currentPreciseOdo + segmentKm).toStringAsFixed(1));
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
    _positionSubscription?.cancel();
    _throttleSaveTimer?.cancel();
    flush();
    super.dispose();
  }
}
