import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../garage/services/fuel_tracker_service.dart';
import '../../../maintenance/domain/post_ride_report.dart';
import '../../../maintenance/presentation/screens/post_ride_debrief_screen.dart';

/// Modal bottom sheet presented when a tracked ride finishes:
/// Displays summary distance and duration ("12.4 km in 0:35"),
/// provides an "Add details" button to open [PostRideDebriefScreen] prefilled,
/// a "Discard" button (with odometer subtraction confirmation), and "Done".
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

  /// Completes the active tracked ride via [FuelTrackerService], executes [onFinished]
  /// if provided (e.g. dismissing navigation or arrival state), and presents
  /// [RideSummarySheet] if distance >= 0.1 km or displays a "Ride too short to record"
  /// floating snackbar if under 0.1 km.
  static Future<PostRideReport?> finishRideAndShowSummary(
    BuildContext context, {
    VoidCallback? onFinished,
  }) async {
    final report = await FuelTrackerService.instance.finishRide();
    onFinished?.call();
    if (context.mounted) {
      if (report != null) {
        await show(context, report);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ride too short to record',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
            ),
            backgroundColor: AppColors.darkCharcoal,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    return report;
  }

  /// Displays a confirmation dialog before discarding a tracked ride, informing
  /// the rider how many kilometers will be subtracted from their bike's odometer.
  static Future<bool> showDiscardConfirmationDialog(
    BuildContext context, {
    required double distanceKm,
  }) async {
    final kmStr = distanceKm.toStringAsFixed(1);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.clay,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Discard ride?',
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.darkCharcoal,
          ),
        ),
        content: Text(
          'Discard this ride? This also removes $kmStr km from your odometer.',
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.mutedText,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('cancel_discard_ride_button'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                color: AppColors.mutedText,
              ),
            ),
          ),
          ElevatedButton(
            key: const ValueKey('confirm_discard_ride_button'),
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alertRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'Discard',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    return result == true;
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

          // Discard Ride Button (with odometer subtraction confirmation)
          TextButton(
            key: const ValueKey('ride_summary_discard_button'),
            onPressed: () async {
              final appliedKm = FuelTrackerService.instance
                  .appliedOdometerKmForReport(report);
              final confirmed = await showDiscardConfirmationDialog(
                context,
                distanceKm: appliedKm,
              );
              if (!confirmed) return;
              if (context.mounted) {
                Navigator.of(context).pop();
              }
              await FuelTrackerService.instance.discardFinishedRideReport(
                report,
              );
            },
            child: Text(
              'Discard',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.alertRed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

