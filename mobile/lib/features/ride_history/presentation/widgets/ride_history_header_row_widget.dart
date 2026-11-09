import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// Ride History header row.
/// Eyebrow + "Ride History" title + "$count Logged" badge.
/// The non-functional download icon has been removed.
class RideHistoryHeaderRowWidget extends StatelessWidget {
  const RideHistoryHeaderRowWidget({
    required this.count,
    super.key,
    this.onDownload,
  });

  final int count;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EXPEDITION ARCHIVE',
          style: AppTextStyles.overline,
        ),
        const SizedBox(height: 4),
        SectionHeader(
          title: 'Ride History',
          padding: EdgeInsets.zero,
          badge: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.clayDark,
              borderRadius: BorderRadius.circular(AppColors.radiusPill),
              boxShadow: AppColors.skeuRaisedSmall,
            ),
            child: Text(
              '$count Logged',
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.mutedText,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
