import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/data/in_progress_ride_model.dart';
import '../../../garage/services/fuel_tracker_service.dart';
import 'ride_summary_sheet.dart';

/// Cold-start recovery bottom sheet presented when an unfinished in-progress ride
/// is detected in persistent storage (e.g. after the app was killed mid-ride).
///
/// Prompts the rider with options to "Continue ride" (primary), "Finish ride", or "Discard".
/// Does NOT silently resume tracking in the background without user confirmation.
class UnfinishedRideRecoverySheet extends StatelessWidget {
  const UnfinishedRideRecoverySheet({
    required this.savedRide,
    super.key,
  });

  final InProgressRide savedRide;

  /// Helper to display this recovery sheet from a BuildContext.
  static Future<void> show(BuildContext context, InProgressRide savedRide) {
    return showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UnfinishedRideRecoverySheet(savedRide: savedRide),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $amPm';
  }

  @override
  Widget build(BuildContext context) {
    final distanceStr =
        savedRide.distanceKm == savedRide.distanceKm.roundToDouble()
            ? savedRide.distanceKm.toStringAsFixed(0)
            : savedRide.distanceKm.toStringAsFixed(1);
    final timeStr = _formatTime(savedRide.startedAt.toLocal());

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
      child: SingleChildScrollView(
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
                  color: AppColors.tacticalOrange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'UNFINISHED RIDE RECOVERY',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.tacticalOrange,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            'Unfinished ride from $timeStr: $distanceStr km',
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.darkCharcoal,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Finish ride or discard?',
            style: GoogleFonts.manrope(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: AppColors.mutedText,
            ),
          ),
          const SizedBox(height: 24),

          // "Continue ride" Primary Action Button
          ElevatedButton(
            key: const ValueKey('unfinished_ride_continue_button'),
            onPressed: () async {
              Navigator.of(context).pop();
              await FuelTrackerService.instance.resumeRide(savedRide);
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
              'Continue ride',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // "Finish ride" Action Button
          ElevatedButton(
            key: const ValueKey('unfinished_ride_finish_button'),
            onPressed: () async {
              Navigator.of(context).pop();
              final report =
                  await FuelTrackerService.instance.finishSavedRide(savedRide);
              if (context.mounted) {
                if (report != null) {
                  RideSummarySheet.show(context, report);
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
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.darkCharcoal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusTile),
              ),
              elevation: 0,
            ),
            child: Text(
              'Finish ride',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // "Discard" Action Button
          OutlinedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await FuelTrackerService.instance.discardSavedRide();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.mutedText,
              side: const BorderSide(color: AppColors.mutedLight),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusTile),
              ),
            ),
            child: Text(
              'Discard',
              style: GoogleFonts.manrope(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }
}

