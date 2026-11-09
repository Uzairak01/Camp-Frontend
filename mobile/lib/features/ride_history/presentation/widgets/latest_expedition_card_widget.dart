import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../garage/controllers/active_bike_controller.dart';
import '../../../maintenance/controllers/trip_budget_controller.dart';
import '../../../maintenance/domain/expense_model.dart';
import '../../../maintenance/domain/post_ride_report.dart';
import '../../../maintenance/domain/trip_budget_model.dart';
import '../../domain/stat_model.dart';
import 'dark_info_tile_widget.dart';
import 'dark_stat_tile_widget.dart';

enum LatestExpeditionOptionAction {
  shareRide,
  deleteRide,
}

/// Cockpit-gradient hero card for the latest ride.
/// Shows real ride report data, date, terrain, bike name, and fuel entries.
/// Elevation chart, track replay, waypoint logs, and synthetic telemetry have been removed.
class LatestExpeditionCardWidget extends StatelessWidget {
  const LatestExpeditionCardWidget({
    super.key,
    this.report,
    this.onMenuActionSelected,
  });

  final PostRideReport? report;
  final ValueChanged<LatestExpeditionOptionAction>? onMenuActionSelected;

  @override
  Widget build(BuildContext context) {
    if (report == null) {
      return CockpitHeroCard(
        innerPadding: const EdgeInsets.all(AppColors.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.tacticalOrange,
                    borderRadius: BorderRadius.circular(AppColors.radiusPill),
                  ),
                  child: Text(
                    'LATEST RIDE',
                    style: GoogleFonts.manrope(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.two_wheeler_rounded,
                    size: 38,
                    color: Colors.white24,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No rides yet',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Record a ride to view route stats and fuel spent.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    }

    final effectiveReport = report!;
    final dateDisplay = formatTripDate(effectiveReport.date);
    final activeBike = ActiveBikeController.instance.activeBike;
    final bikeName = activeBike != null
        ? '${activeBike.make} ${activeBike.modelName}'
        : 'Motorcycle';

    final title = effectiveReport.notes != null &&
            effectiveReport.notes!.trim().isNotEmpty
        ? effectiveReport.notes!.trim()
        : (effectiveReport.terrainTags.isNotEmpty
            ? '${effectiveReport.terrainTags.join(' • ')} Ride'
            : 'Ride Debrief');

    final stats = [
      Stat(
        label: 'DISTANCE',
        value: effectiveReport.distanceKm > 0
            ? effectiveReport.distanceKm.toStringAsFixed(1)
            : '0.0',
        unit: 'KM',
      ),
      Stat(
        label: 'DATE',
        value:
            '${kTripMonths[effectiveReport.date.toLocal().month - 1]} ${effectiveReport.date.toLocal().day}',
      ),
      Stat(
        label: 'TERRAIN',
        value: effectiveReport.terrainTags.isNotEmpty
            ? effectiveReport.terrainTags.first
            : 'Road',
      ),
    ];

    return CockpitHeroCard(
      innerPadding: const EdgeInsets.all(AppColors.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: badge + date + popup menu button ──────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.tacticalOrange,
                        borderRadius:
                            BorderRadius.circular(AppColors.radiusPill),
                      ),
                      child: Text(
                        'LATEST RIDE',
                        style: GoogleFonts.manrope(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        dateDisplay,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _ExpeditionOptionsMenuButton(
                onSelected: onMenuActionSelected,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Title ──────────────────────────────────────────────────────────
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
              height: 1.25,
            ),
          ),

          const SizedBox(height: 6),

          // ── Bike line (no "Active Fleet") ──────────────────────────────────
          Text(
            '🏍 $bikeName',
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),

          const SizedBox(height: 14),

          // ── 3 dark stats ───────────────────────────────────────────────────
          Row(
            children: [
              for (int i = 0; i < stats.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: DarkStatTile(stat: stats[i]),
                ),
              ],
            ],
          ),

          const SizedBox(height: 14),

          // ── Two info tiles: Terrain and Fuel Spent ─────────────────────────
          Row(
            children: [
              Expanded(
                child: DarkInfoTileWidget(
                  category: 'TERRAIN CONDITIONS',
                  primaryLine: effectiveReport.terrainTags.isNotEmpty
                      ? effectiveReport.terrainTags.join('\n')
                      : 'Road\nNominal conditions',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final activeBike = ActiveBikeController.instance.activeBike;
                    final fuelExpenses = TripBudgetController.instance.expenses
                        .where((e) {
                          if (e.category != ExpenseCategory.fuel) return false;
                          if (activeBike != null && activeBike.id.isNotEmpty) {
                            return e.bikeId == null ||
                                e.bikeId!.isEmpty ||
                                e.bikeId == activeBike.id;
                          }
                          return true;
                        })
                        .toList();
                    final totalFuel = fuelExpenses.fold<double>(
                        0.0, (sum, e) => sum + e.amount);

                    final hasFuel = totalFuel > 0;
                    final primary = hasFuel
                        ? formatPkr(totalFuel)
                        : 'No fuel logged';
                    final note = hasFuel
                        ? 'All refills for this bike (${fuelExpenses.length})'
                        : 'All refills for this bike';

                    return DarkInfoTileWidget(
                      category: 'FUEL SPENT (ALL REFILLS)',
                      primaryLine: primary,
                      noteLine: note,
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExpeditionOptionsMenuButton extends StatelessWidget {
  const _ExpeditionOptionsMenuButton({
    this.onSelected,
  });

  final ValueChanged<LatestExpeditionOptionAction>? onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<LatestExpeditionOptionAction>(
      icon: Icon(
        Icons.more_horiz_rounded,
        size: 20,
        color: Colors.white.withValues(alpha: 0.55),
      ),
      color: AppColors.dockBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      onSelected: onSelected,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: LatestExpeditionOptionAction.shareRide,
          child: Row(
            children: [
              const Icon(
                Icons.share_outlined,
                size: 16,
                color: Colors.white70,
              ),
              const SizedBox(width: 10),
              Text(
                'Share Ride',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: LatestExpeditionOptionAction.deleteRide,
          child: Row(
            children: [
              const Icon(
                Icons.delete_outline_rounded,
                size: 16,
                color: Colors.white70,
              ),
              const SizedBox(width: 10),
              Text(
                'Delete ride',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
