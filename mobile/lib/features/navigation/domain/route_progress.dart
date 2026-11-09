import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'motion_math.dart';
import 'routing_service.dart';

/// Immutable result of projecting a rider's GPS fix onto a route polyline.
class RouteSnapResult {
  /// Creates a route snap result.
  const RouteSnapResult({
    required this.snappedPoint,
    required this.alongRouteMeters,
    required this.crossTrackMeters,
    required this.segmentIndex,
    required this.segmentBearingDegrees,
    required this.rawAlongRouteMeters,
  });

  /// Closest point on the route corresponding to [alongRouteMeters].
  final LatLng snappedPoint;

  /// Monotonic distance in meters along the route from the polyline start.
  final double alongRouteMeters;

  /// Perpendicular (cross-track) distance in meters from the fix to the route segment.
  final double crossTrackMeters;

  /// Zero-based index of the matched segment `[segmentIndex, segmentIndex + 1]`.
  final int segmentIndex;

  /// Forward compass bearing in degrees (`0..360`, clockwise from North) of the matched segment.
  final double segmentBearingDegrees;

  /// Unclamped along-route projection distance before monotonic clamping.
  final double rawAlongRouteMeters;
}

/// Pure geometric helper for snapping GPS fixes onto a route polyline,
/// maintaining monotonic along-route progress, computing step end distances,
/// trimming rerouted polylines, and detecting hook/U-turn spurs.
class RouteProgress {
  const RouteProgress._();

  /// Maximum backward distance in meters allowed when searching segments relative to last progress.
  static const double maxBackwardSlackMeters = 20.0;

  /// Default forward search window in meters ahead of last progress.
  static const double defaultForwardWindowMeters = 1200.0;

  /// Minimum cross-track distance threshold in meters for snapping the map dot (`max(30 m, accuracy)`).
  static const double minSnapCrossTrackMeters = 30.0;

  /// Distance threshold in meters before a step end at which the step advances automatically.
  static const double stepAdvanceThresholdMeters = 15.0;

  /// Minimum cross-track distance threshold in meters for off-route detection (`max(40 m, 2 * accuracy)`).
  static const double minOffRouteCrossTrackMeters = 40.0;

  /// Computes cumulative geodesic distances in meters along [polyline].
  ///
  /// Returns a list of the same length as [polyline] starting with `0.0`
  /// (or an empty list if [polyline] is empty).
  static List<double> computeCumulativeDistances(List<LatLng> polyline) {
    if (polyline.isEmpty) return const [];
    final cumulative = List<double>.filled(polyline.length, 0.0);
    double total = 0.0;
    for (int i = 1; i < polyline.length; i++) {
      total += MotionMath.distanceBetweenPoints(polyline[i - 1], polyline[i]);
      cumulative[i] = total;
    }
    return cumulative;
  }

  /// Computes the cumulative along-route distance in meters at the end of each step in [steps].
  ///
  /// The end of step `i` is the along-route projection of `steps[i + 1].location`
  /// (the maneuver point starting the next step), and the end of the final step
  /// is the end of the polyline.
  static List<double> computeStepEndDistances({
    required List<LatLng> polyline,
    required List<double> cumulativeDistances,
    required List<RouteStep> steps,
  }) {
    if (steps.isEmpty) return const [];
    final totalPolyDist =
        cumulativeDistances.isNotEmpty ? cumulativeDistances.last : 0.0;
    if (polyline.length < 2 || totalPolyDist <= 0.0) {
      final result = <double>[];
      double running = 0.0;
      for (final step in steps) {
        running += step.distanceMeters;
        result.add(running);
      }
      return result;
    }

    final ends = List<double>.filled(steps.length, totalPolyDist);
    double searchStartMeters = 0.0;

    for (int i = 0; i < steps.length - 1; i++) {
      final nextManeuverLoc = steps[i + 1].location;
      final snap = snapToRoute(
        polyline: polyline,
        cumulativeDistances: cumulativeDistances,
        point: nextManeuverLoc,
        lastAlongRouteMeters: searchStartMeters,
        maxBackwardSlackMeters: 0.0,
        searchEntirePolyline: true,
      );

      double stepEnd = snap.alongRouteMeters;
      // Fallback if synthetic step locations are identical while step distance is positive
      if (stepEnd <= searchStartMeters && steps[i].distanceMeters > 0) {
        stepEnd = math.min(
          totalPolyDist,
          searchStartMeters + steps[i].distanceMeters,
        );
      }
      ends[i] = stepEnd;
      searchStartMeters = stepEnd;
    }

    ends[steps.length - 1] = totalPolyDist;
    return ends;
  }

