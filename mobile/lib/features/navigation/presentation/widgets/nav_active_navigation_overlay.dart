import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../controllers/navigation_controller.dart';

/// Floating telemetry and navigation shortcuts during active State 3 guidance:
/// - Wide "Google Maps" external launcher
/// - Wide "Offline Maps" route pack shortcut
/// - Speedometer card (current speed only, no speed-limits or lanes)
class NavActiveNavigationOverlay extends StatelessWidget {
  const NavActiveNavigationOverlay({
    required this.controller,
    this.mapController,
    super.key,
  });

  final NavigationController controller;
  final MapController? mapController;

  /// Launches Google Maps externally with turn-by-turn guidance for the active destination.
  static Future<void> launchGoogleMaps(
    BuildContext context,
    String googleMapsUrl,
  ) async {
    final uri = Uri.parse(googleMapsUrl);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps')),
        );
      }
    }
  }

  /// Navigates to the offline route packs catalog screen.
  static void openOfflineMaps(BuildContext context) {
    Navigator.of(context).pushNamed(CampRoutes.routePacks);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            NavExternalShortcuts(controller: controller),
            const SizedBox(height: 12),

            // 3. Speedometer Badge (No speed-limit sign, no lane guidance)
            Container(
              width: 110,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    controller.formattedSpeed,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: AppColors.darkCharcoal,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    controller.speedUnitLabel,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: AppColors.mutedLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stacked "Google Maps" and "Offline Route Packs" shortcut buttons.
/// Reused identically across both READY and RIDING states.
class NavExternalShortcuts extends StatelessWidget {
  const NavExternalShortcuts({
    required this.controller,
    super.key,
  });

  final NavigationController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        NavActionPill(
          icon: Icons.navigation_outlined,
          iconColor: const Color(0xFFEA580C),
          label: 'Google Maps',
          trailing: Icons.open_in_new_rounded,
          onTap: () => NavActiveNavigationOverlay.launchGoogleMaps(
            context,
            controller.googleMapsUrl,
          ),
        ),
        const SizedBox(height: 8),
        NavActionPill(
          icon: Icons.offline_pin_outlined,
          iconColor: AppColors.tacticalOrange,
          label: 'Offline Route Packs',
          trailing: Icons.chevron_right_rounded,
          onTap: () => NavActiveNavigationOverlay.openOfflineMaps(context),
        ),
      ],
    );
  }
}

/// Pill button component for external tool launches.
class NavActionPill extends StatelessWidget {
  const NavActionPill({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.trailing,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final IconData trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minWidth: 175),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.darkCharcoal,
              ),
            ),
            const SizedBox(width: 8),
            Icon(trailing, size: 16, color: AppColors.mutedLight),
          ],
        ),
      ),
    );
  }
}
