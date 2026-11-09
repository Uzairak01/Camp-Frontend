import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';

/// Widget #7 — Translucent dark info tile used inside the cockpit hero card.
/// Shows a category label (eyebrow), a primary value line, and an optional
/// muted note below (e.g. "• Nominal" or "green under-budget note").
class DarkInfoTileWidget extends StatelessWidget {
  const DarkInfoTileWidget({
    required this.category,
    required this.primaryLine,
    super.key,
    this.noteLine,
    this.noteColor,
  });

  /// Uppercase eyebrow label, e.g. "CARB TUNING".
  final String category;

  /// Main value line, e.g. "Leaned 0.5 Turns / 61kPa at Summit • Nominal".
  final String primaryLine;

  /// Optional secondary note, e.g. "$3.60 under budget".
  final String? noteLine;

  /// Color for the note text; defaults to [AppColors.statusGreen].
  final Color? noteColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppColors.radiusTile),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category,
            style: GoogleFonts.manrope(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.45),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            primaryLine,
            style: GoogleFonts.manrope(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.35,
            ),
          ),
          if (noteLine != null) ...[
            const SizedBox(height: 3),
            Text(
              noteLine!,
              style: GoogleFonts.manrope(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: noteColor ?? AppColors.statusGreen,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
