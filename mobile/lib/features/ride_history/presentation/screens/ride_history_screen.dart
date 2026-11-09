import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../garage/controllers/active_bike_controller.dart';
import '../../../maintenance/controllers/post_ride_report_controller.dart';
import '../../../maintenance/domain/post_ride_report.dart';
import '../../domain/expedition_log_model.dart';
import '../../domain/stat_model.dart';
import '../widgets/expedition_card_widget.dart';
import '../widgets/latest_expedition_card_widget.dart';
import '../widgets/ride_filter_chips_widget.dart';
import '../widgets/ride_history_header_row_widget.dart';
import '../widgets/season_summary_card_widget.dart';

/// Ride History screen.
/// Displays genuine rider-logged ride history without synthetic claims.
class RideHistoryScreen extends StatefulWidget {
  const RideHistoryScreen({super.key});

  @override
  State<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen> {
  String? _selectedTerrain;

  Future<void> _shareRide(PostRideReport report) async {
    final localDate = report.date.toLocal();
    final dateStr =
        '${localDate.year}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')}';
    final activeBike = ActiveBikeController.instance.activeBike;
    final bikeName = activeBike != null
        ? '${activeBike.make} ${activeBike.modelName}'
        : 'Motorcycle';
    final distStr = '${report.distanceKm.toStringAsFixed(1)} km';
    final terrainStr = report.terrainTags.isNotEmpty
        ? report.terrainTags.join(', ')
        : (report.terrain.isNotEmpty ? report.terrain : 'Road');
    final notesStr = (report.notes != null && report.notes!.trim().isNotEmpty)
        ? report.notes!.trim()
        : 'None';

    final summary = 'CAMP Ride Summary:\n'
        'Date: $dateStr\n'
        'Bike: $bikeName\n'
        'Distance: $distStr\n'
        'Terrain: $terrainStr\n'
        'Notes: $notesStr';

