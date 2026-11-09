import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../navigation/domain/motion_math.dart';
import '../../settings/controllers/settings_controller.dart';

/// Status of a location fix processed by the tracking engine.
enum TrackingFixStatus {
  /// Fix satisfied all filter criteria and contributed to accumulated distance.
  accepted,

  /// Fix failed one or more filter checks (accuracy, distance, speed, jump, or inactive).
  rejected,
}

/// Category of an event recorded in the tracking diagnostics log.
enum TrackingEventType {
  /// Raw GPS fix received and evaluated.
  fix,

  /// Detected time gap between consecutive fixes exceeding 30 seconds.
  gap,

  /// Tracker lifecycle state transition (started, stopped, paused).
  trackerState,

  /// Flutter application lifecycle state change (resumed, paused, inactive, detached).
  lifecycle,

  /// Navigation off-route state change (entered off-route or returned on-route).
  offRoute,

  /// Navigation reroute attempt outcome (accepted or discarded, with reason).
  reroute,
}

/// Aggregated summary metrics computed across the recorded fix events in [TrackingDiagnostics].
class TrackingDiagnosticsSummary {
  /// Creates an immutable snapshot of tracking diagnostic summary statistics.
  const TrackingDiagnosticsSummary({
    required this.totalFixes,
    required this.accuracyRejectedFixes,
    required this.percentRejectedForAccuracy,
    required this.medianAccuracyMeters,
    required this.validReportedSpeedFixes,
    required this.percentValidReportedSpeed,
    required this.longestGapWithoutAcceptedSeconds,
    required this.maxCalculatedSpeedAcceptedMps,
  });

  /// Total number of raw location fixes evaluated.
  final int totalFixes;

  /// Number of fixes rejected due to horizontal accuracy exceeding threshold.
  final int accuracyRejectedFixes;

  /// Percentage (`0..100`) of total fixes rejected for accuracy.
  final double percentRejectedForAccuracy;

  /// Median horizontal accuracy in meters across all fixes with non-null accuracy.
  final double? medianAccuracyMeters;

  /// Number of fixes that carried a valid reported speed (`>= 1.0 m/s`).
  final int validReportedSpeedFixes;

  /// Percentage (`0..100`) of total fixes that had a valid reported speed.
  final double percentValidReportedSpeed;

  /// Longest elapsed time in seconds without an accepted fix.
  final double longestGapWithoutAcceptedSeconds;

  /// Maximum calculated speed in meters per second among accepted fixes.
  final double maxCalculatedSpeedAcceptedMps;

  /// Maximum calculated speed in km/h among accepted fixes.
  double get maxCalculatedSpeedAcceptedKmh =>
      maxCalculatedSpeedAcceptedMps * 3.6;
}

/// Immutable record of a single tracking diagnostic event.
class TrackingEvent {
  const TrackingEvent({
    required this.timestamp,
    required this.type,
    this.previousAcceptedTimestamp,
    this.elapsedSeconds,
    this.distanceFromPreviousAcceptedMeters,
    this.previousAccuracy,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.speed,
    this.reportedSpeedValid,
    this.calculatedSpeed,
    this.crossTrackMeters,
    this.isOffRouteState,
    this.status,
    this.reason,
    this.segmentMeters,
    this.accumulatedMeters,
    this.gapDuration,
    this.message,
    this.heading,
    this.headingSource,
  });

  /// Factory creating an accepted or rejected fix event.
  factory TrackingEvent.fix({
    required DateTime timestamp,
    required double latitude,
    required double longitude,
    required double? accuracy,
    required double? speed,
    required TrackingFixStatus status,
    required String reason,
    DateTime? previousAcceptedTimestamp,
    double? elapsedSeconds,
    double? distanceFromPreviousAcceptedMeters,
    double? previousAccuracy,
    bool? reportedSpeedValid,
    double? calculatedSpeed,
    double segmentMeters = 0.0,
    double accumulatedMeters = 0.0,
  }) {
    return TrackingEvent(
      timestamp: timestamp.toUtc(),
      type: TrackingEventType.fix,
      previousAcceptedTimestamp: previousAcceptedTimestamp?.toUtc(),
      elapsedSeconds: elapsedSeconds,
      distanceFromPreviousAcceptedMeters: distanceFromPreviousAcceptedMeters,
      previousAccuracy: previousAccuracy,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      speed: speed,
      reportedSpeedValid:
          reportedSpeedValid ?? (speed != null && speed >= 1.0),
      calculatedSpeed: calculatedSpeed,
      status: status,
      reason: reason,
      segmentMeters: segmentMeters,
      accumulatedMeters: accumulatedMeters,
    );
  }

