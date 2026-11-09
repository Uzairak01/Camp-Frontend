import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';

/// Widget #5 — Route progress line.
/// "Kaghan Valley → ⛰ Summit (4,173m) → Chilas Jct"
/// Start dot (green) — divider — peak icon+label (orange) — divider — end dot (orange).
class RouteProgressWidget extends StatelessWidget {
  const RouteProgressWidget({
    required this.startLabel,
    required this.peakLabel,
    required this.peakElevation,
    required this.endLabel,
    super.key,
    this.dark = true,
  });

  final String startLabel;
  final String peakLabel;
  final String peakElevation;
  final String endLabel;

  /// When true, text appears on dark cockpit background.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final labelColor =
        dark ? Colors.white.withValues(alpha: 0.75) : AppColors.mutedText;

    return Row(
      children: [
        // Start
        const _Dot(color: AppColors.statusGreen),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            startLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: labelColor,
            ),
          ),
        ),

        // Divider
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            height: 1,
            color: (dark ? Colors.white : AppColors.darkCharcoal)
                .withValues(alpha: 0.15),
          ),
        ),

        // Peak
        const Icon(
          Icons.landscape_rounded,
          size: 14,
          color: AppColors.tacticalOrange,
        ),
        const SizedBox(width: 3),
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              peakLabel,
              style: GoogleFonts.manrope(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.tacticalOrange,
                letterSpacing: 0.3,
              ),
            ),
            Text(
              peakElevation,
              style: GoogleFonts.manrope(
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
                color: AppColors.tacticalOrange.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),

        // Divider
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            height: 1,
            color: (dark ? Colors.white : AppColors.darkCharcoal)
                .withValues(alpha: 0.15),
          ),
        ),

        // End
        Flexible(
          child: Text(
            endLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: labelColor,
            ),
          ),
        ),
        const SizedBox(width: 4),
        const _Dot(color: AppColors.tacticalOrange),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
