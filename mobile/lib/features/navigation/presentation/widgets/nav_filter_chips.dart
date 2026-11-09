import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../controllers/navigation_controller.dart';
import '../../domain/places_poi_service.dart';

/// Horizontal row of discovery filter chips: Nearby Mechanics, Fuel, Rest Stops.
class NavFilterChips extends StatelessWidget {
  const NavFilterChips({
    required this.controller,
    super.key,
  });

  final NavigationController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildChip(
            label: 'Nearby Mechanics',
            icon: Icons.handyman_rounded,
            iconColor: AppColors.tacticalOrange,
            type: PoiType.mechanic,
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: 'Fuel',
            icon: Icons.local_gas_station_rounded,
            iconColor: const Color(0xFF2563EB),
            type: PoiType.fuel,
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: 'Rest Stops',
            icon: Icons.park_rounded,
            iconColor: const Color(0xFF059669),
            type: PoiType.restStop,
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required IconData icon,
    required Color iconColor,
    required PoiType type,
  }) {
    final isSelected = controller.activePoiFilter == type;

    return GestureDetector(
      onTap: () => controller.togglePoiFilter(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? iconColor : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? iconColor.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: isSelected ? 8 : 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? AppColors.darkCharcoal : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
