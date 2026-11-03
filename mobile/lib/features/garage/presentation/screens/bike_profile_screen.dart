import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/data/app_repositories.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../bike_scan/presentation/screens/bike_details_screen.dart';
import '../../../maintenance/controllers/post_ride_report_controller.dart';
import '../../../maintenance/domain/maintenance_item_model.dart';
import '../../../maintenance/domain/maintenance_prediction_engine.dart';
import '../../../maintenance/domain/post_ride_report.dart';
import '../../controllers/active_bike_controller.dart';
import '../../domain/bike_model.dart';
import '../../domain/fuel_estimator.dart';
import '../../services/fuel_tracker_service.dart';
import '../widgets/update_fuel_sheet.dart';

/// Read-only detail view for a single motorcycle in CAMP.
/// Displays telemetry status, specifications, maintenance health summary,
/// riding terrain configuration, and recent trips.
class BikeProfileScreen extends StatefulWidget {
  const BikeProfileScreen({
    super.key,
    this.bike,
    this.bikeId,
  });

  /// Specific bike instance passed directly.
  final Bike? bike;

  /// Identifier of the bike to load from [ActiveBikeController].
  final String? bikeId;

  @override
  State<BikeProfileScreen> createState() => _BikeProfileScreenState();
}

class _BikeProfileScreenState extends State<BikeProfileScreen> {
  final ActiveBikeController _bikeController = ActiveBikeController.instance;

  List<MaintenanceItem> _maintenanceItems = [];

  @override
  void initState() {
    super.initState();
    _loadMaintenanceItems();
  }

  Future<void> _loadMaintenanceItems() async {
    try {
      final items = await AppRepositories.instance.maintenanceRepository.loadMaintenanceItems();
      if (mounted) {
        setState(() {
          _maintenanceItems = items;
        });
      }
    } catch (_) {}
  }

  /// Navigation height constants for anti-overlap calculation:
  static const double _kNavHeight = 64.0;
  static const double _kNavBottomMargin = 24.0;
  static const double _kScrollBottomPadding =
      _kNavHeight + _kNavBottomMargin + 32.0;

  Bike? _resolveCurrentBike() {
    // 1. Check if bike ID was provided in constructor or via route arguments
    final args = ModalRoute.of(context)?.settings.arguments;
    final argId = widget.bikeId ??
        (args is String ? args : (args is Bike ? args.id : null));

    if (argId != null) {
      final found = _bikeController.getBikeById(argId);
      if (found != null) return found;
    }

    // 2. If a bike was passed directly, try to get freshest copy by ID
    if (widget.bike != null) {
      final freshest = _bikeController.getBikeById(widget.bike!.id);
      return freshest ?? widget.bike!;
    }

    // 3. Fallback to current active rig
    return _bikeController.activeBike;
  }