  /// Factory creating a gap warning event.
  factory TrackingEvent.gap({
    required DateTime timestamp,
    required Duration gapDuration,
  }) {
    return TrackingEvent(
      timestamp: timestamp.toUtc(),
      type: TrackingEventType.gap,
      gapDuration: gapDuration,
      message:
          '${gapDuration.inSeconds}s elapsed since previous fix (updates paused / screen locked)',
    );
  }

  /// Factory creating a tracker state change event.
  factory TrackingEvent.trackerState({
    required DateTime timestamp,
    required String state,
    String? details,
  }) {
    return TrackingEvent(
      timestamp: timestamp.toUtc(),
      type: TrackingEventType.trackerState,
      message: details != null ? '$state ($details)' : state,
    );
  }

  /// Factory creating an application lifecycle change event.
  factory TrackingEvent.lifecycle({
    required DateTime timestamp,
    required String lifecycleState,
  }) {
    return TrackingEvent(
      timestamp: timestamp.toUtc(),
      type: TrackingEventType.lifecycle,
      message: 'AppLifecycleState.$lifecycleState',
    );
  }

  /// Factory creating a navigation off-route state change event.
  factory TrackingEvent.offRoute({
    required DateTime timestamp,
    required bool isOffRoute,
    required double crossTrackMeters,
    required double? accuracy,
    required String reason,
  }) {
    final stateLabel = isOffRoute ? 'OFF_ROUTE' : 'ON_ROUTE';
    return TrackingEvent(
      timestamp: timestamp.toUtc(),
      type: TrackingEventType.offRoute,
      crossTrackMeters: crossTrackMeters,
      accuracy: accuracy,
      isOffRouteState: isOffRoute,
      reason: reason,
      message:
          '$stateLabel | CrossTrack: ${crossTrackMeters.toStringAsFixed(1)} m | Acc: ${accuracy != null ? '${accuracy.toStringAsFixed(1)} m' : 'N/A'} | $reason',
    );
  }

  /// Factory creating a navigation reroute outcome event.
  factory TrackingEvent.reroute({
    required DateTime timestamp,
    required double crossTrackMeters,
    required double? accuracy,
    required bool accepted,
    required String reason,
    double? heading,
    String? headingSource,
  }) {
    final statusLabel = accepted ? 'ACCEPTED' : 'DISCARDED';
    final headingText = heading != null
        ? '${heading.toStringAsFixed(1)}° (${headingSource ?? "from last good fixes"})'
        : 'none';
    return TrackingEvent(
      timestamp: timestamp.toUtc(),
      type: TrackingEventType.reroute,
      crossTrackMeters: crossTrackMeters,
      accuracy: accuracy,
      heading: heading,
      headingSource: headingSource,
      status: accepted
          ? TrackingFixStatus.accepted
          : TrackingFixStatus.rejected,
      reason: reason,
      message:
          '$statusLabel | Heading: $headingText | CrossTrack: ${crossTrackMeters.toStringAsFixed(1)} m | Acc: ${accuracy != null ? '${accuracy.toStringAsFixed(1)} m' : 'N/A'} | $reason',
    );
  }

  /// Wall-clock time when the event occurred (stored in UTC).
  final DateTime timestamp;

  /// Nature of the recorded event.
  final TrackingEventType type;

  /// Timestamp of the previous accepted fix, if one existed when this fix was evaluated.
  final DateTime? previousAcceptedTimestamp;

  /// Seconds elapsed since [previousAcceptedTimestamp], if available.
  final double? elapsedSeconds;

  /// Great-circle distance in meters from the previous accepted fix, if available.
  final double? distanceFromPreviousAcceptedMeters;

  /// Horizontal accuracy in meters of the previous accepted fix, if available.
  final double? previousAccuracy;

  /// Latitude of the GPS fix.
  final double? latitude;

  /// Longitude of the GPS fix.
  final double? longitude;

  /// Horizontal accuracy in meters reported by the GPS provider.
  final double? accuracy;

  /// Speed over ground in meters per second reported by the GPS provider.
  final double? speed;

