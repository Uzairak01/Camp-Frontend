import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../bike_scan/presentation/screens/bike_details_screen.dart';
import '../../../dashboard/presentation/widgets/app_drawer_widget.dart';
import '../../../maintenance/controllers/post_ride_report_controller.dart';
import '../../../maintenance/domain/maintenance_prediction_engine.dart';
import '../../controllers/active_bike_controller.dart';
import '../../domain/bike_model.dart';
import '../../domain/fuel_estimator.dart';
import '../widgets/update_fuel_sheet.dart';
import 'bike_profile_screen.dart';

/// CAMP Garage Screen — Displays the rider's synchronized motorcycles,
/// active rig status, and standby fleet.
class GarageScreen extends StatelessWidget {
  const GarageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bikeController = ActiveBikeController.instance;

    return Scaffold(
      drawer: const AppDrawerWidget(),
      backgroundColor: AppColors.clay,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppColors.screenPadding,
                10,
                AppColors.screenPadding,
                110,
              ),
              child: ListenableBuilder(
                listenable: bikeController,
                builder: (context, _) {
                  final bikes = bikeController.bikes;
                  final activeBike = bikeController.activeBike;
                  final standbyBikes =
                      bikes.where((b) => b.id != activeBike?.id).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── 1. Top Header ─────────────────────────────────────
                      _buildHeader(context),

                      const SizedBox(height: 16),

                      // ── 2. Section Header: MY GARAGE (X BIKES) ────────────
                      _buildSectionHeader(context, bikes.length),

                      const SizedBox(height: 16),

                      if (bikes.isEmpty) ...[
                        _buildEmptyGarageCard(context),
                        const SizedBox(height: AppColors.cardGap),
                      ] else ...[
                        // ── 3. Active Bike Card ───────────────────────────────
                        if (activeBike != null) ...[
                          _buildActiveBikeCard(context, activeBike),
                          const SizedBox(height: AppColors.cardGap),
                        ],

                        // ── 4. Standby Bike Cards ─────────────────────────────
                        ...standbyBikes.map((bike) => Padding(
                              padding: const EdgeInsets.only(
                                  bottom: AppColors.cardGap),
                              child: _buildStandbyBikeCard(
                                context,
                                bike,
                                bikeController,
                              ),
                            )),
                      ],

                      // ── 5. Register Additional Bike Card ──────────────────
                      _buildRegisterAdditionalBikeCard(context),

                      const SizedBox(height: 8),
                    ],
                  );
                },
              ),
            ),

            // ── 6. Floating Bottom Navigation Dock ──────────────────────────
            const Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Center(
                child: CampBottomNav(
                  selected: CampTab.garage,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 1. Header (CampAppBar)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return CampAppBar(
      leading: CampAppBarLeading.back,
      onLeadingPressed: () => Navigator.of(context).maybePop(),
      actionWidget: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.clay,
          borderRadius: BorderRadius.circular(AppColors.radiusPill),
          boxShadow: AppColors.skeuRaisedSmall,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: AppColors.tacticalOrange,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'GARAGE',
              style: GoogleFonts.manrope(
                color: AppColors.darkCharcoal,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 2. Section Header: MY GARAGE (X BIKES) & + Add Bike Button
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildSectionHeader(BuildContext context, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MY GARAGE ($count ${count == 1 ? 'BIKE' : 'BIKES'})',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.tacticalOrangeDark,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Switch active rig or add a bike',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: AppColors.mutedText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pushNamed(CampRoutes.addBike),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.tacticalOrangeLight,
                  AppColors.tacticalOrange,
                  AppColors.tacticalOrangeDark,
                ],
              ),
              borderRadius: BorderRadius.circular(AppColors.radiusPill),
              boxShadow: AppColors.orangeGlow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.add_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  'Add Bike',
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 2b. Empty Garage State Card
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildEmptyGarageCard(BuildContext context) {
    return CampCard(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      borderRadius: AppColors.radiusCard,
      color: AppColors.clay,
      shadows: AppColors.skeuRaised,
      child: Center(
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.clayDark,
                boxShadow: AppColors.skeuRecessed,
              ),
              child: const Center(
                child: Icon(Icons.two_wheeler_rounded, size: 30, color: AppColors.mutedText),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No motorcycles in garage',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.darkCharcoal,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Add your motorcycle to track maintenance and stats.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(color: AppColors.mutedText),
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: 'Add motorcycle',
              icon: Icons.add_rounded,
              onTap: () => Navigator.of(context).pushNamed(CampRoutes.addBike),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 3. Active Bike Card
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildActiveBikeCard(BuildContext context, Bike bike) {
    final liters =
        FuelEstimator.currentLiters(bike) ?? bike.fuelRemainingLiters;
    final tankCap = bike.fuelTankCapacityLiters;
    final fuelAvg = bike.fuelAverageKmPerLiter;
    final rangeKm = FuelEstimator.rangeKm(liters, fuelAvg);
    final pct = FuelEstimator.percent(liters, tankCap);
    final fuelRatio = pct != null ? (pct / 100.0).clamp(0.0, 1.0) : 0.0;
    final String fuelText = liters == null
        ? 'Set fuel level'
        : (rangeKm != null
            ? '${liters.toStringAsFixed(1)} / ${tankCap?.toStringAsFixed(0) ?? '--'} L  •  about ${rangeKm.round()} km range'
            : '${liters.toStringAsFixed(1)} / ${tankCap?.toStringAsFixed(0) ?? '--'} L');

    final bikeReports =
        PostRideReportController.instance.getReportsForBike(bike.id);
    final assessment = MaintenancePredictionEngine.analyze(
      bike: bike,
      rideReports: bikeReports,
    );

    return CampCard(
      color: Colors.white,
      padding: const EdgeInsets.all(AppColors.cardPadding),
      borderRadius: AppColors.radiusCard,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => BikeProfileScreen(bike: bike),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Overline, Bike Name + Chevron, and ACTIVE Pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'ACTIVE RIG',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: AppColors.tacticalOrange,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: AppColors.tacticalOrange,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${bike.make} ${bike.modelName}',
                            style: GoogleFonts.manrope(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: AppColors.darkCharcoal,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.mutedLight,
                          size: 22,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _buildSubtitle(bike),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.tacticalOrange,
                  borderRadius: BorderRadius.circular(AppColors.radiusPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'ACTIVE',
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Bike Photo with Expand icon & single "● Manually Tracked" badge
          ClipRRect(
            borderRadius: BorderRadius.circular(AppColors.radiusTile),
            child: SizedBox(
              height: 180,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CampBikeImage(
                    imagePath: bike.imagePath,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.fullscreen_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E232A).withValues(alpha: 0.85),
                        borderRadius:
                            BorderRadius.circular(AppColors.radiusPill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF9CA3AF),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Manually Tracked',
                            style: GoogleFonts.manrope(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Stat Tile Grid (2x2)
          Row(
            children: [
              Expanded(
                child: InsetTile(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ENGINE', style: AppTextStyles.overline),
                      const SizedBox(height: 4),
                      Text(
                        bike.displacement != null ? '${_formatKm(bike.displacement!)} cc' : 'Not set',
                        style: AppTextStyles.statMedium.copyWith(fontSize: 17),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _engineSubtitle(bike),
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InsetTile(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FUEL TANK', style: AppTextStyles.overline),
                      const SizedBox(height: 4),
                      Text(
                        bike.fuelTankCapacityLiters != null ? '${bike.fuelTankCapacityLiters!.toStringAsFixed(0)} L' : 'Not set',
                        style: AppTextStyles.statMedium.copyWith(fontSize: 17),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        bike.fuelTankCapacityLiters != null
                            ? '${(bike.fuelTankCapacityLiters! / 3.78541).toStringAsFixed(1)} gal cap'
                            : 'Capacity not set',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: InsetTile(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ODOMETER', style: AppTextStyles.overline),
                      const SizedBox(height: 4),
                      Text(
                        _formatKm(bike.odometerKm),
                        style: AppTextStyles.statMedium.copyWith(fontSize: 17),
                      ),
                      const SizedBox(height: 2),
                      Text('km logged', style: AppTextStyles.caption),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InsetTile(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FUEL SYSTEM', style: AppTextStyles.overline),
                      const SizedBox(height: 4),
                      Text(
                        bike.fuelSystem == FuelSystem.efi
                            ? 'EFI'
                            : 'Carburetor',
                        style: AppTextStyles.statMedium.copyWith(fontSize: 17),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        bike.fuelSystem == FuelSystem.efi
                            ? 'Electronic Injection'
                            : (bike.carburetorType ?? 'Carburetor'),
                        style: AppTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Fuel Range Level Container
          InsetTile(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.local_gas_station_rounded,
                          size: 16,
                          color: AppColors.tacticalOrange,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Fuel Range Level',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkCharcoal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        fuelText,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        textAlign: TextAlign.end,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: liters == null
                              ? AppColors.tacticalOrange
                              : (pct != null && pct < 15.0
                                  ? AppColors.alertRed
                                  : (pct != null && pct < 25.0
                                      ? const Color(0xFFD97706)
                                      : AppColors.darkCharcoal)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 6,
                    child: LinearProgressIndicator(
                      value: fuelRatio,
                      backgroundColor: const Color(0xFFE5E7EB),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        pct == null
                            ? AppColors.tacticalOrange
                            : (pct < 15.0
                                ? AppColors.alertRed
                                : (pct < 25.0
                                    ? const Color(0xFFD97706)
                                    : AppColors.tacticalOrange)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => UpdateFuelSheet.show(context, bike),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
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
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.tacticalOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Text(
                      bike.fuelAverageKmPerLiter != null
                          ? 'Fuel Avg: ${bike.fuelAverageKmPerLiter!.toStringAsFixed(1)} km/L'
                          : 'Add fuel avg',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: bike.fuelAverageKmPerLiter != null
                            ? AppColors.mutedText
                            : AppColors.tacticalOrange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Health Status Pill — computed from MaintenancePredictionEngine
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: assessment.healthIndex >= 80
                  ? const Color(0xFFDCFCE7)
                  : (assessment.healthIndex >= 50
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFFEE2E2)),
              borderRadius: BorderRadius.circular(AppColors.radiusPill),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: assessment.healthIndex >= 80
                            ? AppColors.statusGreen
                            : (assessment.healthIndex >= 50
                                ? const Color(0xFFD97706)
                                : const Color(0xFFDC2626)),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${assessment.healthIndex}% • ${assessment.healthStatusLabel}',
                      style: GoogleFonts.manrope(
                        color: assessment.healthIndex >= 80
                            ? const Color(0xFF16A34A)
                            : (assessment.healthIndex >= 50
                                ? const Color(0xFFB45309)
                                : const Color(0xFFDC2626)),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text(
                    'Calculated from maintenance rule engine wear & service logs',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mutedText,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Compact Summary Line (Oil and Tune-Up)
          Row(
            children: [
              const Icon(
                Icons.settings_outlined,
                size: 14,
                color: AppColors.mutedText,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Oil: ${_oilSummary(bike)} • Tune-Up: ${_tuneUpSummary(bike)}',
                  style: GoogleFonts.manrope(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedText,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Action Row: Primary Active, Edit, Trash
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9F5EF),
                    borderRadius: BorderRadius.circular(AppColors.radiusPill),
                    border: Border.all(
                      color: const Color(0xFF86EFAC).withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Primary Active',
                        style: GoogleFonts.manrope(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) =>
                          BikeDetailsScreen(initialBike: bike),
                    ),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.clay,
                    borderRadius: BorderRadius.circular(AppColors.radiusPill),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.08),
                      width: 1,
                    ),
                    boxShadow: AppColors.skeuRaisedSmall,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.edit_outlined,
                        size: 15,
                        color: AppColors.darkCharcoal,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Edit',
                        style: GoogleFonts.manrope(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showDeleteConfirmation(context, bike),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5F5),
                    borderRadius: BorderRadius.circular(AppColors.radiusTile),
                    border: Border.all(
                      color: const Color(0xFFFEE2E2),
                      width: 1,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.alertRed,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 4. Standby Bike Card
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildStandbyBikeCard(
    BuildContext context,
    Bike bike,
    ActiveBikeController controller,
  ) {
    return CampCard(
      color: Colors.white,
      padding: const EdgeInsets.all(AppColors.cardPadding),
      borderRadius: AppColors.radiusCard,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => BikeProfileScreen(bike: bike),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Overline, Bike Name, Subtitle, STANDBY pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STANDBY RIG',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.mutedLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${bike.make} ${bike.modelName}',
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkCharcoal,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _buildSubtitle(bike),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.clayDark,
                  borderRadius: BorderRadius.circular(AppColors.radiusPill),
                ),
                child: Text(
                  'STANDBY',
                  style: GoogleFonts.manrope(
                    color: AppColors.mutedText,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Compact Row with bike icon, displacement/twin, tank/km, and Manual badge
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.clayDark,
              borderRadius: BorderRadius.circular(AppColors.radiusTile),
              boxShadow: AppColors.skeuRecessed,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEDD5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.two_wheeler_rounded,
                      color: AppColors.tacticalOrange,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bike.displacement != null
                            ? '${_formatKm(bike.displacement!)} cc • ${_engineSubtitle(bike)}'
                            : _engineSubtitle(bike),
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${bike.fuelTankCapacityLiters != null ? '${bike.fuelTankCapacityLiters!.toStringAsFixed(0)} L Tank • ' : ''}${_formatKm(bike.odometerKm)} km logged',
                        style: AppTextStyles.caption,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Fuel System: ${bike.fuelSystem == FuelSystem.efi ? 'EFI' : 'Carburetor'}',
                        style: GoogleFonts.manrope(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.clay,
                        borderRadius:
                            BorderRadius.circular(AppColors.radiusPill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Color(0xFF9CA3AF),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Manual',
                            style: GoogleFonts.manrope(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkCharcoal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Compact Summary Line (Oil and Tune-Up)
          Row(
            children: [
              const Icon(
                Icons.settings_outlined,
                size: 14,
                color: AppColors.mutedText,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Oil: ${_oilSummary(bike)} • Tune-Up: ${_tuneUpSummary(bike)}',
                  style: GoogleFonts.manrope(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedText,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Action Row: Set as Active Rig, Edit, Trash
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    controller.setActiveBike(bike.id);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius:
                          BorderRadius.circular(AppColors.radiusPill),
                      border: Border.all(
                        color: AppColors.tacticalOrange,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: AppColors.tacticalOrange,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Set as Active Rig',
                          style: GoogleFonts.manrope(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.tacticalOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) =>
                          BikeDetailsScreen(initialBike: bike),
                    ),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.clay,
                    borderRadius: BorderRadius.circular(AppColors.radiusPill),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.08),
                      width: 1,
                    ),
                    boxShadow: AppColors.skeuRaisedSmall,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.edit_outlined,
                        size: 15,
                        color: AppColors.darkCharcoal,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Edit',
                        style: GoogleFonts.manrope(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showDeleteConfirmation(context, bike),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5F5),
                    borderRadius: BorderRadius.circular(AppColors.radiusTile),
                    border: Border.all(
                      color: const Color(0xFFFEE2E2),
                      width: 1,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.alertRed,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 5. Register Additional Bike Card
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildRegisterAdditionalBikeCard(BuildContext context) {
    return CustomPaint(
      painter: const _DashedBorderPainter(
        color: Color(0xFFFFB37C),
        strokeWidth: 1.5,
        dashLength: 6,
        dashGap: 4,
        borderRadius: AppColors.radiusCard,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppColors.radiusCard),
        ),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: Color(0xFFFFEDD5),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.add_rounded,
                  color: AppColors.tacticalOrange,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Register Additional Bike',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.darkCharcoal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add a bike to start tracking its maintenance',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.mutedText,
                fontSize: 12.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: '+ Add a Motorcycle',
              isFullWidth: true,
              onTap: () => Navigator.of(context).pushNamed(CampRoutes.addBike),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> _showDeleteConfirmation(BuildContext context, Bike bike) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.clay,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusCard),
        ),
        title: Text(
          'Remove Motorcycle?',
          style: AppTextStyles.title.copyWith(fontSize: 18),
        ),
        content: Text(
          'Are you sure you want to remove ${bike.make} ${bike.modelName} from your garage fleet?',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.manrope(
                color: AppColors.mutedText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alertRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusPill),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Remove Bike',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ActiveBikeController.instance.removeBike(bike.id);
    }
  }

  String _buildSubtitle(Bike bike) {
    return bike.formattedSubtitle;
  }

  String _engineSubtitle(Bike bike) {
    if (bike.make == 'BMW' && (bike.displacement ?? 0) > 1000) {
      return 'Boxer Twin';
    }
    if (bike.bikeType != null && bike.bikeType!.isNotEmpty) {
      return '${bike.bikeType} Engine';
    }
    if (bike.displacement != null) {
      return '${bike.displacement} cc';
    }
    return 'Engine Specs';
  }

  String _oilSummary(Bike bike) {
    if (bike.lastOilChange?.km != null) {
      return '${_formatKm(bike.lastOilChange!.km!)} km ago';
    }
    if (bike.lastOilChange?.date != null) {
      return _formatDate(bike.lastOilChange!.date!);
    }
    return 'No record';
  }

  String _tuneUpSummary(Bike bike) {
    if (bike.lastTuneUp?.date != null) {
      return _formatDate(bike.lastTuneUp!.date!);
    }
    if (bike.lastTuneUp?.km != null) {
      return '${_formatKm(bike.lastTuneUp!.km!)} km';
    }
    return 'No record';
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final month = months[date.month - 1];
    final day = date.day.toString().padLeft(2, '0');
    return '$month $day, ${date.year}';
  }

  String _formatKm(int km) {
    final str = km.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i > 0) {
        buffer.write(',');
      }
    }
    return buffer.toString().split('').reversed.join('');
  }
}

/// Custom painter for dashed outline around [Register Additional Bike] card
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.dashGap,
    required this.borderRadius,
  });

  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double dashGap;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(borderRadius),
    );

    final path = Path()..addRRect(rrect);
    final pathMetrics = path.computeMetrics();

    for (final metric in pathMetrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final length = (distance + dashLength < metric.length)
            ? dashLength
            : metric.length - distance;
        final extract = metric.extractPath(distance, distance + length);
        canvas.drawPath(extract, paint);
        distance += dashLength + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth ||
      dashLength != oldDelegate.dashLength ||
      dashGap != oldDelegate.dashGap ||
      borderRadius != oldDelegate.borderRadius;
}
