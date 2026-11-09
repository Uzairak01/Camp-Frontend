import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../controllers/navigation_controller.dart';
import '../../domain/geocoding_service.dart';
import '../../domain/places_poi_service.dart';

/// Compact detail sheet displayed when tapping any map POI marker (Mechanic, Fuel, Rest Stop).
/// Features name, category tag, distance/subtitle, phone (if present), and "Directions" button.
class NavPoiDetailSheet extends StatelessWidget {
  const NavPoiDetailSheet({
    required this.marker,
    required this.controller,
    required this.onClose,
    super.key,
  });

  final PoiMarker marker;
  final NavigationController controller;
  final VoidCallback onClose;

  void _getDirections() {
    onClose();
    controller.openRoutePreview(
      PlaceSearchResult(
        name: marker.name,
        displayName: marker.subtitle ?? marker.name,
        location: marker.location,
        category: marker.type.name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color typeColor;
    String typeLabel;
    IconData typeIcon;

    switch (marker.type) {
      case PoiType.mechanic:
        typeColor = AppColors.tacticalOrange;
        typeLabel = 'NEARBY MECHANIC';
        typeIcon = Icons.handyman_rounded;
        break;
      case PoiType.fuel:
        typeColor = const Color(0xFF2563EB);
        typeLabel = 'FUEL STATION';
        typeIcon = Icons.local_gas_station_rounded;
        break;
      case PoiType.restStop:
        typeColor = const Color(0xFF059669);
        typeLabel = 'REST STOP & SCENIC';
        typeIcon = Icons.park_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Row(
            children: [
              // Icon Tile
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Icon(typeIcon, color: typeColor, size: 24),
                ),
              ),
              const SizedBox(width: 14),

              // Title and details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        typeLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: typeColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      marker.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkCharcoal,
                      ),
                    ),
                    if (marker.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        marker.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                color: AppColors.mutedLight,
                onPressed: onClose,
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Action row
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _getDirections,
                  icon: const Icon(Icons.directions_rounded, size: 18),
                  label: const Text(
                    'Directions',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.tacticalOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