  /// Whether the GPS-reported speed was valid (>= minimum moving threshold).
  final bool? reportedSpeedValid;

  /// Speed in meters per second calculated from distance and time since last accepted fix.
  final double? calculatedSpeed;

  /// Cross-track distance in meters from the active route polyline (for off-route and reroute events).
  final double? crossTrackMeters;

  /// Whether the rider transitioned into off-route (`true`) or back on-route (`false`).
  final bool? isOffRouteState;

  /// Whether the fix was accepted or rejected by the distance filter engine.
  final TrackingFixStatus? status;

  /// Detailed human-readable explanation of the acceptance or rejection.
  final String? reason;

  /// Distance in meters contributed by this specific fix segment.
  final double? segmentMeters;

  /// Total distance in meters accumulated up to and including this fix.
  final double? accumulatedMeters;

  /// Elapsed duration since previous location fix (for gap events).
  final Duration? gapDuration;

  /// Descriptive message for lifecycle and state events.
  final String? message;

  /// Heading in degrees (`0..360`) evaluated during navigation rerouting, if available.
  final double? heading;

  /// Origin of the heading used for reroutes (`"from last good fixes"` or `"none"`).
  final String? headingSource;

  bool get isGap => type == TrackingEventType.gap;
  bool get isRejected => status == TrackingFixStatus.rejected;
  bool get isAccepted => status == TrackingFixStatus.accepted;

  /// Whether the fix segment passed all filters.
  bool get segmentPassed => isAccepted;

  /// Event timestamp formatted as UTC ISO-8601 with `'Z'` suffix.
  String get formattedTimestampUtc => MotionMath.formatUtcIso8601(timestamp);

  /// Previous accepted fix timestamp formatted as UTC ISO-8601 with `'Z'` suffix, or `'None'`.
  String get formattedPreviousAcceptedTimestampUtc =>
      previousAcceptedTimestamp != null
          ? MotionMath.formatUtcIso8601(previousAcceptedTimestamp!)
          : 'None';

  /// Formatted elapsed seconds since previous accepted fix.
  String get formattedElapsedSeconds =>
      elapsedSeconds != null ? '${elapsedSeconds!.toStringAsFixed(1)} s' : 'N/A';

  /// Formatted distance in meters from previous accepted fix.
  String get formattedDistanceFromPreviousAccepted =>
      distanceFromPreviousAcceptedMeters != null
          ? '${distanceFromPreviousAcceptedMeters!.toStringAsFixed(1)} m'
          : 'N/A';

  /// Formatted previous accepted fix accuracy in meters.
  String get formattedPreviousAccuracy =>
      previousAccuracy != null
          ? '${previousAccuracy!.toStringAsFixed(1)} m'
          : 'N/A';

  /// Latitude rounded to 5 decimal places (~1.1 meter resolution).
  String get formattedLatitude =>
      latitude != null ? latitude!.toStringAsFixed(5) : '-';

  /// Longitude rounded to 5 decimal places (~1.1 meter resolution).
  String get formattedLongitude =>
      longitude != null ? longitude!.toStringAsFixed(5) : '-';

  /// Whether the reported speed on this fix is considered valid (>= 1.0 m/s).
  bool get isReportedSpeedValid =>
      reportedSpeedValid ?? (speed != null && speed! >= 1.0);

  /// Human-readable validity flag ('valid' or 'invalid') for the reported speed.
  String get formattedReportedSpeedValidity =>
      isReportedSpeedValid ? 'valid' : 'invalid';

  /// Formatted speed in meters per second and km/h.
  String get formattedSpeed {
    if (speed == null) return 'N/A';
    final kmh = speed! * 3.6;
    return '${speed!.toStringAsFixed(2)} m/s (${kmh.toStringAsFixed(1)} km/h)';
  }

  /// Formatted calculated speed in meters per second and km/h.
  String get formattedCalculatedSpeed {
    if (calculatedSpeed == null) return 'N/A';
    final kmh = calculatedSpeed! * 3.6;
    return '${calculatedSpeed!.toStringAsFixed(2)} m/s (${kmh.toStringAsFixed(1)} km/h)';
  }

  /// Formatted accuracy in meters.
  String get formattedAccuracy =>
      accuracy != null ? '${accuracy!.toStringAsFixed(1)} m' : 'N/A';
}