  /// Projects [point] onto [polyline] within a forward window of [lastAlongRouteMeters]
  /// (allowing at most [maxBackwardSlackMeters] backwards) and enforces monotonic progress.
  static RouteSnapResult snapToRoute({
    required List<LatLng> polyline,
    required LatLng point,
    List<double>? cumulativeDistances,
    double lastAlongRouteMeters = 0.0,
    double maxBackwardSlackMeters = RouteProgress.maxBackwardSlackMeters,
    double forwardWindowMeters = RouteProgress.defaultForwardWindowMeters,
    bool searchEntirePolyline = false,
  }) {
    if (polyline.isEmpty) {
      return RouteSnapResult(
        snappedPoint: point,
        alongRouteMeters: lastAlongRouteMeters,
        crossTrackMeters: double.infinity,
        segmentIndex: 0,
        segmentBearingDegrees: 0.0,
        rawAlongRouteMeters: lastAlongRouteMeters,
      );
    }

    final cumDist = cumulativeDistances != null &&
            cumulativeDistances.length == polyline.length
        ? cumulativeDistances
        : computeCumulativeDistances(polyline);

    if (polyline.length == 1) {
      final d = MotionMath.distanceBetweenPoints(point, polyline.first);
      return RouteSnapResult(
        snappedPoint: polyline.first,
        alongRouteMeters: lastAlongRouteMeters,
        crossTrackMeters: d,
        segmentIndex: 0,
        segmentBearingDegrees: 0.0,
        rawAlongRouteMeters: 0.0,
      );
    }

    final minAllowedAlong =
        math.max(0.0, lastAlongRouteMeters - maxBackwardSlackMeters);
    final maxWindowAlong = searchEntirePolyline
        ? double.infinity
        : (lastAlongRouteMeters + forwardWindowMeters);

    _SegmentProjection? best = _findBestSegmentInRange(
      polyline: polyline,
      cumDist: cumDist,
      point: point,
      minAlong: minAllowedAlong,
      maxAlong: maxWindowAlong,
    );

    // If the rider jumped ahead of the local window (e.g. after a long GPS dropout),
    // search all remaining forward segments without allowing backward movement > 20 m.
    if (!searchEntirePolyline && (best == null || best.crossTrackMeters > 50.0)) {
      final forwardFallback = _findBestSegmentInRange(
        polyline: polyline,
        cumDist: cumDist,
        point: point,
        minAlong: minAllowedAlong,
        maxAlong: double.infinity,
      );
      if (forwardFallback != null &&
          (best == null ||
              forwardFallback.crossTrackMeters < best.crossTrackMeters)) {
        best = forwardFallback;
      }
    }

    // Ultimate fallback if lastAlongRouteMeters was already at the very end of the polyline
    best ??= _findBestSegmentInRange(
      polyline: polyline,
      cumDist: cumDist,
      point: point,
      minAlong: 0.0,
      maxAlong: double.infinity,
    )!;

    // Enforce monotonic progress: along-route distance never decreases.
    final monotonicAlong = math.max(lastAlongRouteMeters, best.rawAlongMeters);
    final snappedPt = monotonicAlong > best.rawAlongMeters
        ? interpolateAtDistance(polyline, cumDist, monotonicAlong)
        : best.projectedPoint;
    final segIndex = monotonicAlong > best.rawAlongMeters
        ? findSegmentIndexAtDistance(cumDist, monotonicAlong)
        : best.segmentIndex;
    final bearing = _segmentBearingAt(polyline, segIndex);

    return RouteSnapResult(
      snappedPoint: snappedPt,
      alongRouteMeters: monotonicAlong,
      crossTrackMeters: best.crossTrackMeters,
      segmentIndex: segIndex,
      segmentBearingDegrees: bearing,
      rawAlongRouteMeters: best.rawAlongMeters,
    );
  }

