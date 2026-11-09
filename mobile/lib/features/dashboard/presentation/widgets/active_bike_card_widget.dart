import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../garage/controllers/active_bike_controller.dart';
import '../../../garage/domain/bike_model.dart';
import '../../../garage/domain/fuel_estimator.dart';
import '../../../garage/presentation/widgets/update_fuel_sheet.dart';
import '../../../garage/services/fuel_tracker_service.dart';
import '../../../maintenance/controllers/maintenance_controller.dart';
import '../../../maintenance/domain/maintenance_prediction_engine.dart';
import 'ride_summary_sheet.dart';

/// Active Motorcycle Overview — skeuomorphic raised card bound to [ActiveBikeController] and [FuelTrackerService].
class ActiveBikeCardWidget extends StatefulWidget {
  const ActiveBikeCardWidget({super.key, this.onDetailsPressed});

  final VoidCallback? onDetailsPressed;

  @override
  State<ActiveBikeCardWidget> createState() => _ActiveBikeCardWidgetState();
}

class _ActiveBikeCardWidgetState extends State<ActiveBikeCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Color _getFuelBarColor(double? pct) {
    if (pct == null) return AppColors.tacticalOrange;
    if (pct < 15.0) return AppColors.alertRed;
    if (pct < 25.0) return const Color(0xFFD97706);
    return AppColors.tacticalOrange;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ActiveBikeController.instance,
        FuelTrackerService.instance,
        MaintenanceController.instance,
      ]),
      builder: (context, _) {
        final bike = ActiveBikeController.instance.activeBike;
        final fuelTracker = FuelTrackerService.instance;

        if (bike == null) {
          return ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 450),
            child: CampCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ACTIVE MOTORCYCLE',
                        style: AppTextStyles.overlineTerracotta,
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () =>
                            Navigator.of(context).pushNamed(CampRoutes.addBike),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.clay,
                            borderRadius:
                                BorderRadius.circular(AppColors.radiusPill),
                            boxShadow: AppColors.skeuRaisedSmall,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add_rounded,
                                  size: 14, color: AppColors.tacticalOrange),
                              const SizedBox(width: 4),
                              Text(
                                'ADD BIKE',
                                style: AppTextStyles.overlineTerracotta.copyWith(
                                    fontSize: 10, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: CampEmptyState(
                        icon: Icons.two_wheeler_rounded,
                        message: 'No motorcycle active in your garage',
                        ctaLabel: 'Add your bike',
                        onCta: () =>
                            Navigator.of(context).pushNamed(CampRoutes.addBike),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final liters =
            FuelEstimator.currentLiters(bike) ?? bike.fuelRemainingLiters;
        final tankCap = bike.fuelTankCapacityLiters;
        final fuelAvg = bike.fuelAverageKmPerLiter;
        final rangeKm = FuelEstimator.rangeKm(liters, fuelAvg);
        final pct = FuelEstimator.percent(liters, tankCap);
        final double fuelRatio =
            pct != null ? (pct / 100.0).clamp(0.0, 1.0) : 0.0;

        final String fuelText = liters == null
            ? 'Set fuel level'
            : (rangeKm != null
                ? '${liters.toStringAsFixed(1)} / ${tankCap?.toStringAsFixed(0) ?? '--'} L  •  about ${rangeKm.round()} km range'
                : '${liters.toStringAsFixed(1)} / ${tankCap?.toStringAsFixed(0) ?? '--'} L');

        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 450),
          child: CampCard(
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ACTIVE MOTORCYCLE',
                    style: AppTextStyles.overlineTerracotta,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () =>
                            Navigator.of(context).pushNamed(CampRoutes.addBike),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.clay,
                            borderRadius:
                                BorderRadius.circular(AppColors.radiusPill),
                            boxShadow: AppColors.skeuRaisedSmall,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add_rounded,
                                  size: 14, color: AppColors.tacticalOrange),
                              const SizedBox(width: 4),
                              Text(
                                'ADD BIKE',
                                style:
                                    AppTextStyles.overlineTerracotta.copyWith(
                                  fontSize: 10,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconTile(
                        icon: Icons.two_wheeler_rounded,
                        size: 40,
                        isInset: false,
                        onTap: widget.onDetailsPressed,
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Text(bike.name, style: AppTextStyles.title),
              const SizedBox(height: 3),
              Text(
                bike.edition != null && bike.edition!.isNotEmpty
                    ? '${bike.edition} • ${bike.modelYear}'
                    : '${bike.make} • ${bike.modelYear}',
                style: AppTextStyles.bodySecondary,
              ),

              const SizedBox(height: 14),

              // ── Motorcycle visual showcase — inset recessed surface ───────
              GestureDetector(
                onTap: widget.onDetailsPressed,
                child: InsetTile(
                  borderRadius: AppColors.radiusTile,
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    height: 130,
                    child: Center(
                      child: _buildBikeShowcaseContent(bike),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Specs tiles row ───────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _specTile(
                      bike.displacement != null
                          ? '${bike.displacement} cc'
                          : (bike.bikeType ?? 'Engine'),
                      bike.fuelSystem == FuelSystem.efi
                          ? 'Electronic EFI'
                          : 'Carburetor',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _specTile(
                      bike.fuelTankCapacityLiters != null
                          ? '${bike.fuelTankCapacityLiters!.toStringAsFixed(0)} L'
                          : 'Tank',
                      'Capacity',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _specTile(
                      '${bike.odometerKm} km',
                      'logged',
                    ),
                  ),
                ],
              ),

              // ── Ride Tracking Control ──────────────────────────────
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.clay,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppColors.skeuRaisedSmall,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: fuelTracker.isRiding
                                ? const Color(0xFF10B981)
                                : AppColors.mutedText,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fuelTracker.isRiding
                                  ? 'RIDE IN PROGRESS'
                                  : 'RIDE TRACKER',
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.darkCharcoal,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              fuelTracker.isRiding
                                  ? '${fuelTracker.rideDistanceKm.toStringAsFixed(1)} km tracked'
                                  : 'Distance & fuel estimate',
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.mutedText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: fuelTracker.isRiding
                            ? AppColors.alertRed
                            : AppColors.tacticalOrange,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 1,
                      ),
                      icon: Icon(
                        fuelTracker.isRiding
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      label: Text(
                        fuelTracker.isRiding ? 'Stop ride' : 'Start ride',
                        style: GoogleFonts.manrope(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      onPressed: () async {
                        if (fuelTracker.isRiding) {
                          await RideSummarySheet.finishRideAndShowSummary(context);
                        } else {
                          await fuelTracker.startRide();
                        }
                      },
                    ),
                  ],
                ),
              ),

              if (fuelTracker.locationErrorMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.alertRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.alertRed.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_off_rounded,
                          size: 16, color: AppColors.alertRed),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          fuelTracker.locationErrorMessage!,
                          style: GoogleFonts.manrope(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.alertRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Low Fuel Warning Banner ───────────────────────────
              if (pct != null && pct < 15.0) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.alertRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.alertRed, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppColors.alertRed, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          rangeKm != null
                              ? 'Low fuel: about ${rangeKm.round()} km left. Please refill.'
                              : 'Low fuel warning. Please refill.',
                          style: GoogleFonts.manrope(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.alertRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Fuel Level ────────────────
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.local_gas_station_rounded,
                        size: 16,
                        color: AppColors.terracotta,
                      ),
                      const SizedBox(width: 6),
                      Text('Fuel Level', style: AppTextStyles.itemTitle),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => UpdateFuelSheet.show(context, bike),
                      child: Text(
                        fuelText,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        textAlign: TextAlign.end,
                        style: AppTextStyles.body.copyWith(
                          color: liters == null
                              ? AppColors.tacticalOrange
                              : (pct != null && pct < 15.0
                                  ? AppColors.alertRed
                                  : (pct != null && pct < 25.0
                                      ? const Color(0xFFD97706)
                                      : AppColors.darkCharcoal)),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => UpdateFuelSheet.show(context, bike),
                child: InsetTile(
                  borderRadius: 8,
                  padding: EdgeInsets.zero,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: SizedBox(
                      height: 10,
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (fuelRatio).clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _getFuelBarColor(pct),
                            borderRadius: const BorderRadius.all(
                              Radius.circular(7),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => UpdateFuelSheet.show(context, bike),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.clay,
                      borderRadius:
                          BorderRadius.circular(AppColors.radiusPill),
                      boxShadow: AppColors.skeuRaisedSmall,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.edit_rounded,
                            size: 12, color: AppColors.tacticalOrange),
                        const SizedBox(width: 4),
                        Text(
                          liters == null
                              ? 'Set fuel level'
                              : 'Update fuel level',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.tacticalOrange,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Service Status ────────────────────────────────────────────
              Builder(
                builder: (context) {
                  final hasData = MaintenanceController.instance.hasMaintenanceData(bike);
                  final urgentItem = MaintenanceController.instance.mostUrgentItem(bike.id);

                  final String statusSubtitle;
                  final Widget statusTrailing;

                  if (!hasData) {
                    statusSubtitle = 'Set up your service schedule';
                    statusTrailing = const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.mutedLight,
                      size: 20,
                    );
                  } else if (urgentItem != null) {
                    final isOverdue = urgentItem.status == ComponentStatus.overdue;
                    if (isOverdue) {
                      statusSubtitle = '${urgentItem.name} overdue';
                      statusTrailing = const StatusChip(
                        label: 'OVERDUE',
                        variant: StatusChipVariant.danger,
                      );
                    } else {
                      if (urgentItem.remainingKm != null) {
                        statusSubtitle = '${urgentItem.name} in ${urgentItem.remainingKm} km';
                      } else if (urgentItem.remainingDays != null) {
                        statusSubtitle = '${urgentItem.name} in ${urgentItem.remainingDays} days';
                      } else {
                        statusSubtitle = '${urgentItem.name} due soon';
                      }
                      statusTrailing = const StatusChip(
                        label: 'DUE SOON',
                        variant: StatusChipVariant.warning,
                      );
                    }
                  } else {
                    statusSubtitle = 'All maintenance up to date';
                    statusTrailing = const StatusChip(
                      label: 'ALL OK',
                      variant: StatusChipVariant.success,
                    );
                  }

                  return InkWell(
                    onTap: () => CampBottomNav.navigateToTab(context, CampTab.finances),
                    borderRadius: BorderRadius.circular(AppColors.radiusTile),
                    child: CampCard(
                      borderRadius: AppColors.radiusTile,
                      shadows: AppColors.skeuRaisedSmall,
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const IconTile(
                            icon: Icons.tune_rounded,
                            iconColor: AppColors.terracotta,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Service Status',
                                    style: AppTextStyles.itemTitle),
                                const SizedBox(height: 3),
                                Text(
                                  statusSubtitle,
                                  style: AppTextStyles.caption,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          statusTrailing,
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
  }

  Widget _buildBikeShowcaseContent(Bike bike) {
    if (bike.imagePath != null && bike.imagePath!.isNotEmpty) {
      return CampBikeImage(
        imagePath: bike.imagePath,
        width: double.infinity,
        height: 130,
        fit: BoxFit.cover,
        borderRadius: BorderRadius.circular(AppColors.radiusTile - 4),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.sports_motorsports_rounded,
          size: 52,
          color: AppColors.darkCharcoal.withValues(alpha: 0.25),
        ),
        const SizedBox(height: 8),
        Text(
          bike.name,
          style: AppTextStyles.bodySecondary.copyWith(
            color: AppColors.darkCharcoal.withValues(alpha: 0.4),
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  Widget _specTile(String title, String sub) => InsetTile(
        borderRadius: 14,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Column(
          children: [
            Text(
              title,
              style: AppTextStyles.itemTitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
}
