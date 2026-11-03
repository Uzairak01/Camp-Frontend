import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../dashboard/presentation/widgets/ride_summary_sheet.dart';
import '../../../garage/services/fuel_tracker_service.dart';
import '../../../settings/controllers/settings_controller.dart';
import '../../controllers/navigation_controller.dart';

/// Modal sheet shown when the user arrives within ~30m of their destination.
///
/// Offers "Finish ride" (primary action running the unified ride finish flow)
/// and "Keep tracking" (dismisses arrival sheet while keeping the ride tracker active).
class NavArrivedSheet extends StatelessWidget {
  const NavArrivedSheet({
    required this.controller,
    required this.onDone,
    super.key,
  });

  final NavigationController controller;
  final VoidCallback onDone;

  /// Completes the active tracked ride using the same finish flow as the exit sheet,
  /// dismisses the arrival state, and presents the ride summary or short-ride notice.
  Future<void> _handleFinishRide(BuildContext context) async {
    final report = await FuelTrackerService.instance.finishRide();
    onDone();
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
  }

  @override
  Widget build(BuildContext context) {
    final route = controller.route;
    final dest = controller.destination;
    final units = SettingsController.instance.units;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Arrival Trophy / Check Graphic
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFA7F3D0), width: 2),
            ),
            child: const Center(
              child: Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF059669),
                size: 34,
              ),
            ),
          ),
          const SizedBox(height: 14),

          const Text(
            'You have arrived',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.darkCharcoal,
            ),
          ),
          const SizedBox(height: 4),

          Text(
            dest?.name ?? 'Destination reached',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedText,
            ),
          ),

          if (route != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text(
                        'DISTANCE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: AppColors.mutedLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        route.formattedDistance(units),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 28, color: const Color(0xFFE5E7EB)),
                  Column(
                    children: [
                      const Text(
                        'TRIP TIME',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: AppColors.mutedLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        route.formattedDuration,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Primary "Finish ride" Action
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const ValueKey('arrived_finish_ride_button'),
              onPressed: () => _handleFinishRide(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.tacticalOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                'Finish ride',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Secondary "Keep tracking" Action
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              key: const ValueKey('arrived_keep_tracking_button'),
              onPressed: onDone,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.darkCharcoal,
                side: const BorderSide(color: AppColors.mutedLight),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                'Keep tracking',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
