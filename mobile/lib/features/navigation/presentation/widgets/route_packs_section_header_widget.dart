import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';

/// Section header displaying the "ROUTE PACKS" eyebrow
/// and trailing "Coming soon" label (no unbacked region claims).
class RoutePacksSectionHeaderWidget extends StatelessWidget {
  const RoutePacksSectionHeaderWidget({
    super.key,
    this.eyebrow = 'ROUTE PACKS',
    this.trailingLabel = 'Coming soon',
  });

  final String eyebrow;
  final String trailingLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            eyebrow,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.overline,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          trailingLabel,
          style: GoogleFonts.manrope(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: AppColors.tacticalOrange,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}