    try {
      // ignore: deprecated_member_use
      await Share.share(summary, subject: 'CAMP Ride - $dateStr');
    } catch (_) {}
  }

  Future<void> _confirmAndDeleteRide(PostRideReport report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.clay,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusCard),
        ),
        title: Text(
          'Delete ride?',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.darkCharcoal,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this ride? This action will update your ride totals and profile stats.',
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.darkCharcoal,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
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
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.alertRed,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final deletedReport = report;
      final originalIndex =
          PostRideReportController.instance.reports.indexOf(deletedReport);
      PostRideReportController.instance.removeReport(deletedReport.id);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Ride deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              PostRideReportController.instance.insertReport(
                originalIndex >= 0 ? originalIndex : 0,
                deletedReport,
              );
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.clay,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // ── App bar ─────────────────────────────────────────────────
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: CampAppBar(
                    leading: CampAppBarLeading.back,
                    actionText: 'LOGS',
                  ),
                ),

                // ── Scrollable body ─────────────────────────────────────────
                Expanded(
                  child: ListenableBuilder(
                    listenable: Listenable.merge([
                      PostRideReportController.instance,
                      ActiveBikeController.instance,
                    ]),
                    builder: (context, _) {
                      final allReports =
                          PostRideReportController.instance.reports;
                      final int totalCount = allReports.length;

                      // Compute terrain counts for terrains that actually exist in saved rides
                      final terrainCounts = <String, int>{};
                      const standardTerrains = [
                        'City',
                        'Highway',
                        'Off-road',
                        'Mountain'
                      ];
                      for (final terrain in standardTerrains) {
                        final count = allReports
                            .where((r) =>
                                r.terrainTags.contains(terrain) ||
                                r.terrain == terrain)
                            .length;
                        if (count > 0) {
                          terrainCounts[terrain] = count;
                        }
                      }
                      for (final r in allReports) {
                        for (final t in r.terrainTags) {
                          if (!terrainCounts.containsKey(t)) {
                            final count = allReports
                                .where((rep) =>
                                    rep.terrainTags.contains(t) ||
                                    rep.terrain == t)
                                .length;
                            if (count > 0) terrainCounts[t] = count;
                          }
                        }
                      }

                      // Apply terrain filter
                      final filteredReports = _selectedTerrain == null
                          ? allReports
                          : allReports
                              .where((r) =>
                                  r.terrainTags.contains(_selectedTerrain) ||
                                  r.terrain == _selectedTerrain)
                              .toList();

                      final latestReport =
                          allReports.isNotEmpty ? allReports.first : null;
                      final activeBike =
                          ActiveBikeController.instance.activeBike;

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                        children: [
                          // 1. Header row: title and count badge
                          RideHistoryHeaderRowWidget(
                            count: totalCount,
                          ),

                          const SizedBox(height: 14),

                          // 2. Filter chips: "All rides (n)" + existing terrain chips
                          Padding(
                            padding: EdgeInsets.zero,
                            child: RideFilterChipsWidget(
                              totalCount: totalCount,
                              terrainCounts: terrainCounts,
                              selectedTerrain: _selectedTerrain,
                              onTerrainSelected: (terrain) =>
                                  setState(() => _selectedTerrain = terrain),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // 3. Your rides summary card
                          const SeasonSummaryCardWidget(),

                          const SizedBox(height: 16),

                          // 4. Latest ride hero card
                          LatestExpeditionCardWidget(
                            report: latestReport,
                            onMenuActionSelected: (action) {
                              if (latestReport == null) return;
                              switch (action) {
                                case LatestExpeditionOptionAction.shareRide:
                                  _shareRide(latestReport);
                                  break;
                                case LatestExpeditionOptionAction.deleteRide:
                                  _confirmAndDeleteRide(latestReport);
                                  break;
                              }
                            },
                          ),

                          const SizedBox(height: 20),

                          // 5. Section label for past rides
                          SectionHeader(
                            title: 'Past Expeditions',
                            actionLabel: totalCount > 0 ? 'See All' : null,
                            onAction: totalCount > 0 ? () {} : null,
                            padding: const EdgeInsets.only(bottom: 10),
                          ),

                          // 6. Ride cards or empty state
                          if (allReports.isEmpty) ...[
                            CampEmptyState(
                              icon: Icons.history_rounded,
                              message: 'No ride logs recorded yet',
                              ctaLabel: 'Plan a ride',
                              onCta: () => Navigator.of(context)
                                  .pushNamed(CampRoutes.navigationMap),
                            ),
                          ] else if (filteredReports.isEmpty) ...[
                            CampEmptyState(
                              icon: Icons.filter_alt_off_rounded,
                              message:
                                  'No rides recorded for $_selectedTerrain terrain',
                              ctaLabel: 'Show all rides',
                              onCta: () =>
                                  setState(() => _selectedTerrain = null),
                            ),
                          ] else ...[
                            ...filteredReports.map((report) {
                              final localDate = report.date.toLocal();
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ExpeditionCardWidget(
                                  log: ExpeditionLog(
                                    date:
                                        '${localDate.month}/${localDate.day}/${localDate.year}',
                                    tag: report.terrainTags.isNotEmpty
                                        ? report.terrainTags.first
                                        : (report.terrain.isNotEmpty
                                            ? report.terrain
                                            : 'Ride'),
                                    tagVariant: StatusChipVariant.success,
                                    icon: Icons.terrain_rounded,
                                    title: report.notes?.isNotEmpty == true
                                        ? report.notes!
                                        : 'Ride on ${localDate.month}/${localDate.day}',
                                    route:
                                        '${report.distanceKm.toStringAsFixed(1)} km',
                                    bike: activeBike != null
                                        ? '${activeBike.make} ${activeBike.modelName}'
                                        : 'Motorcycle',
                                    stats: [
                                      Stat(
                                        label: 'DISTANCE',
                                        value: report.distanceKm
                                            .toStringAsFixed(1),
                                        unit: 'KM',
                                      ),
                                      if (report.durationHours != null &&
                                          report.durationHours! > 0)
                                        Stat(
                                          label: 'TIME',
                                          value:
                                              '${report.durationHours!.toStringAsFixed(1)}h',
                                        ),
                                    ],
                                    footer: ExpeditionFooterChips(
                                      report.terrainTags.isNotEmpty
                                          ? report.terrainTags
                                          : const ['Ride'],
                                    ),
                                    footerLink: 'View Log',
                                  ),
                                  onShare: () => _shareRide(report),
                                  onDelete: () =>
                                      _confirmAndDeleteRide(report),
                                ),
                              );
                            }),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // ── Floating bottom nav ────────────────────────────────────────────
          const Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(child: CampBottomNav(selected: CampTab.profile)),
          ),
        ],
      ),
    );
  }
}
