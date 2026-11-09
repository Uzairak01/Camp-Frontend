import 'package:flutter/material.dart';
import '../../controllers/navigation_controller.dart';
import '../../domain/location_service.dart';

/// Banner shown when device location service or permission is disabled.
/// Explains that manual search still works and provides a direct "Open Settings" shortcut.
class NavPermissionBanner extends StatelessWidget {
  const NavPermissionBanner({
    required this.controller,
    required this.locationService,
    super.key,
  });

  final NavigationController controller;
  final LocationService locationService;

  @override
  Widget build(BuildContext context) {
    if (!controller.permissionDenied && controller.isLocationServiceEnabled) {
      return const SizedBox.shrink();
    }

    final isOff = !controller.isLocationServiceEnabled;
    final message = isOff
        ? 'Location services are disabled on your device.'
        : 'Location permission was denied. Tap to allow.';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCD34D)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.location_off_rounded,
            color: Color(0xFFD97706),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF92400E),
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () async {
              if (isOff) {
                await locationService.openLocationSettings();
              } else {
                await locationService.openAppSettings();
              }
              await controller.checkLocationPermissionAndStart();
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Open Settings',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