  static _SegmentProjection? _findBestSegmentInRange({
    required List<LatLng> polyline,
    required List<double> cumDist,
    required LatLng point,
    required double minAlong,
    required double maxAlong,
  }) {
    _SegmentProjection? best;

    for (int i = 0; i < polyline.length - 1; i++) {
      final segStartAlong = cumDist[i];
      final segEndAlong = cumDist[i + 1];

      // Skip segments completely outside [minAlong, maxAlong]
      if (segEndAlong < minAlong || segStartAlong > maxAlong) {
        continue;
      }

      final segLen = segEndAlong - segStartAlong;
      final a = polyline[i];
      final b = polyline[i + 1];

      double minT = 0.0;
      double maxT = 1.0;
      if (segLen > 0) {
        if (segStartAlong < minAlong) {
          minT = ((minAlong - segStartAlong) / segLen).clamp(0.0, 1.0);
        }
        if (segEndAlong > maxAlong) {
          maxT = ((maxAlong - segStartAlong) / segLen).clamp(0.0, 1.0);
        }
      }
      if (minT > maxT) continue;

      final proj = _projectOntoSegment(point, a, b, minT: minT, maxT: maxT);
      final rawAlong = segStartAlong + proj.t * segLen;
      final crossTrack =
          MotionMath.distanceBetweenPoints(point, proj.projectedPoint);

      if (best == null || crossTrack < best.crossTrackMeters) {
        best = _SegmentProjection(
          segmentIndex: i,
          t: proj.t,
          projectedPoint: proj.projectedPoint,
          rawAlongMeters: rawAlong,
          crossTrackMeters: crossTrack,
        );
      }
    }

    return best;
  }

  static ({double t, LatLng projectedPoint}) _projectOntoSegment(
    LatLng p,
    LatLng a,
    LatLng b, {
    double minT = 0.0,
    double maxT = 1.0,
  }) {
    final latP = p.latitudeInRad;
    final lonP = p.longitudeInRad;
    final latA = a.latitudeInRad;
    final lonA = a.longitudeInRad;
    final latB = b.latitudeInRad;
    final lonB = b.longitudeInRad;

    final cosMeanLat = math.cos((latA + latB) / 2.0);
    final dx = (lonB - lonA) * cosMeanLat;
    final dy = latB - latA;
    final segLenSq = dx * dx + dy * dy;

    if (segLenSq <= 1e-18) {
      return (t: minT, projectedPoint: a);
    }

    final px = (lonP - lonA) * cosMeanLat;
    final py = latP - latA;
    final rawT = (px * dx + py * dy) / segLenSq;
    final t = rawT.clamp(minT, maxT);

    final projLat = (latA + t * (latB - latA)) * (180.0 / math.pi);
    final projLon = (lonA + t * (lonB - lonA)) * (180.0 / math.pi);
    return (t: t, projectedPoint: LatLng(projLat, projLon));
  }

  /// Interpolates the coordinate along [polyline] at [distanceMeters] from the start.
  static LatLng interpolateAtDistance(
    List<LatLng> polyline,
    List<double> cumDist,
    double distanceMeters,
  ) {
    if (polyline.isEmpty) return const LatLng(0, 0);
    if (polyline.length == 1 || distanceMeters <= 0.0) return polyline.first;
    final total = cumDist.last;
    if (distanceMeters >= total) return polyline.last;

    final idx = findSegmentIndexAtDistance(cumDist, distanceMeters);
    final segStart = cumDist[idx];
    final segLen = cumDist[idx + 1] - segStart;
    if (segLen <= 0.0) return polyline[idx];

    final t = ((distanceMeters - segStart) / segLen).clamp(0.0, 1.0);
    final a = polyline[idx];
    final b = polyline[idx + 1];
    return LatLng(
      a.latitude + t * (b.latitude - a.latitude),
      a.longitude + t * (b.longitude - a.longitude),
    );
  }

  /// Finds the segment index `i` such that `cumDist[i] <= distanceMeters <= cumDist[i + 1]`.
  static int findSegmentIndexAtDistance(
    List<double> cumDist,
    double distanceMeters,
  ) {
    if (cumDist.length < 2) return 0;
    for (int i = 0; i < cumDist.length - 1; i++) {
      if (distanceMeters <= cumDist[i + 1]) {
        return i;
      }
    }
    return cumDist.length - 2;
  }

  /// Computes the active step index for a given [alongRouteMeters] and [stepEndDistances].
  static int findStepIndexAtAlongDistance({
    required List<double> stepEndDistances,
    required double alongRouteMeters,
    double advanceThresholdMeters = stepAdvanceThresholdMeters,
  }) {
    if (stepEndDistances.isEmpty) return 0;
    for (int i = 0; i < stepEndDistances.length - 1; i++) {
      final remToStepEnd = stepEndDistances[i] - alongRouteMeters;
      if (remToStepEnd >= advanceThresholdMeters &&
          alongRouteMeters < stepEndDistances[i]) {
        return i;
      }
    }
    return stepEndDistances.length - 1;
  }

