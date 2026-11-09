import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../controllers/navigation_controller.dart';

/// Top card in State 2 (Route Preview) featuring back button, title,
/// Origin & Destination waypoint inputs, endpoint swap, Add Stop action,
/// and motorcycle profile duration tab.
class NavRoutePreviewPanel extends StatelessWidget {
  const NavRoutePreviewPanel({
    required this.controller,
    required this.onBack,
    required this.onAddStop,
    super.key,
  });

  final NavigationController controller;
  final VoidCallback onBack;
  final VoidCallback onAddStop;

  @override
  Widget build(BuildContext context) {
    final route = controller.route;
    final error = controller.routeError;
    final isCalc = controller.isCalculatingRoute;

    // Show duration if route is ready; if location is unavailable or error,
    // do NOT say "Calculating...", display "Location unavailable".
    final String durationText;
    if (error != null || controller.latestGoodPosition == null) {
      durationText = 'Location unavailable';
    } else if (isCalc || route == null) {
      durationText = 'Calculating...';
    } else {
      durationText = route.formattedDuration;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header: Back Button, Title, Overflow Menu ───────────────────────
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  color: AppColors.darkCharcoal,
                  onPressed: onBack,
                  padding: EdgeInsets.zero,
                ),
              ),
              const Expanded(
                child: Text(
                  'ROUTE PREVIEW',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: AppColors.mutedText,
                  ),
                ),
              ),
              const SizedBox(width: 36), // Balanced alignment
            ],
          ),
          const SizedBox(height: 16),

          // ── Waypoints Section: Origin & Destination Inputs + Swap ───────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Vertical Timeline Graphic
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF2563EB),
                        width: 3,
                      ),
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 32,
                    color: const Color(0xFFD1D5DB),
                  ),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: AppColors.tacticalOrange,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Inputs Column
              Expanded(
                child: Column(
                  children: [
                    // Origin (Your Location)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              controller.currentLocationName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.darkCharcoal,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.my_location_rounded,
                            size: 16,
                            color: Color(0xFF2563EB),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Destination
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              controller.destination?.name ?? 'Choose destination',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkCharcoal,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: onBack,
                            child: const Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: AppColors.mutedLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Swap Button
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: IconButton(
                  icon: const Icon(Icons.swap_vert_rounded, size: 20),
                  color: AppColors.darkCharcoal,
                  onPressed: controller.swapStartAndDestination,
                  tooltip: 'Swap start and destination',
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),

          // ── Stops if added ─────────────────────────────────────────────────
          if (controller.stops.isNotEmpty) ...[
            const SizedBox(height: 10),
            Column(
              children: controller.stops.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.stop_circle_outlined,
                        color: AppColors.tacticalOrange,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Stop ${entry.key + 1}: ${entry.value.name}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 16),
                        color: const Color(0xFFEF4444),
                        onPressed: () => controller.removeStop(entry.key),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 12),

          // ── Sub-actions: Add Stop ──────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: onAddStop,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_circle_outline_rounded,
                      color: AppColors.tacticalOrange,
                      size: 18,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Add stop',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.tacticalOrange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Mode Selector: Motorcycle (Tactical Orange Pill) ────────────────
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    AppColors.tacticalOrangeLight,
                    AppColors.tacticalOrange,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.tacticalOrange.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.two_wheeler_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    durationText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
