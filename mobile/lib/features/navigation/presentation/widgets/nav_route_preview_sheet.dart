import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../settings/controllers/settings_controller.dart';
import '../../controllers/navigation_controller.dart';

/// State 2 bottom sheet featuring route duration, distance, fastest route status,
/// Est. Fuel card, Start button, Add stop, Share (share_plus), and Save.
class NavRoutePreviewSheet extends StatelessWidget {
  const NavRoutePreviewSheet({
    required this.controller,
    required this.onStartNavigation,
    required this.onAddStop,
    super.key,
  });

  final NavigationController controller;
  final VoidCallback onStartNavigation;
  final VoidCallback onAddStop;

  void _shareRoute(BuildContext context) {
    final dest = controller.destination;
    final destName = dest?.name ?? 'Destination';
    final url = controller.googleMapsUrl;
    // ignore: deprecated_member_use
    Share.share(
      'Follow my route to $destName on CAMP Navigation: $url',
      subject: 'CAMP Navigation Route to $destName',
    );
  }

  @override
  Widget build(BuildContext context) {
    final route = controller.route;
    final error = controller.routeError;
    final isCalc = controller.isCalculatingRoute;
    final fuelEstimate = controller.fuelEstimateDisplay;
    final isSaved = controller.destination != null &&
        controller.isPlaceSaved(controller.destination!);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Bottom Area: Exactly ONE of Error, Calculating, or Route Metrics ──
          if (error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    color: Color(0xFFDC2626),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      error,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF991B1B),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: controller.calculateRoute,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else if (isCalc || route == null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.tacticalOrange,
                    ),
                  ),
                  SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Calculating fastest road route...',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mutedText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  disabledBackgroundColor: const Color(0xFFE5E7EB),
                  disabledForegroundColor: AppColors.mutedText,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Calculating...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ] else ...[
            // ── Metrics Row: Duration + Distance and Fuel Estimate Tile ────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            route.formattedDuration,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF059669),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${route.formattedDistance(SettingsController.instance.units)})',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.mutedText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Fastest route',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Est. Fuel Tile (Only visible if active bike has fuel consumption)
                if (fuelEstimate != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'EST. FUEL',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: AppColors.mutedLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          fuelEstimate,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.darkCharcoal,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Action Buttons Row: Start, Add, Share, Save ───────────────────
            Row(
              children: [
                // 1. Primary "Start" Button
                Expanded(
                  flex: 3,
                  child: ElevatedButton(
                    onPressed: onStartNavigation,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                      backgroundColor: AppColors.tacticalOrange,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: AppColors.tacticalOrange.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.navigation_rounded, size: 20),
                          SizedBox(width: 6),
                          Text(
                            'Start',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 2. Add Stop Button
                _buildActionTile(
                  icon: Icons.add_location_alt_outlined,
                  label: 'Add',
                  onTap: onAddStop,
                ),
                const SizedBox(width: 8),

                // 3. Share Button (share_plus)
                _buildActionTile(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  onTap: () => _shareRoute(context),
                ),
                const SizedBox(width: 8),

                // 4. Save Button
                _buildActionTile(
                  icon: isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  iconColor: isSaved ? AppColors.tacticalOrange : null,
                  label: isSaved ? 'Saved' : 'Save',
                  onTap: () {
                    if (controller.destination != null) {
                      controller.toggleSavedPlace(controller.destination!);
                    }
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Container(
      width: 58,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: iconColor ?? AppColors.darkCharcoal,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: iconColor ?? AppColors.mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