/// Central in-memory diagnostics singleton for real-time ride tracking observation.
///
/// Records location fixes, filter decisions, time gaps, state transitions, and
/// lifecycle states. Capped at the last 500 events to ensure strict memory safety.
/// Automatically resets on application restart.
class TrackingDiagnostics extends ChangeNotifier {
  TrackingDiagnostics();

  /// Global singleton instance.
  static final TrackingDiagnostics instance = TrackingDiagnostics();

  /// Maximum number of events retained in memory before dropping oldest.
  static const int maxEvents = 500;

  /// In-memory event log ordered newest first.
  final List<TrackingEvent> _events = [];

  /// Read-only snapshot of recorded events (newest first).
  List<TrackingEvent> get events => List.unmodifiable(_events);

  double _accumulatedDistanceMeters = 0.0;
  int _acceptedCount = 0;
  int _rejectedCount = 0;
  String _trackerState = 'stopped';
  DateTime? _lastFixTime;

  /// Running accumulated ride distance in meters.
  double get accumulatedDistanceMeters => _accumulatedDistanceMeters;

  /// Total count of location fixes accepted since tracking began or log was cleared.
  int get acceptedCount => _acceptedCount;

  /// Total count of location fixes rejected since tracking began or log was cleared.
  int get rejectedCount => _rejectedCount;

  /// Current tracker state ('started', 'stopped', 'paused').
  String get trackerState => _trackerState;

  /// Timestamp of the most recent location fix received (stored in UTC).
  DateTime? get lastFixTime => _lastFixTime;

  /// Number of seconds elapsed since the last location fix was received.
  int? get secondsSinceLastFix {
    if (_lastFixTime == null) return null;
    return DateTime.now().toUtc().difference(_lastFixTime!).inSeconds;
  }

  /// Records an incoming location fix along with filter evaluation outcome.
  void recordFix({
    required DateTime timestamp,
    required double latitude,
    required double longitude,
    required double? accuracy,
    required double? speed,
    required bool accepted,
    required String reason,
    DateTime? previousAcceptedTimestamp,
    double? elapsedSeconds,
    double? distanceFromPreviousAcceptedMeters,
    double? previousAccuracy,
    bool? reportedSpeedValid,
    double? calculatedSpeed,
    double segmentMeters = 0.0,
  }) {
    final utcTime = timestamp.toUtc();

    // 1. Detect gap since previous fix (>30 seconds)
    if (_lastFixTime != null) {
      final gapSeconds =
          MotionMath.elapsedSecondsBetween(_lastFixTime!, utcTime);
      if (gapSeconds > 30.0) {
        _insertEvent(TrackingEvent.gap(
          timestamp: utcTime,
          gapDuration: Duration(milliseconds: (gapSeconds * 1000).round()),
        ));
      }
    }
    _lastFixTime = utcTime;

    // 2. Update metric counters
    if (accepted) {
      _acceptedCount++;
      _accumulatedDistanceMeters += segmentMeters;
    } else {
      _rejectedCount++;
    }

    // 3. Record fix event
    _insertEvent(TrackingEvent.fix(
      timestamp: utcTime,
      previousAcceptedTimestamp: previousAcceptedTimestamp,
      elapsedSeconds: elapsedSeconds,
      distanceFromPreviousAcceptedMeters: distanceFromPreviousAcceptedMeters,
      previousAccuracy: previousAccuracy,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      speed: speed,
      reportedSpeedValid: reportedSpeedValid,
      calculatedSpeed: calculatedSpeed,
      status: accepted ? TrackingFixStatus.accepted : TrackingFixStatus.rejected,
      reason: reason,
      segmentMeters: segmentMeters,
      accumulatedMeters: _accumulatedDistanceMeters,
    ));

    notifyListeners();
  }

  /// Records a tracker state transition ('started', 'stopped', 'paused', 'resumed').
  void recordTrackerState(
    String state, [
    String? details,
    double? restoredDistanceMeters,
  ]) {
    _trackerState = state;
    if (state == 'started') {
      _accumulatedDistanceMeters = 0.0;
      _acceptedCount = 0;
      _rejectedCount = 0;
      _lastFixTime = null;
    } else if (state == 'resumed' && restoredDistanceMeters != null) {
      _accumulatedDistanceMeters = restoredDistanceMeters;
      _lastFixTime = null;
    }
    _insertEvent(TrackingEvent.trackerState(
      timestamp: DateTime.now().toUtc(),
      state: state,
      details: details,
    ));
    notifyListeners();
  }

