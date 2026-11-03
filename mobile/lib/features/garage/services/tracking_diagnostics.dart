import 'package:flutter/foundation.dart';

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
}

/// Immutable record of a single tracking diagnostic event.
class TrackingEvent {
  const TrackingEvent({
    required this.timestamp,
    required this.type,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.speed,
    this.reportedSpeedValid,
    this.calculatedSpeed,
    this.status,
    this.reason,
    this.segmentMeters,
    this.accumulatedMeters,
    this.gapDuration,
    this.message,
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
    bool? reportedSpeedValid,
    double? calculatedSpeed,
    double segmentMeters = 0.0,
    double accumulatedMeters = 0.0,
  }) {
    return TrackingEvent(
      timestamp: timestamp,
      type: TrackingEventType.fix,
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
      timestamp: timestamp,
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
      timestamp: timestamp,
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
      timestamp: timestamp,
      type: TrackingEventType.lifecycle,
      message: 'AppLifecycleState.$lifecycleState',
    );
  }

  /// Wall-clock time when the event occurred.
  final DateTime timestamp;

  /// Nature of the recorded event.
  final TrackingEventType type;

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

  bool get isGap => type == TrackingEventType.gap;
  bool get isRejected => status == TrackingFixStatus.rejected;
  bool get isAccepted => status == TrackingFixStatus.accepted;

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

  /// Timestamp of the most recent location fix received.
  DateTime? get lastFixTime => _lastFixTime;

  /// Number of seconds elapsed since the last location fix was received.
  int? get secondsSinceLastFix {
    if (_lastFixTime == null) return null;
    return DateTime.now().difference(_lastFixTime!).inSeconds;
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
    bool? reportedSpeedValid,
    double? calculatedSpeed,
    double segmentMeters = 0.0,
  }) {
    // 1. Detect gap since previous fix (>30 seconds)
    if (_lastFixTime != null) {
      final gap = timestamp.difference(_lastFixTime!);
      if (gap.inSeconds > 30) {
        _insertEvent(TrackingEvent.gap(
          timestamp: timestamp,
          gapDuration: gap,
        ));
      }
    }
    _lastFixTime = timestamp;

    // 2. Update metric counters
    if (accepted) {
      _acceptedCount++;
      _accumulatedDistanceMeters += segmentMeters;
    } else {
      _rejectedCount++;
    }

    // 3. Record fix event
    _insertEvent(TrackingEvent.fix(
      timestamp: timestamp,
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
      timestamp: DateTime.now(),
      state: state,
      details: details,
    ));
    notifyListeners();
  }

  /// Records a Flutter application lifecycle state transition.
  void recordLifecycleChange(String lifecycleState) {
    _insertEvent(TrackingEvent.lifecycle(
      timestamp: DateTime.now(),
      lifecycleState: lifecycleState,
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

  /// Generates a complete plain-text export of the current diagnostic state and log.
  String formatLogAsPlainText({
    double maxAccuracyMeters = 30.0,
    double minDistanceMeters = 5.0,
    double minSpeedMps = 1.0,
    double maxSpeedMps = 55.56,
  }) {
    final buffer = StringBuffer()
      ..writeln('=== CAMP TRACKING DIAGNOSTICS LOG ===')
      ..writeln('Generated: ${DateTime.now().toIso8601String()}')
      ..writeln('Tracker State: $_trackerState')
      ..writeln('Accumulated Distance: ${_accumulatedDistanceMeters.toStringAsFixed(1)} m (${(_accumulatedDistanceMeters / 1000.0).toStringAsFixed(2)} km)')
      ..writeln('Accepted Fixes: $_acceptedCount')
      ..writeln('Rejected Fixes: $_rejectedCount')
      ..writeln('Last Fix: ${_lastFixTime != null ? _lastFixTime!.toIso8601String() : 'None'} (${secondsSinceLastFix ?? 0}s ago)')
      ..writeln()
      ..writeln('=== FILTER THRESHOLDS ===')
      ..writeln('- Max Accuracy: ${maxAccuracyMeters.toStringAsFixed(1)} m')
      ..writeln('- Min Distance: ${minDistanceMeters.toStringAsFixed(1)} m')
      ..writeln('- Min Speed: ${minSpeedMps.toStringAsFixed(1)} m/s (${(minSpeedMps * 3.6).toStringAsFixed(1)} km/h)')
      ..writeln('- Max Speed: ${maxSpeedMps.toStringAsFixed(2)} m/s (${(maxSpeedMps * 3.6).toStringAsFixed(1)} km/h)')
      ..writeln()
      ..writeln('=== EVENTS (${_events.length} of $maxEvents, newest first) ===');

    if (_events.isEmpty) {
      buffer.writeln('No events recorded.');
    } else {
      for (final event in _events) {
        final timeStr = event.timestamp.toIso8601String();
        switch (event.type) {
          case TrackingEventType.fix:
            final statusStr = event.isAccepted ? 'ACCEPTED' : 'REJECTED';
            buffer.writeln(
              '[$timeStr] [$statusStr] '
              'Lat: ${event.formattedLatitude}, Lng: ${event.formattedLongitude} | '
              'Acc: ${event.formattedAccuracy} | '
              'Spd: ${event.formattedSpeed} [${event.formattedReportedSpeedValidity}] | '
              'CalcSpd: ${event.formattedCalculatedSpeed} | '
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
        }
      }
    }

    return buffer.toString();
  }
}