  void _showNotification(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.darkCharcoal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(milliseconds: 2000),
      ),
    );
  }

  void _navigateToEditSpecs(Bike bike) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => BikeDetailsScreen(initialBike: bike),
      ),
    );
  }

  void _showDeleteConfirmationDialog(Bike bike) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.clay,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusCard),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.alertRed,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Remove Motorcycle?',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppColors.darkCharcoal,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to remove "${bike.make} ${bike.modelName}" from your garage? Stored ride and service records will be detached.',
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: AppColors.darkCharcoal,
              height: 1.4,
            ),
          ),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  color: AppColors.mutedText,
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
                elevation: 0,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _bikeController.removeBike(bike.id);
                if (mounted) {
                  Navigator.of(context).pop();
                  _showNotification(
                    'Removed ${bike.make} ${bike.modelName} from garage',
                  );
                }
              },
              child: Text(
                'Remove Bike',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showImageExpandedModal(Bike bike) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              CampBikeImage(
                imagePath: bike.imagePath,
                fit: BoxFit.contain,
                borderRadius: BorderRadius.circular(AppColors.radiusCard),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () => Navigator.of(dialogCtx).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
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
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_bikeController, FuelTrackerService.instance]),
      builder: (context, _) {
        final bike = _resolveCurrentBike();
        if (bike == null) {
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              systemNavigationBarColor: AppColors.background,
              systemNavigationBarIconBrightness: Brightness.dark,
            ),
            child: Scaffold(
              backgroundColor: AppColors.clay,
              body: Stack(
                children: [
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppColors.screenPadding,
                        vertical: 16.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const CampAppBar(
                            leading: CampAppBarLeading.back,
                            titleText: 'BIKE PROFILE',
                          ),
                          const Spacer(),
                          CampEmptyState(
                            icon: Icons.two_wheeler_rounded,
                            message: 'No motorcycle active in your garage',
                            ctaLabel: 'Add your bike',
                            onCta: () => Navigator.of(context)
                                .pushNamed(CampRoutes.addBike),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: _kNavBottomMargin,
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

        final isActive = _bikeController.isActive(bike.id);

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarColor: AppColors.background,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
          child: Scaffold(
            backgroundColor: AppColors.clay,
            body: Stack(
              children: [
                // ── Scrollable Body Content ──────────────────────────────────
                SafeArea(
                  bottom: false,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppColors.screenPadding,
                      8.0,
                      AppColors.screenPadding,
                      _kScrollBottomPadding,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Header: CampAppBar
                        _buildHeader(isActive),

                        const SizedBox(height: 14),

                        // 2. Hero card
                        _buildHeroCard(bike, isActive),

                        const SizedBox(height: AppColors.cardGap),

                        // 3. Specifications card
                        _buildSpecificationsCard(bike),

                        const SizedBox(height: AppColors.cardGap),

                        // 4. Maintenance Health card
                        _buildMaintenanceHealthCard(bike),

                        const SizedBox(height: AppColors.cardGap),

                        // 5. Riding Profile card
                        _buildRidingProfileCard(bike),

                        const SizedBox(height: AppColors.cardGap),

                        // 6. Recent Trips (On This Bike) card
                        _buildRecentTripsCard(bike),

                        const SizedBox(height: AppColors.cardGap),

                        // 7. Bottom Actions
                        _buildBottomActions(bike, isActive),

                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                // ── Floating Bottom Dock ──────────────────────────────────────
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: _kNavBottomMargin,
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
      },
    );
  }

  // ── 1. Header ──────────────────────────────────────────────────────────────
  Widget _buildHeader(bool isActive) {
    return CampAppBar(
      leading: CampAppBarLeading.back,
      onLeadingPressed: () => Navigator.of(context).pop(),
      actionWidget: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
        decoration: BoxDecoration(
          color: isActive ? AppColors.tacticalOrange : AppColors.clayDark,
          borderRadius: BorderRadius.circular(AppColors.radiusPill),
          boxShadow: AppColors.skeuRaisedSmall,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: isActive ? Colors.white : AppColors.mutedText,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              isActive ? 'ACTIVE RIG' : 'STANDBY',
              style: GoogleFonts.manrope(
                color: isActive ? Colors.white : AppColors.mutedText,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 2. Hero Card ───────────────────────────────────────────────────────────
  Widget _buildHeroCard(Bike bike, bool isActive) {
    final titleOverline =
        isActive ? 'ACTIVE RIG' : 'STANDBY FLEET';

    final subtitleText = bike.formattedSubtitle;

    return CampCard(
      padding: const EdgeInsets.all(14),
      borderRadius: AppColors.radiusCard,
      color: AppColors.clay,
      shadows: AppColors.skeuRaised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                titleOverline,
                style: AppTextStyles.overlineTerracotta.copyWith(
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w800,
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _navigateToEditSpecs(bike),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.edit_outlined,
                      size: 14,
                      color: AppColors.tacticalOrangeDark,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Edit Specs',
                      style: GoogleFonts.manrope(
                        color: AppColors.tacticalOrangeDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppColors.radiusTile),
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: CampBikeImage(
                    imagePath: bike.imagePath,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => _showImageExpandedModal(bike),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.open_in_full_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  '${bike.make} ${bike.modelName}',
                  style: GoogleFonts.manrope(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.darkCharcoal,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.clayDark,
                  borderRadius: BorderRadius.circular(AppColors.radiusPill),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 1,
                  ),
                  boxShadow: AppColors.skeuRecessed,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF94A3B8),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'MANUALLY TRACKED',
                      style: GoogleFonts.manrope(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkCharcoal,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitleText,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.mutedText,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── 3. Specifications Card ────────────────────────────────────────────────
  Widget _buildSpecificationsCard(Bike bike) {
    final displacementText = bike.displacement != null
        ? '${_formatNumber(bike.displacement!)} cc'
        : 'Not set';
    final engineSubtitle = bike.make == 'BMW' && (bike.displacement ?? 0) > 1000
        ? 'Boxer Twin'
        : (bike.bikeType != null ? '${bike.bikeType} Engine' : (bike.displacement != null ? '${bike.displacement} cc' : 'Engine specs'));

    final isEfi = bike.fuelSystem == FuelSystem.efi;
    final fuelSystemTitle = isEfi ? 'Fuel Injection (EFI)' : 'Carburetor';
    final fuelSystemSubtitle = isEfi
        ? 'Electronic'
        : (bike.carburetorType?.isNotEmpty == true
            ? bike.carburetorType!
            : 'Mechanical');

    final tankCapacity = bike.fuelTankCapacityLiters;
    final liters =
        FuelEstimator.currentLiters(bike) ?? bike.fuelRemainingLiters;
    final range = FuelEstimator.rangeKm(liters, bike.fuelAverageKmPerLiter);
    final tankTitle = tankCapacity != null
        ? (liters != null
            ? '${liters.toStringAsFixed(1)} / ${tankCapacity.toStringAsFixed(0)} L'
            : '${tankCapacity % 1 == 0 ? tankCapacity.toInt().toString() : tankCapacity.toStringAsFixed(1)} L')
        : 'Not set';
    final tankSubtitle = tankCapacity != null
        ? (range != null
            ? 'about ${range.round()} km range'
            : (liters != null
                ? 'Tap to log refill'
                : '${(tankCapacity * 0.264172).toStringAsFixed(1)} gal cap'))
        : 'Tap Edit to set';

    final fuelAvgValue = bike.fuelAverageKmPerLiter;
    final fuelAvgTitle = fuelAvgValue != null
        ? '${fuelAvgValue.toStringAsFixed(1)} km/L'
        : 'Add fuel average';
    final fuelAvgSubtitle = fuelAvgValue != null ? 'User Reported' : 'Tap Edit to set';

    final odometerTitle = bike.preciseOdometerKm != null
        ? '${bike.preciseOdometerKm!.toStringAsFixed(1)} km'
        : '${_formatNumber(bike.odometerKm)} km';

    final rigCategory = bike.bikeType ?? 'Motorcycle';
    final rigSubtitle = bike.bikeType != null ? _getCategorySubtitle(rigCategory) : 'Category not set';

    return CampCard(
      padding: const EdgeInsets.all(AppColors.cardPadding),
      borderRadius: AppColors.radiusCard,
      color: AppColors.clay,
      shadows: AppColors.skeuRaised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.tune_rounded,
                      size: 16,
                      color: AppColors.tacticalOrange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'SPECIFICATIONS',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.darkCharcoal,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'As Entered',
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildSpecStatTile(
                  label: 'ENGINE',
                  value: displacementText,
                  subtitle: engineSubtitle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSpecStatTile(
                  label: 'FUEL SYSTEM',
                  value: fuelSystemTitle,
                  subtitle: fuelSystemSubtitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildSpecStatTile(
                  label: 'FUEL TANK',
                  value: tankTitle,
                  subtitle: tankSubtitle,
                  onTap: () => UpdateFuelSheet.show(context, bike),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSpecStatTile(
                  label: 'FUEL AVG',
                  value: fuelAvgTitle,
                  subtitle: fuelAvgSubtitle,
                  valueColor: fuelAvgValue == null ? AppColors.tacticalOrange : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildSpecStatTile(
                  label: 'ODOMETER',
                  value: odometerTitle,
                  subtitle: 'Last Updated',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSpecStatTile(
                  label: 'RIG CATEGORY',
                  value: rigCategory,
                  subtitle: rigSubtitle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpecStatTile({
    required String label,
    required String value,
    required String subtitle,
    Color? valueColor,
    VoidCallback? onTap,
  }) {
    final tile = InsetTile(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderRadius: AppColors.radiusTile,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.mutedText,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: valueColor ?? AppColors.darkCharcoal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedText,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (onTap == null) return tile;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: tile,
    );
  }

  String _getCategorySubtitle(String category) {
    switch (category.toLowerCase()) {
      case 'adventure':
        return 'Heavy Dual-Sport';
      case 'commuter':
        return 'Urban Utility';
      case 'sport':
        return 'Performance Track';
      case 'cruiser':
        return 'Highway Cruiser';
      case 'scooter':
        return 'City Runabout';
      case 'electric':
        return 'EV Diagnostics';
      default:
        return 'Touring Spec';
    }
  }

  // ── 4. Maintenance Health Card ─────────────────────────────────────────────
  Widget _buildMaintenanceHealthCard(Bike bike) {
    final items = _maintenanceItems;

    final oilChangeDisplay = _formatServiceRecord(bike.lastOilChange);
    final tuneUpDisplay = _formatServiceRecord(bike.lastTuneUp);

    final reports = PostRideReportController.instance.getReportsForBike(bike.id);
    final assessment = MaintenancePredictionEngine.analyze(bike: bike, rideReports: reports);
    final healthScore = assessment.healthIndex;

    return CampCard(
      padding: const EdgeInsets.all(AppColors.cardPadding),
      borderRadius: AppColors.radiusCard,
      color: AppColors.clay,
      shadows: AppColors.skeuRaised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.favorite_border_rounded,
                size: 18,
                color: Color(0xFF059669),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'MAINTENANCE HEALTH',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.darkCharcoal,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(AppColors.radiusPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF059669),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$healthScore%',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          InsetTile(
            padding: const EdgeInsets.all(12),
            borderRadius: AppColors.radiusTile,
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: (healthScore / 100.0).clamp(0.0, 1.0),
                        strokeWidth: 5.5,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
                      ),
                      Text(
                        '$healthScore%',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Systems ${assessment.healthStatusLabel}',
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.darkCharcoal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD1FAE5),
                              borderRadius:
                                  BorderRadius.circular(AppColors.radiusPill),
                            ),
                            child: Text(
                              assessment.healthStatusLabel,
                              style: GoogleFonts.manrope(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF059669),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Next service due in ${assessment.nextServiceKm} km',
                        style: GoogleFonts.manrope(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mutedText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Calculated from maintenance rule engine wear & service logs',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildMilestoneRow(
            title: 'Last Oil Change:',
            value: oilChangeDisplay,
            onViewTap: () =>
                _showNotification('Opening oil change service history...'),
          ),
          const SizedBox(height: 8),
          _buildMilestoneRow(
            title: 'Last Tune-Up:',
            value: tuneUpDisplay,
            onViewTap: () =>
                _showNotification('Opening tune-up service history...'),
          ),
          const SizedBox(height: 14),
          Text(
            'COMPONENT DIAGNOSTICS',
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.mutedText,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'No maintenance components logged yet for this motorcycle.',
                style: AppTextStyles.caption.copyWith(color: AppColors.mutedText),
              ),
            )
          else ...[
            for (final item in items.take(3)) ...[
              _buildDiagnosticItemRow(
                title: item.name,
                indicatorText: switch (item.status) {
                  MaintenanceStatus.overdue => 'Overdue',
                  MaintenanceStatus.dueSoon => 'Due Soon',
                  MaintenanceStatus.ok => 'OK',
                  MaintenanceStatus.diyRec => 'DIY Rec',
                },
                dotColor: switch (item.status) {
                  MaintenanceStatus.overdue => AppColors.alertRed,
                  MaintenanceStatus.dueSoon => const Color(0xFFF59E0B),
                  MaintenanceStatus.ok => const Color(0xFF10B981),
                  MaintenanceStatus.diyRec => const Color(0xFFF59E0B),
                },
                isAlert: item.status != MaintenanceStatus.ok,
              ),
              const SizedBox(height: 8),
            ],
          ],
          const SizedBox(height: 14),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Navigator.of(context).pushNamed(CampRoutes.financeRigHealth);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.clay,
                borderRadius: BorderRadius.circular(AppColors.radiusTile),
                border: Border.all(
                  color: AppColors.tacticalOrange.withValues(alpha: 0.35),
                  width: 1.2,
                ),
                boxShadow: AppColors.skeuRaisedSmall,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'View Full Rig Diagnostics Report',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.tacticalOrangeDark,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 15,
                    color: AppColors.tacticalOrangeDark,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneRow({
    required String title,
    required String value,
    required VoidCallback onViewTap,
  }) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.mutedText,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.darkCharcoal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onViewTap,
          child: Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'View →',
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
    );
  }

  Widget _buildDiagnosticItemRow({
    required String title,
    required String indicatorText,
    required Color dotColor,
    required bool isAlert,
  }) {
    return InsetTile(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      borderRadius: 10,
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.manrope(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.darkCharcoal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            indicatorText,
            style: GoogleFonts.manrope(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: isAlert ? const Color(0xFFD97706) : const Color(0xFF059669),
            ),
          ),
        ],
      ),
    );
  }

  String _formatServiceRecord(ServiceRecord? record) {
    if (record == null) return 'Not recorded';
    final parts = <String>[];
    if (record.km != null) {
      parts.add('${_formatNumber(record.km!)} km ago');
    }
    if (record.date != null) {
      parts.add('(${_formatMonthYear(record.date!)})');
    }
    return parts.isNotEmpty ? parts.join(' ') : 'Logged';
  }

  String _formatMonthYear(DateTime dt) {
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
    return '${months[dt.month - 1]} ${dt.year}';
  }

  // ── 5. Riding Profile Card ────────────────────────────────────────────────
  Widget _buildRidingProfileCard(Bike bike) {
    const allTerrains = ['City', 'Highway', 'Off-road', 'Mountain'];
    final configured = bike.ridingTerrain ?? const ['City', 'Highway', 'Off-road'];

    return CampCard(
      padding: const EdgeInsets.all(AppColors.cardPadding),
      borderRadius: AppColors.radiusCard,
      color: AppColors.clay,
      shadows: AppColors.skeuRaised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 17,
                color: AppColors.tacticalOrange,
              ),
              const SizedBox(width: 8),
              Text(
                'RIDING PROFILE',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.darkCharcoal,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Primary Riding Terrain (Configured):',
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedText,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allTerrains.map((terrain) {
              final isSelected = configured.contains(terrain);
              if (isSelected) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(AppColors.radiusPill),
                    border: Border.all(
                      color: AppColors.tacticalOrange,
                      width: 1.2,
                    ),
                    boxShadow: AppColors.skeuRaisedSmall,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: AppColors.tacticalOrange,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        terrain,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.tacticalOrangeDark,
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.clayDark,
                    borderRadius: BorderRadius.circular(AppColors.radiusPill),
                    boxShadow: AppColors.skeuRecessed,
                  ),
                  child: Text(
                    terrain,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mutedText,
                    ),
                  ),
                );
              }
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── 6. Recent Trips (On This Bike) Card ────────────────────────────────────
  Widget _buildRecentTripsCard(Bike bike) {
    final reports = PostRideReportController.instance.getReportsForBike(bike.id);

    return CampCard(
      padding: const EdgeInsets.all(AppColors.cardPadding),
      borderRadius: AppColors.radiusCard,
      color: AppColors.clay,
      shadows: AppColors.skeuRaised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.map_outlined,
                      size: 17,
                      color: AppColors.tacticalOrange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'RECENT TRIPS (ON THIS BIKE)',
                        style: GoogleFonts.manrope(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.darkCharcoal,
                          letterSpacing: 0.4,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (reports.isNotEmpty) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Navigator.of(context).pushNamed(CampRoutes.rideHistory);
                  },
                  child: Text(
                    'See all (${reports.length})',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.tacticalOrangeDark,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (reports.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.route_rounded, size: 30, color: AppColors.mutedLight),
                    const SizedBox(height: 6),
                    Text(
                      'No rides yet on this bike',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkCharcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Completed rides for this motorcycle will appear here.',
                      style: AppTextStyles.caption.copyWith(color: AppColors.mutedText),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else ...[
            for (final report in reports.take(3)) ...[
              _buildReportRow(report),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildReportRow(PostRideReport report) {
    final title = report.routeTitle.isNotEmpty
        ? report.routeTitle
        : 'Ride on ${report.formattedDate}';
    final duration = report.durationHours != null
        ? '${report.durationHours!.toStringAsFixed(1)} hrs'
        : (report.durationMinutes != null ? '${report.durationMinutes} min' : '—');

    return InsetTile(
      padding: const EdgeInsets.all(12),
      borderRadius: AppColors.radiusTile,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkCharcoal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${report.distanceKm.toStringAsFixed(1)} km',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.tacticalOrangeDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                report.formattedDate,
                style: AppTextStyles.caption,
              ),
              Text(
                duration,
                style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 7. Bottom Actions ──────────────────────────────────────────────────────
  Widget _buildBottomActions(Bike bike, bool isActive) {
    return Column(
      children: [
        // Full-width "Edit Specifications & Tires →" button
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _navigateToEditSpecs(bike),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AppColors.tacticalOrangeLight,
                  AppColors.tacticalOrange,
                  AppColors.tacticalOrangeDark,
                ],
              ),
              borderRadius: BorderRadius.circular(AppColors.radiusTile),
              boxShadow: AppColors.orangeGlow,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Edit Specifications & Tires',
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Active State pill OR "Set as Active Rig" button + Trash Icon
        Row(
          children: [
            Expanded(
              child: isActive
                  ? Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius:
                            BorderRadius.circular(AppColors.radiusTile),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Color(0xFF059669),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Currently Active Rig',
                            style: GoogleFonts.manrope(
                              color: const Color(0xFF059669),
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    )
                  : GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _bikeController.setActiveBike(bike.id);
                        _showNotification('Set ${bike.modelName} as Active Rig');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.clay,
                          borderRadius:
                              BorderRadius.circular(AppColors.radiusTile),
                          border: Border.all(
                            color: AppColors.tacticalOrange.withValues(alpha: 0.5),
                            width: 1.2,
                          ),
                          boxShadow: AppColors.skeuRaisedSmall,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 16,
                              color: AppColors.tacticalOrangeDark,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Set as Active Rig',
                              style: GoogleFonts.manrope(
                                color: AppColors.tacticalOrangeDark,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            // Delete / Trash Icon Button
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showDeleteConfirmationDialog(bike),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(AppColors.radiusTile),
                  border: Border.all(
                    color: AppColors.alertRed.withValues(alpha: 0.25),
                    width: 1,
                  ),
                  boxShadow: AppColors.skeuRaisedSmall,
                ),
                child: const Center(
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.alertRed,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // "Remove Bike from Garage" red text link
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _showDeleteConfirmationDialog(bike),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              'Remove Bike from Garage',
              style: GoogleFonts.manrope(
                color: AppColors.alertRed,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatNumber(int value) {
    final str = value.toString();
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
