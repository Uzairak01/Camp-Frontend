import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';

/// Widget #9 — Small raised pill date badge.
/// Used at the top of each ExpeditionCardWidget.
class DateChipWidget extends StatelessWidget {
  const DateChipWidget({
    required this.label,
    super.key,
  });

  /// Date string, e.g. "OCT 11, 2024".
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.clay,
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
        boxShadow: AppColors.skeuRaisedSmall,
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: AppColors.darkCharcoal,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
