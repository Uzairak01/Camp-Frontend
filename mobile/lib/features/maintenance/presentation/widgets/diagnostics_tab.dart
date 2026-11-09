import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/camp_card.dart';
import '../../../../core/widgets/inset_tile.dart';
import '../../../garage/domain/bike_model.dart';
import '../../controllers/maintenance_controller.dart';
import '../../controllers/post_ride_report_controller.dart';
import '../../domain/maintenance_prediction_engine.dart';
import '../../domain/service_schedule_item.dart';
import '../screens/post_ride_debrief_screen.dart';
import '../screens/service_schedule_screen.dart';
import 'mark_service_done_dialog.dart';

/// Tab 1 — Maintenance Health Index, component wear analysis, and pattern
/// intelligence. All values are computed deterministically from user-entered
/// bike data (odometer, service records, terrain) and logged PostRideReports.
/// No sensor, OBD-II, or ECU data is used.
class DiagnosticsTab extends StatelessWidget {
  const DiagnosticsTab({
    required this.bike,
    this.onSwitchToPostRide,
    super.key,
  });

  final Bike bike;

  /// Optional callback invoked when the user taps "Log Post-Ride Debrief".
  /// If null, pushes [PostRideDebriefScreen].
  final VoidCallback? onSwitchToPostRide;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        MaintenanceController.instance,
        PostRideReportController.instance,
      ]),
      builder: (context, _) {
        final reports = PostRideReportController.instance.getReportsForBike(bike.id);
        final assessment = MaintenancePredictionEngine.analyze(
          bike: bike,
          rideReports: reports,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Maintenance Health Index Card ──────────────────────────────
            _buildHealthIndexCard(assessment),
            const SizedBox(height: 14),

            // ── 1b. Service Schedule Setup Entry ──────────────────────────────
            CampCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ServiceScheduleScreen(bikeId: bike.id),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(AppColors.radiusCard),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      color: AppColors.tacticalOrange,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Service Schedule',
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.darkCharcoal,
                            ),
                          ),
                          Text(
                            'Set service intervals & riding conditions',
                            style: GoogleFonts.manrope(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.mutedLight,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // ── 2. Component Analysis & Wear Section ──────────────────────────
            Text(
              'COMPONENT ANALYSIS & WEAR',
              style: GoogleFonts.manrope(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.mutedText,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),

            ...assessment.components.map((component) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildComponentCard(context, component),
                )),

            const SizedBox(height: 10),

            // ── 3. CAMP Predictive Intelligence Section ────────────────────────
            _buildPredictiveIntelligenceSection(context, assessment),
            const SizedBox(height: 16),

            // ── 4. Finances & Rig Health Banner ───────────────────────────────
            _buildFinancesBanner(context),
          ],
        );
      },
    );
  }

  // ── Health Index Card ─────────────────────────────────────────────────────
  Widget _buildHealthIndexCard(MaintenanceAssessment assessment) {
    final statusColor = assessment.healthIndex >= 80
        ? AppColors.statusGreen
        : (assessment.healthIndex >= 60
            ? AppColors.tacticalOrange
            : const Color(0xFFDC2626));

    return CampCard(
      padding: const EdgeInsets.all(18),
      borderRadius: AppColors.radiusCard,
      color: AppColors.clay,
      shadows: AppColors.skeuRaised,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MAINTENANCE HEALTH INDEX',
                  style: GoogleFonts.manrope(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.mutedText,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${assessment.healthIndex}',
                      style: GoogleFonts.manrope(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: AppColors.darkCharcoal,
                      ),
                    ),
                    Text(
                      '/100',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mutedLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 15,
                      color: AppColors.tacticalOrangeDark,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'Next service in ${_formatNumber(assessment.nextServiceKm)} km or ${assessment.nextServiceDays} days',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.tacticalOrangeDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 70,
                  height: 70,
                  child: CircularProgressIndicator(
                    value: assessment.healthIndex / 100,
                    strokeWidth: 7.5,
                    backgroundColor: AppColors.clayDark,
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${assessment.healthIndex}%',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.darkCharcoal,
                      ),
                    ),
                    Text(
                      assessment.healthStatusLabel,
                      style: GoogleFonts.manrope(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Component Card ────────────────────────────────────────────────────────
  Widget _buildComponentCard(BuildContext context, ComponentPrediction component) {
    final Color badgeBg;
    final Color badgeTextColor;
    final Color dotColor;

    switch (component.status) {
      case ComponentStatus.overdue:
        dotColor = const Color(0xFFDC2626);
        badgeBg = const Color(0xFFFEE2E2);
        badgeTextColor = const Color(0xFFB91C1C);
        break;
      case ComponentStatus.dueSoon:
        dotColor = AppColors.tacticalOrange;
        badgeBg = const Color(0xFFFFEDD5);
        badgeTextColor = AppColors.tacticalOrangeDark;
        break;
      case ComponentStatus.ok:
        if (component.scheduleStatus == ScheduleItemStatus.notSetUp) {
          dotColor = AppColors.mutedLight;
          badgeBg = AppColors.clayDark;
          badgeTextColor = AppColors.mutedText;
        } else if (component.scheduleStatus == ScheduleItemStatus.addLastDone) {
          dotColor = AppColors.tacticalOrange;
          badgeBg = AppColors.tacticalOrange.withValues(alpha: 0.15);
          badgeTextColor = AppColors.tacticalOrangeDark;
        } else {
          dotColor = AppColors.statusGreen;
          badgeBg = const Color(0xFFD1FAE5);
          badgeTextColor = const Color(0xFF047857);
        }
        break;
    }

    return CampCard(
      padding: const EdgeInsets.all(16),
      borderRadius: AppColors.radiusCard,
      color: AppColors.clay,
      shadows: AppColors.skeuRaised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  component.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkCharcoal,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(AppColors.radiusPill),
                ),
                child: Text(
                  component.statusBadgeText,
                  style: GoogleFonts.manrope(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: badgeTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (component.wearPercent / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppColors.clayDark,
              valueColor: AlwaysStoppedAnimation<Color>(dotColor),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            component.reason,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.darkCharcoal.withValues(alpha: 0.85),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: const BorderSide(color: AppColors.clayDark),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusPill),
                  ),
                ),
                icon: const Icon(Icons.check_circle_outline_rounded,
                    size: 14, color: AppColors.statusGreen),
                label: Text(
                  'Mark Done',
                  style: GoogleFonts.manrope(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkCharcoal,
                  ),
                ),
                onPressed: () {
                  final scheduleItems =
                      MaintenanceController.instance.getScheduleItems(bike.id);
                  final item = scheduleItems.firstWhere(
                    (i) =>
                        i.id == component.id ||
                        i.type.displayName == component.name,
                    orElse: () => scheduleItems.first,
                  );
                  MarkServiceDoneDialog.show(context, bike: bike, item: item);
                },
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showDiyGuide(context, component),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View DIY Guide >',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.tacticalOrangeDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Predictive Intelligence Section ───────────────────────────────────────
  Widget _buildPredictiveIntelligenceSection(BuildContext context, MaintenanceAssessment assessment) {
    return CampCard(
      padding: const EdgeInsets.all(16),
      borderRadius: AppColors.radiusCard,
      color: AppColors.clay,
      shadows: AppColors.skeuRaised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, size: 20, color: AppColors.tacticalOrange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'CAMP PREDICTIVE INTELLIGENCE',
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkCharcoal,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (assessment.hasSufficientRideLogs && assessment.patternInsights.isNotEmpty) ...[
            ...assessment.patternInsights.map((insight) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InsetTile(
                    padding: const EdgeInsets.all(14),
                    borderRadius: AppColors.radiusTile,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                insight.title,
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.darkCharcoal,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEDD5),
                                borderRadius: BorderRadius.circular(AppColors.radiusPill),
                              ),
                              child: Text(
                                insight.percentageBadge,
                                style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.tacticalOrangeDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          insight.description,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.darkCharcoal,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          insight.recommendation,
                          style: GoogleFonts.manrope(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mutedText,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
          ] else ...[
            InsetTile(
              padding: const EdgeInsets.all(18),
              borderRadius: AppColors.radiusTile,
              child: Column(
                children: [
                  const Icon(Icons.auto_graph_rounded, size: 36, color: AppColors.mutedLight),
                  const SizedBox(height: 10),
                  Text(
                    'Log a few rides to unlock pattern insights.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkCharcoal,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'After logging at least 3 post-ride reports, CAMP summarizes your ride distance, terrain mix, and average km per day.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.mutedText,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (onSwitchToPostRide != null) {
                        onSwitchToPostRide!();
                      } else {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PostRideDebriefScreen(bikeId: bike.id),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.tacticalOrange,
                        borderRadius: BorderRadius.circular(AppColors.radiusTile),
                        boxShadow: AppColors.skeuRaisedSmall,
                      ),
                      child: Text(
                        'Log Post-Ride Debrief',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Finances Banner ───────────────────────────────────────────────────────
  Widget _buildFinancesBanner(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pushNamed(CampRoutes.financeRigHealth),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.clay,
          borderRadius: BorderRadius.circular(AppColors.radiusCard),
          border: const Border(
            left: BorderSide(color: AppColors.tacticalOrange, width: 3.5),
          ),
          boxShadow: AppColors.skeuRaisedSmall,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.lightbulb_outline_rounded, color: AppColors.tacticalOrange, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Parts costs and budgets are tracked in Finances & Rig Health.',
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkCharcoal,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'View →',
              style: GoogleFonts.manrope(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.tacticalOrangeDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── DIY Guide Modal ───────────────────────────────────────────────────────
  void _showDiyGuide(BuildContext context, ComponentPrediction component) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: AppColors.clay,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: AppColors.skeuRaised,
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4.5,
                decoration: BoxDecoration(
                  color: AppColors.mutedLight,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(Icons.build_circle_rounded, size: 24, color: AppColors.tacticalOrange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            component.diyGuideTitle,
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppColors.darkCharcoal,
                            ),
                          ),
                          Text(
                            'CAMP Field Service Guide • ${component.name}',
                            style: GoogleFonts.manrope(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                      color: AppColors.mutedText,
                    ),
                  ],
                ),
              ),
              const Divider(height: 20, color: AppColors.clayDark),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: component.diySteps.length,
                  separatorBuilder: (context, _) => const SizedBox(height: 12),
                  itemBuilder: (context, idx) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.clayDark,
                            shape: BoxShape.circle,
                            boxShadow: AppColors.skeuRaisedSmall,
                          ),
                          child: Center(
                            child: Text(
                              '${idx + 1}',
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: AppColors.tacticalOrangeDark,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            component.diySteps[idx],
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkCharcoal,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.tacticalOrange,
                      borderRadius: BorderRadius.circular(AppColors.radiusTile),
                      boxShadow: AppColors.orangeGlow,
                    ),
                    child: Center(
                      child: Text(
                        'Done',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }
}
