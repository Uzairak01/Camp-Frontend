import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../maintenance/domain/post_ride_report.dart';
import '../../../maintenance/presentation/screens/post_ride_debrief_screen.dart';

/// Modal bottom sheet presented when a tracked ride finishes:
/// Displays summary distance and duration ("12.4 km in 0:35")
/// and provides an "Add details" button to open [PostRideDebriefScreen] prefilled.
class RideSummarySheet extends StatelessWidget {
  const RideSummarySheet({
    required this.report,
    super.key,
  });

  final PostRideReport report;

  /// Helper to display this modal bottom sheet from any context.
  static Future<void> show(BuildContext context, PostRideReport report) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RideSummarySheet(report: report),
    );
  }

  static String formatDuration(double? hours) {
    if (hours == null || hours <= 0) return '0:01';
    final totalMinutes = (hours * 60).round().clamp(1, 100000);
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return '$h:${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final distanceStr = report.distanceKm == report.distanceKm.roundToDouble()
        ? report.distanceKm.toStringAsFixed(0)
        : report.distanceKm.toStringAsFixed(1);
    final durationStr = formatDuration(report.durationHours);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.clay,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.mutedLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.statusGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'RIDE SAVED',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.statusGreen,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                color: AppColors.mutedText,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Title & Summary
          Text(
            '$distanceStr km in $durationStr',
            style: GoogleFonts.manrope(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.darkCharcoal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            report.routeTitle,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedText,
            ),
          ),
          const SizedBox(height: 24),

          // Add Details Button
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PostRideDebriefScreen(
                    initialReport: report,
                    bikeId: report.bikeId,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.tacticalOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusTile),
              ),
              elevation: 0,
            ),
            child: Text(
              'Add details',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Done / Dismiss Button
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Done',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.mutedText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

