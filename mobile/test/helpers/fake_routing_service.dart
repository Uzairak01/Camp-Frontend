import 'package:camp/features/navigation/domain/routing_service.dart';
import 'package:latlong2/latlong.dart';

/// Captured parameters from a single [FakeRoutingService.getRoute] invocation.
class FakeRouteRequest {
  const FakeRouteRequest({
    required this.waypoints,
    required this.requestAlternatives,
    required this.startBearingDegrees,
    required this.startBearingToleranceDegrees,
    required this.startRadiusMeters,
  });

  final List<LatLng> waypoints;
  final bool requestAlternatives;
  final double? startBearingDegrees;
  final double startBearingToleranceDegrees;
  final double? startRadiusMeters;
}

/// Fake implementation of [RoutingService] for unit and widget testing.
class FakeRoutingService implements RoutingService {
  FakeRoutingService({
    this.cannedResult,
    this.shouldThrow = false,
    this.errorMessage = 'Route needs an internet connection',
  });

  RouteResult? cannedResult;
  bool shouldThrow;
  String errorMessage;
  int callCount = 0;
  final List<FakeRouteRequest> requests = [];
  List<LatLng>? lastWaypoints;
  bool? lastRequestAlternatives;
  double? lastStartBearingDegrees;
  Future<RouteResult> Function({
    required List<LatLng> waypoints,
    bool requestAlternatives,
    double? startBearingDegrees,
    double startBearingToleranceDegrees,
    double? startRadiusMeters,
  })? onGetRoute;

  @override
  Future<RouteResult> getRoute({
    required List<LatLng> waypoints,
    bool requestAlternatives = true,
    double? startBearingDegrees,
    double startBearingToleranceDegrees = 45.0,
    double? startRadiusMeters,
  }) async {
    callCount++;
    final copiedWaypoints = List<LatLng>.from(waypoints);
    lastWaypoints = copiedWaypoints;
    lastRequestAlternatives = requestAlternatives;
    lastStartBearingDegrees = startBearingDegrees;
    requests.add(
      FakeRouteRequest(
        waypoints: copiedWaypoints,
        requestAlternatives: requestAlternatives,
        startBearingDegrees: startBearingDegrees,
        startBearingToleranceDegrees: startBearingToleranceDegrees,
        startRadiusMeters: startRadiusMeters,
      ),
    );

    if (onGetRoute != null) {
      return onGetRoute!(
        waypoints: waypoints,
        requestAlternatives: requestAlternatives,
        startBearingDegrees: startBearingDegrees,
        startBearingToleranceDegrees: startBearingToleranceDegrees,
        startRadiusMeters: startRadiusMeters,
      );
    }

    if (shouldThrow) {
      throw Exception(errorMessage);
    }

    if (cannedResult != null) {
      return cannedResult!;
    }

    // Generate a simple synthetic route between the waypoints
    final start = waypoints.first;
    final end = waypoints.last;
    final mid = LatLng(
      (start.latitude + end.latitude) / 2 + 0.005,
      (start.longitude + end.longitude) / 2 + 0.005,
    );

    final line = [start, mid, end];
    return RouteResult(
      polyline: line,
      distanceMeters: 5400.0,
      durationSeconds: 660.0, // 11 min
      steps: [
        RouteStep(
          maneuverType: 'depart',
          streetName: 'Test Way',
          distanceMeters: 1600.0,
          durationSeconds: 180.0,
          location: start,
          instruction: 'Head out on Test Way',
        ),
        RouteStep(
          maneuverType: 'turn',
          maneuverModifier: 'right',
          streetName: 'Test Pass Rd',
          distanceMeters: 3800.0,
          durationSeconds: 480.0,
          location: mid,
          instruction: 'Turn right onto Test Pass Rd',
        ),
        RouteStep(
          maneuverType: 'arrive',
          streetName: 'Destination',
          distanceMeters: 0.0,
          durationSeconds: 0.0,
          location: end,
          instruction: 'Arrive at destination',
        ),
      ],
    );
  }
}