  /// Trims the leading points of [polyline] so that it begins directly at [snap.snappedPoint].
  static List<LatLng> trimPolylineFromSnap(
    List<LatLng> polyline,
    RouteSnapResult snap,
  ) {
    if (polyline.length < 2) return List<LatLng>.from(polyline);
    final nextVertexIndex = (snap.segmentIndex + 1).clamp(1, polyline.length - 1);
    final trimmed = <LatLng>[snap.snappedPoint];
    for (int i = nextVertexIndex; i < polyline.length; i++) {
      final pt = polyline[i];
      if (MotionMath.distanceBetweenPoints(trimmed.last, pt) > 0.5 ||
          i == polyline.length - 1) {
        trimmed.add(pt);
      }
    }
    if (trimmed.length == 1) {
      trimmed.add(polyline.last);
    }
    return trimmed;
  }

  /// Checks whether the initial [checkDistanceMeters] (default `150 m`) of [polyline]
  /// points more than [maxAngleDiffDegrees] (default `120°`) away from [riderHeadingDegrees].
  ///
  /// Returns the offending angle difference in degrees if a hook/U-turn spur is detected,
  /// or `null` if the route start is aligned with the rider's heading.
  static double? detectHookRouteAngleDegrees({
    required List<LatLng> polyline,
    required double riderHeadingDegrees,
    double checkDistanceMeters = 150.0,
    double maxAngleDiffDegrees = 120.0,
  }) {
    if (polyline.length < 2) return null;
    final cumDist = computeCumulativeDistances(polyline);
    final total = cumDist.last;
    if (total <= 1.0) return null;

    // 1. Check overall bearing from start to the point at min(150 m, total)
    final targetDist = math.min(checkDistanceMeters, total);
    final targetPt = interpolateAtDistance(polyline, cumDist, targetDist);
    final overallBearing = bearingDegrees(polyline.first, targetPt);
    final overallDiff =
        angularDifferenceDegrees(overallBearing, riderHeadingDegrees);
    if (overallDiff > maxAngleDiffDegrees) {
      return overallDiff;
    }

    // 2. Check individual segments within the first 150 m so an initial backwards hook
    // followed by a U-turn within 150 m is also caught.
    for (int i = 0; i < polyline.length - 1; i++) {
      if (cumDist[i] >= checkDistanceMeters) break;
      final segLen = cumDist[i + 1] - cumDist[i];
      if (segLen < 5.0) continue;
      final segBearing = bearingDegrees(polyline[i], polyline[i + 1]);
      final diff = angularDifferenceDegrees(segBearing, riderHeadingDegrees);
      if (diff > maxAngleDiffDegrees) {
        return diff;
      }
    }

    return null;
  }

  /// Computes the forward compass bearing in degrees (`0..360`, clockwise from North)
  /// from [from] to [to].
  static double bearingDegrees(LatLng from, LatLng to) {
    final lat1 = from.latitudeInRad;
    final lat2 = to.latitudeInRad;
    final dLon = to.longitudeInRad - from.longitudeInRad;
    if (lat1 == lat2 && dLon == 0.0) return 0.0;

    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final brng = math.atan2(y, x) * (180.0 / math.pi);
    return (brng + 360.0) % 360.0;
  }

  /// Smallest unsigned angle in degrees (`0..180`) between two compass headings.
  static double angularDifferenceDegrees(double headingA, double headingB) {
    final diff = ((headingA - headingB) % 360.0 + 360.0) % 360.0;
    return diff > 180.0 ? 360.0 - diff : diff;
  }

  static double _segmentBearingAt(List<LatLng> polyline, int segmentIndex) {
    if (polyline.length < 2) return 0.0;
    final idx = segmentIndex.clamp(0, polyline.length - 2);
    for (int i = idx; i < polyline.length - 1; i++) {
      if (MotionMath.distanceBetweenPoints(polyline[i], polyline[i + 1]) >
          0.1) {
        return bearingDegrees(polyline[i], polyline[i + 1]);
      }
    }
    return bearingDegrees(polyline[idx], polyline[idx + 1]);
  }
}

class _SegmentProjection {
  const _SegmentProjection({
    required this.segmentIndex,
    required this.t,
    required this.projectedPoint,
    required this.rawAlongMeters,
    required this.crossTrackMeters,
  });

  final int segmentIndex;
  final double t;
  final LatLng projectedPoint;
  final double rawAlongMeters;
  final double crossTrackMeters;
}