  /// Records a Flutter application lifecycle state transition.
  void recordLifecycleChange(String lifecycleState) {
    _insertEvent(TrackingEvent.lifecycle(
      timestamp: DateTime.now().toUtc(),
      lifecycleState: lifecycleState,
    ));
    notifyListeners();
  }

  /// Records an off-route state transition (`OFF_ROUTE` or `ON_ROUTE`) with UTC timestamp,
  /// cross-track distance, horizontal accuracy, and diagnostic reason.
  void recordOffRouteStateChange({
    required DateTime timestamp,
    required bool isOffRoute,
    required double crossTrackMeters,
    required double? accuracy,
    required String reason,
  }) {
    _insertEvent(TrackingEvent.offRoute(
      timestamp: timestamp,
      isOffRoute: isOffRoute,
      crossTrackMeters: crossTrackMeters,
      accuracy: accuracy,
      reason: reason,
    ));
    notifyListeners();
  }

  /// Records a navigation reroute outcome (`ACCEPTED` or `DISCARDED`) with UTC timestamp,
  /// cross-track distance, horizontal accuracy, heading, and reason.
  void recordReroute({
    required DateTime timestamp,
    required double crossTrackMeters,
    required double? accuracy,
    required bool accepted,
    required String reason,
    double? heading,
    String? headingSource,
  }) {
    _insertEvent(TrackingEvent.reroute(
      timestamp: timestamp,
      crossTrackMeters: crossTrackMeters,
      accuracy: accuracy,
      accepted: accepted,
      reason: reason,
      heading: heading,
      headingSource: headingSource,
    ));
    notifyListeners();
  }

  /// Resets in-memory diagnostics log and counters.
  void clear() {
    _events.clear();
    _accumulatedDistanceMeters = 0.0;
    _acceptedCount = 0;
    _rejectedCount = 0;
    _lastFixTime = null;
    notifyListeners();
  }

  /// Internal helper inserting an event at index 0 and enforcing the 500-event cap.
  void _insertEvent(TrackingEvent event) {
    _events.insert(0, event);
    while (_events.length > maxEvents) {
      _events.removeLast();
    }
  }

