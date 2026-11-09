import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../../app/theme/app_colors.dart';
import '../../controllers/navigation_controller.dart';
import '../../domain/places_poi_service.dart';

/// Fullscreen interactive map view rendering OpenStreetMap raster tiles,
/// polylines, user GPS indicator (blue dot, accuracy circle, heading cone),
/// and POI markers.
class NavMapView extends StatelessWidget {
  const NavMapView({
    required this.controller,
    required this.mapController,
    this.tileProvider,
    this.onTapMap,
    this.onPositionChanged,
    super.key,
  });

  final NavigationController controller;
  final MapController mapController;
  final TileProvider? tileProvider;
  final VoidCallback? onTapMap;
  final PositionCallback? onPositionChanged;

  static const String _osmStandardUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String _openTopoUrl =
      'https://tile.opentopomap.org/{z}/{x}/{y}.png';

  @override
  Widget build(BuildContext context) {
    final userLoc = controller.userLatLng;
    final heading = controller.currentHeading ?? 0.0;
    final isNavigating = controller.state == NavigationState.navigating;
    final route = controller.route;

    // Use cameraCenter which positions camera using GPS, destination, or Lahore fallback
    final initialCenter = controller.cameraCenter;

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: 15.0,
        minZoom: 3.0,
        maxZoom: 19.0,
        onTap: (_, _) => onTapMap?.call(),
        onPositionChanged: (pos, hasGesture) {
          if (hasGesture) {
            controller.markUserPanned();
          }
          onPositionChanged?.call(pos, hasGesture);
        },
      ),
      children: [
        // 1. Tile Layer
        TileLayer(
          urlTemplate: controller.isTopoLayer ? _openTopoUrl : _osmStandardUrl,
          tileProvider: tileProvider,
          userAgentPackageName: 'com.camp.moto',
          maxZoom: 19,
          errorTileCallback: (tile, error, stackTrace) {},
        ),

        // 2. Polylines Layer (Route)
        if (route != null) ...[
          // Alternate route polyline (subtle gray)
          if (route.alternatePolyline != null &&
              route.alternatePolyline!.isNotEmpty)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: route.alternatePolyline!,
                  strokeWidth: 6.0,
                  color: const Color(0xFF94A3B8).withValues(alpha: 0.7),
                  strokeCap: StrokeCap.round,
                  strokeJoin: StrokeJoin.round,
                ),
              ],
            ),

          // Primary route polyline (tactical orange with smooth border)
          PolylineLayer(
            polylines: [
              // Outer border / glow line
              Polyline(
                points: route.polyline,
                strokeWidth: 9.0,
                color: AppColors.tacticalOrangeDark.withValues(alpha: 0.5),
                strokeCap: StrokeCap.round,
                strokeJoin: StrokeJoin.round,
              ),
              // Inner main line
              Polyline(
                points: route.polyline,
                strokeWidth: 6.0,
                color: AppColors.tacticalOrange,
                strokeCap: StrokeCap.round,
                strokeJoin: StrokeJoin.round,
              ),
            ],
          ),
        ],

        // 3. POI Markers Layer
        if (controller.poiMarkers.isNotEmpty)
          MarkerLayer(
            markers: controller.poiMarkers.map((poi) {
              final isSelected = controller.selectedPoiMarker?.id == poi.id;
              return Marker(
                point: poi.location,
                width: 44,
                height: 44,
                child: GestureDetector(
                  onTap: () => controller.selectPoiMarker(poi),
                  child: _buildPoiMarker(poi, isSelected),
                ),
              );
            }).toList(),
          ),

        // 4. Waypoint Markers (Stops & Destination)
        if (controller.destination != null)
          MarkerLayer(
            markers: [
              // Intermediate stops
              ...controller.stops.asMap().entries.map((entry) {
                return Marker(
                  point: entry.value.location,
                  width: 32,
                  height: 32,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.tacticalOrange,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${entry.key + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }),

              // Destination pin
              Marker(
                point: controller.destination!.location,
                width: 44,
                height: 44,
                alignment: Alignment.topCenter,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.tacticalOrange,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.tacticalOrange.withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.place_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),

        // 5. User GPS Location Marker (Dot, Accuracy Circle & Heading Cone)
        // Rendered strictly when a real GPS fix exists; never drawn at the camera fallback center.
        if (userLoc != null)
          MarkerLayer(
            markers: [
              Marker(
                point: userLoc,
                width: 120,
                height: 120,
                child: _buildUserLocationMarker(
                  heading: heading,
                  isNavigating: isNavigating,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildUserLocationMarker({
    required double heading,
    required bool isNavigating,
  }) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Heading Cone (Projected directional beam)
        Transform.rotate(
          angle: (heading * math.pi) / 180.0,
          child: CustomPaint(
            size: const Size(120, 120),
            painter: _HeadingConePainter(),
          ),
        ),

        // Accuracy Halo
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
        ),

        // Inner Blue Dot with White Border
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: const Color(0xFF1E60FF),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E60FF).withValues(alpha: 0.45),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: isNavigating
              ? Transform.rotate(
                  angle: (heading * math.pi) / 180.0,
                  child: const Icon(
                    Icons.navigation_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
                )
              : null,
        ),
      ],
    );
  }

  Widget _buildPoiMarker(PoiMarker poi, bool isSelected) {
    Color bg;
    IconData icon;

    switch (poi.type) {
      case PoiType.mechanic:
        bg = AppColors.tacticalOrange;
        icon = Icons.handyman_rounded;
        break;
      case PoiType.fuel:
        bg = const Color(0xFF2563EB);
        icon = Icons.local_gas_station_rounded;
        break;
      case PoiType.restStop:
        bg = const Color(0xFF059669);
        icon = Icons.park_rounded;
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isSelected ? 42 : 34,
      height: isSelected ? 42 : 34,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: isSelected ? 3.0 : 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: bg.withValues(alpha: 0.4),
            blurRadius: isSelected ? 12 : 6,
            spreadRadius: isSelected ? 2 : 0,
          ),
        ],
      ),
      child: Center(
        child: Icon(
          icon,
          size: isSelected ? 20 : 16,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Custom painter for directional heading beam cone.
class _HeadingConePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final conePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF2563EB).withValues(alpha: 0.4),
          const Color(0xFF2563EB).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 55));

    final path = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: 55),
        -math.pi / 2 - (math.pi / 6),
        math.pi / 3,
        false,
      )
      ..close();

    canvas.drawPath(path, conePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
