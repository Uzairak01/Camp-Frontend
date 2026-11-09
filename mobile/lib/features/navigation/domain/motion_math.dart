import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'location_service.dart';

/// Shared pure utility class for GPS fix accuracy gating, great-circle distance,
/// elapsed time, calculated speed, and UTC ISO-8601 timestamp formatting.
///
/// Used uniformly by `NavigationController`, `FuelTrackerService`, and
/// `TrackingDiagnostics` so that the map dot, speedometer, ride tracker, and
/// diagnostic log share a single source of truth for location math.
class MotionMath {
  const MotionMath._();

  /// Maximum horizontal accuracy in meters for a GPS fix to be considered trustworthy.
  /// Fixes with `accuracy > 30.0` m are rejected by both the ride tracker and map/speed pipeline.
  static const double maxAccuracyMeters = 30.0;

  /// Returns `true` when [accuracy] is within [maxAccuracy] (or `null` when the
  /// platform does not report horizontal error).
  static bool isGoodAccuracy(
    double? accuracy, {
    double maxAccuracy = maxAccuracyMeters,
  }) {
    return accuracy == null || accuracy <= maxAccuracy;
  }

  /// Returns `true` when [fix] has horizontal accuracy `<= maxAccuracyMeters` (30 m).
  static bool isGoodFix(
    PositionData fix, {
    double maxAccuracy = maxAccuracyMeters,
  }) {
    return isGoodAccuracy(fix.accuracy, maxAccuracy: maxAccuracy);
  }

  /// Computes great-circle distance in meters between two [PositionData] fixes.
  static double distanceMeters(PositionData a, PositionData b) {
    return Geolocator.distanceBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
  }

  /// Computes great-circle distance in meters between two [LatLng] coordinates.
  static double distanceBetweenPoints(LatLng a, LatLng b) {
    return Geolocator.distanceBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
  }

  /// Computes elapsed time in seconds (`current - previous`) between two fixes.
  static double elapsedSeconds(PositionData previous, PositionData current) {
    return elapsedSecondsBetween(previous.timestamp, current.timestamp);
  }

  /// Computes elapsed time in seconds (`current - previous`) between two timestamps.
  static double elapsedSecondsBetween(DateTime previous, DateTime current) {
    return current.difference(previous).inMilliseconds / 1000.0;
  }

  /// Calculates speed in meters per second (`distance / dt`) between [previous]
  /// and [current], or returns `null` if elapsed time is `<= 0`.
  static double? calculatedSpeedMps(
    PositionData previous,
    PositionData current,
  ) {
    final dt = elapsedSeconds(previous, current);
    if (dt <= 0) return null;
    final dist = distanceMeters(previous, current);
    return dist / dt;
  }

  /// Calculates speed in meters per second (`distance / dt`) between [previous]
  /// and [current], returning `0.0` if elapsed time is `<= 0`.
  static double calculatedSpeedMpsOrZero(
    PositionData previous,
    PositionData current,
  ) {
    return calculatedSpeedMps(previous, current) ?? 0.0;
  }

  /// Formats [timestamp] as a UTC ISO-8601 string with a trailing `'Z'` suffix.
  static String formatUtcIso8601(DateTime timestamp) {
    return timestamp.toUtc().toIso8601String();
  }
}