  /// Computes aggregate summary statistics over the recorded fix events.
  TrackingDiagnosticsSummary computeSummary({
    double maxAccuracyMeters = MotionMath.maxAccuracyMeters,
  }) {
    final fixEvents = _events
        .where((e) => e.type == TrackingEventType.fix)
        .toList()
        .reversed
        .toList();

    final totalFixes = fixEvents.length;
    if (totalFixes == 0) {
      return const TrackingDiagnosticsSummary(
        totalFixes: 0,
        accuracyRejectedFixes: 0,
        percentRejectedForAccuracy: 0.0,
        medianAccuracyMeters: null,
        validReportedSpeedFixes: 0,
        percentValidReportedSpeed: 0.0,
        longestGapWithoutAcceptedSeconds: 0.0,
        maxCalculatedSpeedAcceptedMps: 0.0,
      );
    }

    int accuracyRejected = 0;
    int validSpeedCount = 0;
    final List<double> accuracies = [];
    double maxCalcSpeedAccepted = 0.0;

    for (final fix in fixEvents) {
      if (fix.accuracy != null) {
        accuracies.add(fix.accuracy!);
      }
      if (fix.isRejected &&
          ((fix.reason?.startsWith('Accuracy filter') ?? false) ||
              (fix.accuracy != null && fix.accuracy! > maxAccuracyMeters))) {
        accuracyRejected++;
      }
      if (fix.isReportedSpeedValid) {
        validSpeedCount++;
      }
      if (fix.isAccepted && fix.calculatedSpeed != null) {
        if (fix.calculatedSpeed! > maxCalcSpeedAccepted) {
          maxCalcSpeedAccepted = fix.calculatedSpeed!;
        }
      }
    }

    double? medianAccuracy;
    if (accuracies.isNotEmpty) {
      accuracies.sort();
      final mid = accuracies.length ~/ 2;
      if (accuracies.length.isOdd) {
        medianAccuracy = accuracies[mid];
      } else {
        medianAccuracy = (accuracies[mid - 1] + accuracies[mid]) / 2.0;
      }
    }

    double longestGapWithoutAccepted = 0.0;
    final acceptedFixes = fixEvents.where((e) => e.isAccepted).toList();
    if (acceptedFixes.isEmpty) {
      longestGapWithoutAccepted = math.max(
        0.0,
        MotionMath.elapsedSecondsBetween(
          fixEvents.first.timestamp,
          fixEvents.last.timestamp,
        ),
      );
    } else {
      // Gap before first accepted fix
      longestGapWithoutAccepted = math.max(
        longestGapWithoutAccepted,
        MotionMath.elapsedSecondsBetween(
          fixEvents.first.timestamp,
          acceptedFixes.first.timestamp,
        ),
      );
      // Gaps between consecutive accepted fixes
      for (int i = 0; i < acceptedFixes.length - 1; i++) {
        final gapSec = MotionMath.elapsedSecondsBetween(
          acceptedFixes[i].timestamp,
          acceptedFixes[i + 1].timestamp,
        );
        longestGapWithoutAccepted = math.max(longestGapWithoutAccepted, gapSec);
      }
      // Gap after last accepted fix
      longestGapWithoutAccepted = math.max(
        longestGapWithoutAccepted,
        MotionMath.elapsedSecondsBetween(
          acceptedFixes.last.timestamp,
          fixEvents.last.timestamp,
        ),
      );
      // Also account for explicit elapsedSeconds on any fix event
      for (final fix in fixEvents) {
        if (fix.elapsedSeconds != null &&
            fix.elapsedSeconds! > longestGapWithoutAccepted) {
          longestGapWithoutAccepted = fix.elapsedSeconds!;
        }
      }
    }

    return TrackingDiagnosticsSummary(
      totalFixes: totalFixes,
      accuracyRejectedFixes: accuracyRejected,
      percentRejectedForAccuracy: (accuracyRejected / totalFixes) * 100.0,
      medianAccuracyMeters: medianAccuracy,
      validReportedSpeedFixes: validSpeedCount,
      percentValidReportedSpeed: (validSpeedCount / totalFixes) * 100.0,
      longestGapWithoutAcceptedSeconds: longestGapWithoutAccepted,
      maxCalculatedSpeedAcceptedMps: maxCalcSpeedAccepted,
    );
  }

