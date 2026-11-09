import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../controllers/navigation_controller.dart';

/// 72 px circular white speed bubble shown at the bottom-left during active RIDING state:
/// - Displays real-time filtered speed from [NavigationController.formattedSpeed] ("--" when unknown).
/// - Unit label "km/h" positioned cleanly underneath the numeric speed readout.
class NavSpeedBubble extends StatelessWidget {
  const NavSpeedBubble({
    required this.controller,
    super.key,
  });

  final NavigationController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('nav_speed_bubble'),
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              controller.formattedSpeed,
              style: GoogleFonts.manrope(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF111827),
                height: 1.0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'km/h',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF6B7280),
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

