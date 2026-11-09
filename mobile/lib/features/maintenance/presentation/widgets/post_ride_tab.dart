import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/camp_card.dart';
import '../../../../core/widgets/inset_tile.dart';
import '../../../garage/domain/bike_model.dart';
import '../../controllers/post_ride_report_controller.dart';
import '../../domain/post_ride_report.dart';
import '../screens/post_ride_debrief_screen.dart';

/// Tab 4 — Post-Ride Debrief history log and entry launcher.
/// Uses [PostRideReportController] as the single source of truth.
class PostRideTab extends StatelessWidget {
  const PostRideTab({required this.bike, super.key});

  final Bike bike;

  Future<void> _confirmAndClearLogs(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.clay,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusCard),
          ),
          title: Text(
            'Clear Expedition Logs?',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.darkCharcoal,
            ),
          ),
          content: Text(
            'This deletes the saved ride reports and will change Profile stats and the predicted service dates. Are you sure you want to proceed?',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.darkCharcoal,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.mutedText,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'Clear Logs',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.alertRed,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      PostRideReportController.instance.clearReportsForBike(bike.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cleared expedition history for active bike.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: PostRideReportController.instance,
      builder: (context, _) {
        final reports = PostRideReportController.instance
            .getReportsForBike(bike.id);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // "Log a ride" button that opens PostRideDebriefScreen
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PostRideDebriefScreen(bikeId: bike.id),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.tacticalOrange,
                  borderRadius: BorderRadius.circular(AppColors.radiusTile),
                  boxShadow: AppColors.orangeGlow,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.edit_note_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Log a ride',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // History Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'EXPEDITION LOG HISTORY (${reports.length})',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.mutedText,
                    letterSpacing: 0.7,
                  ),
                ),
                if (reports.isNotEmpty)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _confirmAndClearLogs(context),
                    child: Text(
                      'Clear Logs',
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mutedLight,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            if (reports.isEmpty) ...[
              InsetTile(
                padding: const EdgeInsets.all(24),
                borderRadius: AppColors.radiusTile,
                child: Center(
                  child: Text(
                    'No post-ride reports logged yet.\nTap "Log a ride" above to debrief your first journey.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mutedText,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ] else ...[
              ...reports.map((report) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildReportHistoryItem(report),
                  )),
            ],
          ],
        );
      },
    );
  }

  // ── History Item ──────────────────────────────────────────────────────────
  Widget _buildReportHistoryItem(PostRideReport report) {
    return CampCard(
      padding: const EdgeInsets.all(14),
      borderRadius: AppColors.radiusCard,
      color: AppColors.clay,
      shadows: AppColors.skeuRaisedSmall,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${report.distanceKm.toStringAsFixed(0)} km',
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.darkCharcoal,
                ),
              ),
              Text(
                _formatRelativeTime(report.date),
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedText,
                ),
              ),
            ],
          ),
          if (report.terrainTags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: report.terrainTags.map((tag) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7.5, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: AppColors.clayDark,
                    borderRadius: BorderRadius.circular(AppColors.radiusPill),
                  ),
                  child: Text(
                    tag,
                    style: GoogleFonts.manrope(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mutedText,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          if (report.combinedNotes != null &&
              report.combinedNotes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              report.combinedNotes!,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.darkCharcoal,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _formatRelativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }
}
