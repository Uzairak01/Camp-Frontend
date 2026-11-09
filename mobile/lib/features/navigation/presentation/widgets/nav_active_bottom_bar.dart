import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../dashboard/presentation/widgets/ride_summary_sheet.dart';
import '../../../garage/services/fuel_tracker_service.dart';
import '../../controllers/navigation_controller.dart';

/// Dark obsidian bottom telemetry dock during active State 3 navigation:
/// - ETA readout in bright emerald green
/// - Remaining duration and distance
/// - Overview route toggle
/// - Red circular Exit (X) button with confirmation prompt
class NavActiveBottomBar extends StatelessWidget {
  const NavActiveBottomBar({
    required this.controller,
    required this.onConfirmExit,
    this.onToggleOverview,
    super.key,
  });

  final NavigationController controller;
  final VoidCallback onConfirmExit;
  final VoidCallback? onToggleOverview;

  Future<void> _promptExitConfirmation(BuildContext context) {
    return promptExitConfirmation(context, onConfirmExit: onConfirmExit);
  }

  /// Prompts the navigation exit sheet or confirmation dialog:
  /// - When ride tracking is running, shows the bottom sheet offering "Finish ride", "Keep tracking", and "Discard".
  /// - When not tracking, shows the dialog to confirm ending guidance.
  static Future<void> promptExitConfirmation(
    BuildContext context, {
    required VoidCallback onConfirmExit,
  }) async {
    final isTracking = FuelTrackerService.instance.isRiding;

    if (isTracking) {
      final choice = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF141416),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(ctx).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF374151),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Finish ride?',
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose whether to finish and save your ride log now, or keep tracking distance and fuel in the background.',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF9CA3AF),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop('finish'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.tacticalOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusTile),
                  ),
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
              OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop('keep'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF374151)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusTile),
                  ),
                ),
                child: Text(
                  'Keep tracking',
                  style: GoogleFonts.manrope(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                key: const ValueKey('nav_exit_discard_ride_button'),
                onPressed: () async {
                  final confirmed =
                      await RideSummarySheet.showDiscardConfirmationDialog(
                    ctx,
                    distanceKm: FuelTrackerService.instance.appliedToOdometerKm,
                  );
                  if (confirmed && ctx.mounted) {
                    Navigator.of(ctx).pop('discard');
                  }
                },
                child: Text(
                  'Discard',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      if (!context.mounted) return;

      if (choice == 'finish') {
        await RideSummarySheet.finishRideAndShowSummary(
          context,
          onFinished: onConfirmExit,
        );
      } else if (choice == 'keep') {
        onConfirmExit();
      } else if (choice == 'discard') {
        await FuelTrackerService.instance.discardSavedRide();
        onConfirmExit();
      }
      return;
    }

    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'End navigation?',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: const Text(
          'Turn-by-turn guidance and live speed tracking will stop.',
          style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Resume',
              style: TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'End Ride',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (shouldExit == true) {
      onConfirmExit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── ETA Section: Green Time Readout ────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'ETA',
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                controller.formattedEta,
                style: const TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),

          const SizedBox(width: 16),
          Container(
            width: 1,
            height: 36,
            color: const Color(0xFF26262A),
          ),
          const SizedBox(width: 16),

          // ── Remaining Duration & Distance ──────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  controller.formattedRemainingDuration,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${controller.formattedRemainingDistance} remaining',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // ── Route Overview Button ──────────────────────────────────────────
          Container(
            width: 44,
            height: 44,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF26262A),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.alt_route_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: onToggleOverview,
              tooltip: 'Toggle route overview',
              padding: EdgeInsets.zero,
            ),
          ),

          // ── Red Circular Exit (X) Button ───────────────────────────────────
          GestureDetector(
            onTap: () => _promptExitConfirmation(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
