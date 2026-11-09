import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/stat_model.dart';

/// Widget #3 — Reusable small stat tile.
/// [dark] = true → translucent white-on-dark style (cockpit card).
/// [dark] = false → light clay-card style (season summary, expedition cards).
class StatTileWidget extends StatelessWidget {
  const StatTileWidget({
    required this.stat,
    super.key,
    this.dark = false,
  });

  final Stat stat;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final valueColor = stat.valueColor ??
        (dark ? Colors.white : AppColors.darkCharcoal);
    final unitColor = stat.unitColor ??
        (dark
            ? Colors.white.withValues(alpha: 0.65)
            : AppColors.mutedText);
    final labelColor =
        dark ? Colors.white.withValues(alpha: 0.45) : AppColors.mutedText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                stat.value,
                maxLines: 1,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: valueColor,
                  letterSpacing: -0.3,
                ),
              ),
              if (stat.unit != null) ...[
                const SizedBox(width: 2),
                Text(
                  stat.unit!,
                  maxLines: 1,
                  style: GoogleFonts.manrope(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: unitColor,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          stat.label,
          style: GoogleFonts.manrope(
            fontSize: 8.5,
            fontWeight: FontWeight.w600,
            color: labelColor,
            letterSpacing: 0.5,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