  /// Generates a complete plain-text export of the current diagnostic state and log.
  ///
  /// All timestamps are formatted as UTC ISO-8601 strings with a `'Z'` suffix.
  /// If [oldestFirst] is true, events are formatted chronologically (oldest first),
  /// which is suitable for file export where the ride starts at the top. Defaults
  /// to false (newest first), matching the in-memory display and clipboard copy.
  String formatLogAsPlainText({
    double maxAccuracyMeters = MotionMath.maxAccuracyMeters,
    double minDistanceMeters = 5.0,
    double minSpeedMps = 1.0,
    double maxSpeedMps = 55.56,
    bool? gpsOnlyLocationProvider,
    bool oldestFirst = false,
  }) {
    final summary = computeSummary(maxAccuracyMeters: maxAccuracyMeters);
    final useGpsOnly = gpsOnlyLocationProvider ??
        SettingsController.instance.gpsOnlyLocationProvider;
    final providerModeLabel = useGpsOnly
        ? 'GPS-only (experimental, forceLocationManager: true)'
        : 'Fused Location Provider (default, forceLocationManager: false)';
    final medianAccStr = summary.medianAccuracyMeters != null
        ? '${summary.medianAccuracyMeters!.toStringAsFixed(1)} m'
        : 'N/A';

    final orderLabel = oldestFirst ? 'oldest first' : 'newest first';
    final buffer = StringBuffer()
      ..writeln('=== CAMP TRACKING DIAGNOSTICS LOG ===')
      ..writeln('Generated: ${MotionMath.formatUtcIso8601(DateTime.now())}')
      ..writeln('Location Provider Mode: $providerModeLabel')
      ..writeln('Tracker State: $_trackerState')
      ..writeln(
          'Accumulated Distance: ${_accumulatedDistanceMeters.toStringAsFixed(1)} m (${(_accumulatedDistanceMeters / 1000.0).toStringAsFixed(2)} km)')
      ..writeln('Accepted Fixes: $_acceptedCount')
      ..writeln('Rejected Fixes: $_rejectedCount')
      ..writeln(
          'Last Fix: ${_lastFixTime != null ? MotionMath.formatUtcIso8601(_lastFixTime!) : 'None'} (${secondsSinceLastFix ?? 0}s ago)')
      ..writeln()
      ..writeln('=== SUMMARY ===')
      ..writeln('- Total Fixes: ${summary.totalFixes}')
      ..writeln(
          '- Rejected for Accuracy: ${summary.percentRejectedForAccuracy.toStringAsFixed(1)}% (${summary.accuracyRejectedFixes} / ${summary.totalFixes})')
      ..writeln('- Median Accuracy: $medianAccStr')
      ..writeln(
          '- Valid Reported Speed: ${summary.percentValidReportedSpeed.toStringAsFixed(1)}% (${summary.validReportedSpeedFixes} / ${summary.totalFixes})')
      ..writeln(
          '- Longest Gap Without Accepted Fix: ${summary.longestGapWithoutAcceptedSeconds.toStringAsFixed(1)} s')
      ..writeln(
          '- Max Calculated Speed (Accepted): ${summary.maxCalculatedSpeedAcceptedMps.toStringAsFixed(2)} m/s (${summary.maxCalculatedSpeedAcceptedKmh.toStringAsFixed(1)} km/h)')
      ..writeln()
      ..writeln('=== FILTER THRESHOLDS ===')
      ..writeln('- Max Accuracy: ${maxAccuracyMeters.toStringAsFixed(1)} m')
      ..writeln('- Min Distance: ${minDistanceMeters.toStringAsFixed(1)} m')
      ..writeln(
          '- Min Speed: ${minSpeedMps.toStringAsFixed(1)} m/s (${(minSpeedMps * 3.6).toStringAsFixed(1)} km/h)')
      ..writeln(
          '- Max Speed: ${maxSpeedMps.toStringAsFixed(2)} m/s (${(maxSpeedMps * 3.6).toStringAsFixed(1)} km/h)')
      ..writeln()
      ..writeln(
          '=== EVENTS (${_events.length} of $maxEvents, $orderLabel) ===');

    if (_events.isEmpty) {
      buffer.writeln('No events recorded.');
    } else {
      final eventsToFormat = oldestFirst ? _events.reversed.toList() : _events;
      for (final event in eventsToFormat) {
        final timeStr = event.formattedTimestampUtc;
        switch (event.type) {
          case TrackingEventType.fix:
            final statusStr = event.isAccepted ? 'ACCEPTED' : 'REJECTED';
            final passedStr = event.segmentPassed ? 'yes' : 'no';
            buffer.writeln(
              '[$timeStr] [$statusStr] '
              'PrevTime: ${event.formattedPreviousAcceptedTimestampUtc} | '
              'dt: ${event.formattedElapsedSeconds} | '
              'DistFromPrev: ${event.formattedDistanceFromPreviousAccepted} | '
              'Lat: ${event.formattedLatitude}, Lng: ${event.formattedLongitude} | '
              'PrevAcc: ${event.formattedPreviousAccuracy} | '
              'Acc: ${event.formattedAccuracy} | '
              'Spd: ${event.formattedSpeed} [${event.formattedReportedSpeedValidity}] | '
              'CalcSpd: ${event.formattedCalculatedSpeed} | '
              'Passed: $passedStr | '
              'Reason: ${event.reason ?? ''}'
              '${event.isAccepted ? ' | +${event.segmentMeters?.toStringAsFixed(1)}m (Total: ${event.accumulatedMeters?.toStringAsFixed(1)}m)' : ''}',
            );
            break;
          case TrackingEventType.gap:
            buffer.writeln(
              '[$timeStr] [GAP] ⚠️ ${event.gapDuration?.inSeconds}s elapsed between fixes',
            );
            break;
          case TrackingEventType.trackerState:
            buffer.writeln('[$timeStr] [TRACKER_STATE] ${event.message}');
            break;
          case TrackingEventType.lifecycle:
            buffer.writeln('[$timeStr] [LIFECYCLE] ${event.message}');
            break;
          case TrackingEventType.offRoute:
            buffer.writeln('[$timeStr] [OFF_ROUTE] ${event.message}');
            break;
          case TrackingEventType.reroute:
            buffer.writeln('[$timeStr] [REROUTE] ${event.message}');
            break;
        }
      }
    }

    return buffer.toString();
  }
}
