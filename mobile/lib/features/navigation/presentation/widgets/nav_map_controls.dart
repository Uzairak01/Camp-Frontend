import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../../app/theme/app_colors.dart';
import '../../controllers/navigation_controller.dart';

/// Floating map control buttons positioned vertically along the right screen margin:
/// Recenter, Layers (Standard / OpenTopoMap), Compass (reset North), Zoom in / Zoom out.
class NavMapControls extends StatelessWidget {
  const NavMapControls({
    required this.controller,
    required this.mapController,
    super.key,
  });

  final NavigationController controller;
  final MapController mapController;

  void _recenter() {
    controller.recenterMap();
    mapController.move(controller.cameraCenter, mapController.camera.zoom);
  }

  void _resetNorth() {
    mapController.rotate(0.0);
  }

  void _zoomIn() {
    final currentZoom = mapController.camera.zoom;
    mapController.move(mapController.camera.center, currentZoom + 1.0);
  }

  void _zoomOut() {
    final currentZoom = mapController.camera.zoom;
    mapController.move(mapController.camera.center, currentZoom - 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Recenter Button
        _buildCircleButton(
          icon: Icons.my_location_rounded,
          iconColor: const Color(0xFF2563EB),
          onTap: _recenter,
          tooltip: 'Recenter on current location',
        ),
        const SizedBox(height: 10),

        // 2. Layers Toggle Button (OSM Standard / OpenTopoMap)
        _buildCircleButton(
          icon: Icons.layers_rounded,
          iconColor: controller.isTopoLayer
              ? AppColors.tacticalOrange
              : const Color(0xFF4B5563),
          onTap: controller.toggleTopoLayer,
          tooltip: 'Toggle topographic map layer',
        ),
        const SizedBox(height: 10),

        // 3. Compass (Reset North)
        _buildCircleButton(
          icon: Icons.explore_rounded,
          iconColor: const Color(0xFFEF4444),
          onTap: _resetNorth,
          tooltip: 'Reset map rotation to North',
        ),
        const SizedBox(height: 10),

        // 4. Zoom Controls Pill (Zoom In & Zoom Out in single pill)
        Container(
          width: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.add, size: 20, color: Color(0xFF374151)),
                onPressed: _zoomIn,
                tooltip: 'Zoom in',
                padding: const EdgeInsets.symmetric(vertical: 8),
                constraints: const BoxConstraints(),
              ),
              const Divider(height: 1, indent: 8, endIndent: 8, color: Color(0xFFE5E7EB)),
              IconButton(
                icon: const Icon(Icons.remove, size: 20, color: Color(0xFF374151)),
                onPressed: _zoomOut,
                tooltip: 'Zoom out',
                padding: const EdgeInsets.symmetric(vertical: 8),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor, size: 22),
        onPressed: onTap,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
