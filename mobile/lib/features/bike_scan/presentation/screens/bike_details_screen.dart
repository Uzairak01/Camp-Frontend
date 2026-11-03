import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/constants/bike_makes.dart';
import '../../../../core/utils/image_storage_helper.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../dashboard/presentation/widgets/app_drawer_widget.dart';
import '../../../garage/controllers/active_bike_controller.dart';
import '../../../garage/domain/bike_model.dart';
import '../../controllers/bike_onboarding_controller.dart';
import '../../utils/gallery_picker_helper.dart';

/// CAMP Bike Details Screen (Step 2 of the Add Bike onboarding journey).
/// Captures core mechanical specs, telemetry baseline, and fuel system configuration.
class BikeDetailsScreen extends StatefulWidget {
  const BikeDetailsScreen({
    super.key,
    this.initialBike,
    /// Set to true when the controller was pre-populated from a photo scan so
    /// the screen shows the "Auto-filled" banner and per-field tags.
    this.prefilled = false,
  });

  final Bike? initialBike;
  final bool prefilled;

  @override
  State<BikeDetailsScreen> createState() => _BikeDetailsScreenState();
}

class _BikeDetailsScreenState extends State<BikeDetailsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final BikeOnboardingController _controller = BikeOnboardingController.instance;

  late TextEditingController _modelNameController;
  late TextEditingController _displacementController;
  late TextEditingController _carburetorTypeController;
  late TextEditingController _fuelTankCapacityController;
  late TextEditingController _odometerController;
  late TextEditingController _currentFuelController;
  late TextEditingController _fuelAverageController;
  late TextEditingController _vinController;
  late TextEditingController _nicknameController;
  late TextEditingController _plateNumberController;
  late TextEditingController _colorController;
  bool _submittedOnce = false;

  static final List<int> _years = List.generate(
    47,
    (index) => DateTime.now().year + 1 - index,
  );

  static const List<Map<String, dynamic>> _bikeTypes = [
    {'name': 'Commuter', 'icon': Icons.commute_rounded},
    {'name': 'Sport', 'icon': Icons.sports_motorsports_rounded},
    {'name': 'Adventure', 'icon': Icons.terrain_rounded},
    {'name': 'Cruiser', 'icon': Icons.motorcycle_rounded},
    {'name': 'Scooter', 'icon': Icons.electric_moped_rounded},
    {'name': 'Electric', 'icon': Icons.bolt_rounded},
  ];

  @override
  void initState() {
    super.initState();

    // If a Bike was passed in (e.g. editing an existing profile), populate the controller.
    if (widget.initialBike != null) {
      final b = widget.initialBike!;
      _controller.setMake(b.make);
      _controller.setModelName(b.modelName);
      _controller.setModelYear(b.modelYear);
      _controller.setDisplacement(b.displacement);
      if (b.bikeType != null) _controller.setBikeType(b.bikeType!);
      _controller.setFuelSystem(b.fuelSystem);
      _controller.setCarburetorType(b.carburetorType);
      _controller.setFuelTankCapacity(b.fuelTankCapacityLiters);
      _controller.setFuelAverageKmpl(b.fuelAverageKmPerLiter);
      _controller.setOdometerKm(b.odometerKm);
      _controller.setCurrentFuelLiters(b.currentFuelLiters);
      if (b.lastOilChange != null) _controller.setLastOilChange(b.lastOilChange!);
      if (b.lastTuneUp != null) _controller.setLastTuneUp(b.lastTuneUp!);
      _controller.setVin(b.vin);
      _controller.setNickname(b.nickname);
      _controller.setPlateNumber(b.plateNumber);
      _controller.setColor(b.color);
      _controller.setImagePath(b.imagePath);
    }

    _modelNameController =
        TextEditingController(text: _controller.modelName);
    _displacementController = TextEditingController(
      text: _controller.displacement != null
          ? _controller.displacement.toString()
          : '',
    );
    _carburetorTypeController =
        TextEditingController(text: _controller.carburetorType ?? '');
    _fuelTankCapacityController = TextEditingController(
      text: _controller.fuelTankCapacityLiters != null
          ? _controller.fuelTankCapacityLiters.toString()
          : '',
    );
    _odometerController = TextEditingController(
      text: _controller.odometerKm != null
          ? _controller.odometerKm.toString()
          : '',
    );
    _currentFuelController = TextEditingController(
      text: _controller.currentFuelLiters != null
          ? _controller.currentFuelLiters.toString()
          : '',
    );
    _fuelAverageController = TextEditingController(
      text: _controller.fuelAverageKmpl != null
          ? _controller.fuelAverageKmpl.toString()
          : '',
    );
    _vinController = TextEditingController(text: _controller.vin ?? '');
    _nicknameController =
        TextEditingController(text: _controller.nickname ?? '');
    _plateNumberController =
        TextEditingController(text: _controller.plateNumber ?? '');
    _colorController =
        TextEditingController(text: _controller.color ?? '');

    _controller.addListener(_onControllerUpdated);
  }

  void _onControllerUpdated() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdated);
    _modelNameController.dispose();
    _displacementController.dispose();
    _carburetorTypeController.dispose();
    _fuelTankCapacityController.dispose();
    _odometerController.dispose();
    _currentFuelController.dispose();
    _fuelAverageController.dispose();
    _vinController.dispose();
    _nicknameController.dispose();
    _plateNumberController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  void _handleContinue() {
    setState(() {
      _submittedOnce = true;
    });

    if (!_controller.isFormValid) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please complete the 4 required fields to proceed.',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: AppColors.alertRed,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_plateError != null || _colorError != null) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _plateError ?? _colorError ?? 'Invalid input',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: AppColors.alertRed,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    final completedBike = _controller.buildBike(id: widget.initialBike?.id);
    if (widget.initialBike != null) {
      final initial = widget.initialBike!;
      final oldOdo = initial.odometerKm;
      final newOdo = completedBike.odometerKm;
      final diff = newOdo - oldOdo;
      final initialBaseOdo = initial.fuelLevelOdometerKm ?? oldOdo.toDouble();
      final adjustedBaseOdo =
          (newOdo < initialBaseOdo) ? newOdo.toDouble() : initialBaseOdo;

      final mergedBike = initial.copyWith(
        make: completedBike.make,
        modelName: completedBike.modelName,
        modelYear: completedBike.modelYear,
        displacement: completedBike.displacement,
        bikeType: completedBike.bikeType,
        fuelSystem: completedBike.fuelSystem,
        carburetorType: completedBike.carburetorType,
        fuelTankCapacityLiters: completedBike.fuelTankCapacityLiters,
        fuelAverageKmPerLiter: completedBike.fuelAverageKmPerLiter,
        odometerKm: newOdo,
        preciseOdometerKm: newOdo.toDouble(),
        fuelLevelOdometerKm: adjustedBaseOdo,
        vin: completedBike.vin,
        nickname: completedBike.nickname,
        plateNumber: completedBike.plateNumber,
        color: completedBike.color,
        imagePath: completedBike.imagePath ?? initial.imagePath,
        lastUpdated: DateTime.now(),
      );
      ActiveBikeController.instance.updateBike(mergedBike);

      if (diff > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Odometer up by $diff km. Fuel estimate adjusted.',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            backgroundColor: AppColors.darkCharcoal,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } else {
      ActiveBikeController.instance.addBike(completedBike, setActive: true);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Motorcycle ${completedBike.make} ${completedBike.modelName} configured!',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: AppColors.darkCharcoal,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(milliseconds: 2000),
      ),
    );

    // Proceed to Garage screen with newly registered bike
    Navigator.of(context).pushNamed(CampRoutes.garage);
  }

  // ── Make validation helpers ─────────────────────────────────────────────────
  bool get isMakeInvalid {
    final len = _controller.make.trim().length;
    return _submittedOnce && (len < 2 || len > 30);
  }

  String get makeError {
    final len = _controller.make.trim().length;
    if (len == 0) return 'Make is required';
    if (len < 2) return 'Too short (min 2 characters)';
    return 'Too long (max 30 characters)';
  }

  String? get _plateError {
    final text = _plateNumberController.text.trim();
    if (text.isEmpty) return null;
    if (text.length < 2 || text.length > 15) {
      return 'Plate must be 2 to 15 characters';
    }
    if (!RegExp(r'^[A-Za-z0-9\s\-]+$').hasMatch(text)) {
      return 'Only letters, numbers, spaces, and hyphens allowed';
    }
    return null;
  }

  String? get _colorError {
    final text = _colorController.text.trim();
    if (text.isEmpty) return null;
    if (text.length < 2 || text.length > 30) {
      return 'Colour must be 2 to 30 characters';
    }
    if (!RegExp(r'^[A-Za-z\s\-\/\.]+$').hasMatch(text)) {
      return 'Only letters, spaces, and hyphens/slashes allowed';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bool canContinue = _controller.isFormValid;
    final bool isModelNameEmpty =
        _submittedOnce && _controller.modelName.trim().isEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        key: _scaffoldKey,
        drawer: const AppDrawerWidget(),
        backgroundColor: AppColors.clay,
        body: Stack(
          children: [
            // ── Body Content with Fixed Header ─────────────────────────────
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppColors.screenPadding),
                    child: _buildTopAppBar(),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppColors.screenPadding,
                        8.0,
                        AppColors.screenPadding,
                        120.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [

                    // 3. Progress Row
                    _buildProgressRow(),

                    const SizedBox(height: 18),

                    // 4. Title & Subtitle
                    Text(
                      'Bike Details',
                      style: AppTextStyles.title,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tell us about your motorcycle so CAMP can tailor maintenance predictions.',
                      style: AppTextStyles.bodySecondary,
                    ),

                    const SizedBox(height: 22),

                    // ── Photo Card ───────────────────────────────────────────
                    _buildPhotoCard(),

                    const SizedBox(height: AppColors.cardGap),

                    // ── Card 1: Basic Information ───────────────────────────
                    _buildBasicInfoCard(isModelNameEmpty),

                    const SizedBox(height: AppColors.cardGap),

                    // ── Card 2: Bike Type ───────────────────────────────────
                    _buildBikeTypeCard(),

                    const SizedBox(height: AppColors.cardGap),

                    // ── Card 3: Engine & Fuel System (Required) ─────────────
                    _buildEngineAndFuelSystemCard(),

                    const SizedBox(height: AppColors.cardGap),

                    // ── Card 4: Current Status ──────────────────────────────
                    _buildCurrentStatusCard(),

                    const SizedBox(height: AppColors.cardGap),

                    // ── Card 5: Optional Info ───────────────────────────────
                    _buildOptionalInfoCard(),

                    const SizedBox(height: 16),

                    // ── Footnote: * Required fields ─────────────────────────
                    Center(
                      child: Text.rich(
                        TextSpan(
                          text: '* ',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.alertRed,
                          ),
                          children: [
                            TextSpan(
                              text:
                                  'Required fields: Make, Model Name, Model Year',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.mutedText,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── 6. Info Banner ──────────────────────────────────────
                    _buildInfoBanner(),

                    const SizedBox(height: 22),

                    // ── 7. Continue Button ──────────────────────────────────
                    _buildContinueButton(canContinue),

                    const SizedBox(height: 14),

                    // ── 8. Back to Options Link ─────────────────────────────
                    Center(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).pop();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Text(
                            'Back to options',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.mutedText,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

            // ── Floating Bottom Dock (Index 1: Bike Scan Active) ─────────────
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

  // ── Motorcycle Photo Card ────────────────────────────────────────────────
  Widget _buildPhotoCard() {
    final imagePath = _controller.imagePath;
    final hasImage = imagePath != null && imagePath.isNotEmpty && File(imagePath).existsSync();

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
              Text(
                'MOTORCYCLE PHOTO',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: AppColors.mutedText,
                ),
              ),
              if (hasImage)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _controller.setImagePath(null);
                  },
                  child: Text(
                    'Remove',
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.alertRed,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppColors.radiusTile),
              child: Stack(
                children: [
                  Image.file(
                    File(imagePath),
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _pickBikePhoto,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(AppColors.radiusPill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.edit_rounded, size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              'Change',
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _pickBikePhoto,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: AppColors.clayDark.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppColors.radiusTile),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.6),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.add_a_photo_rounded,
                      color: AppColors.tacticalOrange,
                      size: 28,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Attach Bike Photo',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkCharcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pick from gallery or take a picture',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickBikePhoto() async {
    final image = await GalleryPickerHelper.pickImageFromGallery(
      onError: (msg) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.darkCharcoal,
          ),
        );
      },
    );
    if (image != null && mounted) {
      final savedPath = await persistBikePhoto(image.path);
      _controller.setImagePath(savedPath);
    }
  }

  // ── Top Navigation Bar ────────────────────────────────────────────────────
  Widget _buildTopAppBar() {
    return CampAppBar(
      leading: CampAppBarLeading.back,
      actionWidget: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
              margin: const EdgeInsets.only(right: 6),
              decoration: const BoxDecoration(
                color: AppColors.tacticalOrange,
                shape: BoxShape.circle,
              ),
            ),
            Text(
              'ADD BIKE',
              style: GoogleFonts.manrope(
                color: AppColors.terracotta,
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


  // ── Progress Row: Step 2 of 4 ─────────────────────────────────────────────
  Widget _buildProgressRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STEP 2 OF 4',
          style: AppTextStyles.overlineOrange,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Segment 1 (Filled - Tactical Orange)
            Expanded(
              child: Container(
                height: 4.5,
                decoration: BoxDecoration(
                  color: AppColors.tacticalOrange,
                  borderRadius: BorderRadius.circular(AppColors.radiusPill),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Segment 2 (Filled - Tactical Orange)
            Expanded(
              child: Container(
                height: 4.5,
                decoration: BoxDecoration(
                  color: AppColors.tacticalOrange,
                  borderRadius: BorderRadius.circular(AppColors.radiusPill),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Segment 3 (Unfilled - Clay Deep)
            Expanded(
              child: Container(
                height: 4.5,
                decoration: BoxDecoration(
                  color: AppColors.clayDeep,
                  borderRadius: BorderRadius.circular(AppColors.radiusPill),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Segment 4 (Unfilled - Clay Deep)
            Expanded(
              child: Container(
                height: 4.5,
                decoration: BoxDecoration(
                  color: AppColors.clayDeep,
                  borderRadius: BorderRadius.circular(AppColors.radiusPill),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Card 1: Basic Information ─────────────────────────────────────────────
  Widget _buildBasicInfoCard(bool isModelNameEmpty) {
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
              Text(
                'BASIC INFORMATION',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: AppColors.mutedText,
                ),
              ),
              Text(
                'Required',
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Make / Manufacturer — combo field (free text + autocomplete)
          MakeComboField(
            initialValue: _controller.make,
            isError: isMakeInvalid,
            errorText: isMakeInvalid ? makeError : null,
            onChanged: (val) {
              final canonical = canonicaliseMake(val);
              _controller.setMake(canonical);
            },
          ),
          const SizedBox(height: 14),

          // Model Name
          LabeledTextField(
            label: 'Model Name',
            controller: _modelNameController,
            placeholder: 'e.g. Africa Twin, CB650R',
            isError: isModelNameEmpty,
            errorText: isModelNameEmpty ? 'Model is required' : null,
            errorLabel: isModelNameEmpty ? '!' : null,
            onChanged: (val) {
              _controller.setModelName(val);
            },
          ),
          const SizedBox(height: 14),

          // Row: Model Year + Displacement
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: LabeledDropdown<int>(
                  label: 'Model Year',
                  value: _years.contains(_controller.modelYear)
                      ? _controller.modelYear
                      : 2024,
                  items: _years,
                  onChanged: (val) {
                    if (val != null) _controller.setModelYear(val);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LabeledTextField(
                  label: 'Displacement',
                  controller: _displacementController,
                  placeholder: '1100',
                  suffixText: 'cc',
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    final parsed = int.tryParse(val.trim());
                    _controller.setDisplacement(parsed);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Card 2: Bike Type ─────────────────────────────────────────────────────
  Widget _buildBikeTypeCard() {
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
              Text(
                'BIKE TYPE',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: AppColors.mutedText,
                ),
              ),
              Text(
                '${_controller.bikeType} selected',
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.tacticalOrangeDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 2 Rows of 3 Pills
          Row(
            children: [
              _buildTypeChip(_bikeTypes[0]),
              const SizedBox(width: 8),
              _buildTypeChip(_bikeTypes[1]),
              const SizedBox(width: 8),
              _buildTypeChip(_bikeTypes[2]),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildTypeChip(_bikeTypes[3]),
              const SizedBox(width: 8),
              _buildTypeChip(_bikeTypes[4]),
              const SizedBox(width: 8),
              _buildTypeChip(_bikeTypes[5]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(Map<String, dynamic> item) {
    final name = item['name'] as String;
    final icon = item['icon'] as IconData;
    final isSelected = _controller.bikeType.toLowerCase() == name.toLowerCase();

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          _controller.setBikeType(name);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.tacticalOrangeLight,
                      AppColors.tacticalOrange,
                      AppColors.tacticalOrangeDark,
                    ],
                  )
                : null,
            color: isSelected ? null : AppColors.clay,
            borderRadius: BorderRadius.circular(AppColors.radiusTile - 2),
            border: Border.all(
              color: isSelected
                  ? AppColors.tacticalOrangeLight
                  : Colors.white.withValues(alpha: 0.8),
              width: 1.2,
            ),
            boxShadow: isSelected
                ? AppColors.orangeGlow
                : AppColors.skeuRaisedSmall,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSelected) ...[
                Icon(
                  icon,
                  size: 15,
                  color: Colors.white,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                name,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.darkCharcoal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Card 3: Engine & Fuel System (Required) ───────────────────────────────
  Widget _buildEngineAndFuelSystemCard() {
    final bool isCarburetor =
        _controller.fuelSystem == FuelSystem.carburetor;

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
              Text(
                'ENGINE & FUEL SYSTEM',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: AppColors.mutedText,
                ),
              ),
              Text(
                'Required',
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Fuel System Segmented Control
          Text(
            'Fuel System',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.darkCharcoal,
            ),
          ),
          const SizedBox(height: 6),
          SegmentedControl(
            options: const ['Carburetor', 'Fuel Injection (EFI)'],
            selectedIndex: isCarburetor ? 0 : 1,
            onChanged: (idx) {
              HapticFeedback.selectionClick();
              _controller.setFuelSystem(
                idx == 0 ? FuelSystem.carburetor : FuelSystem.efi,
              );
            },
          ),
          const SizedBox(height: 14),

          // Conditional Carburetor Type (Removed completely from widget tree when EFI)
          if (isCarburetor) ...[
            LabeledTextField(
              label: 'Carburetor Type',
              controller: _carburetorTypeController,
              placeholder: 'e.g. Mikuni, Keihin, CV',
              helperText: 'Specify the carburetor make or slide configuration',
              onChanged: (val) => _controller.setCarburetorType(val),
            ),
            const SizedBox(height: 14),
          ],

          // Fuel Tank Capacity
          LabeledTextField(
            label: 'Fuel Tank Capacity',
            controller: _fuelTankCapacityController,
            placeholder: 'e.g. 18.8',
            suffixText: 'L',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (val) {
              final parsed = double.tryParse(val.trim());
              _controller.setFuelTankCapacity(parsed);
            },
          ),
          const SizedBox(height: 14),

          // Fuel Average
          LabeledTextField(
            label: 'Fuel Average (km/L)',
            controller: _fuelAverageController,
            placeholder: 'e.g. 40',
            suffixText: 'km/L',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            helperText: 'Used to estimate range and fuel cost',
            onChanged: (val) {
              final parsed = double.tryParse(val.trim());
              // Validate 1–100 range
              if (parsed != null && parsed >= 1 && parsed <= 100) {
                _controller.setFuelAverageKmpl(parsed);
              } else {
                _controller.setFuelAverageKmpl(null);
              }
            },
          ),
        ],
      ),
    );
  }

  // ── Card 4: Current Status ────────────────────────────────────────────────
  Widget _buildCurrentStatusCard() {
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
              Text(
                'CURRENT STATUS',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: AppColors.mutedText,
                ),
              ),
              Text(
                'Update anytime from Garage',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.mutedLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Current Odometer Reading (Optional, defaults to 0)
          LabeledTextField(
            label: 'Current Odometer Reading',
            controller: _odometerController,
            placeholder: 'e.g. 14,820',
            suffixText: 'km',
            keyboardType: TextInputType.number,
            helperText: 'Leave blank to start from 0',
            onChanged: (val) {
              final cleaned = val.replaceAll(RegExp(r'[^\d]'), '');
              final parsed = int.tryParse(cleaned);
              _controller.setOdometerKm(parsed);
              setState(() {});
            },
          ),
          if (widget.initialBike != null &&
              (_controller.odometerKm ?? 0) > widget.initialBike!.odometerKm) ...[
            const SizedBox(height: 6),
            Text(
              'Odometer up by ${(_controller.odometerKm ?? 0) - widget.initialBike!.odometerKm} km. Fuel estimate adjusted.',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.tacticalOrange,
              ),
            ),
          ],
          const SizedBox(height: 14),

          // Current Fuel Level (Optional)
          LabeledTextField(
            label: 'Current Fuel Level (Optional)',
            controller: _currentFuelController,
            placeholder: 'e.g. 12.5',
            suffixText: 'L',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (val) {
              final parsed = double.tryParse(val.trim());
              _controller.setCurrentFuelLiters(parsed);
            },
          ),
          const SizedBox(height: 14),

          // Last Oil Change (DistanceOrDateInput from Phase 2)
          DistanceOrDateInput(
            label: 'Last Oil Change',
            value: _controller.lastOilChange,
            placeholderKm: 'e.g. 3,200',
            onChanged: (record) => _controller.setLastOilChange(record),
          ),
          const SizedBox(height: 14),

          // Last Tune-Up (DistanceOrDateInput from Phase 2)
          DistanceOrDateInput(
            label: 'Last Tune-Up',
            value: _controller.lastTuneUp,
            placeholderKm: 'e.g. 5,000',
            onChanged: (record) => _controller.setLastTuneUp(record),
          ),
        ],
      ),
    );
  }

  // ── Card 5: Optional Info ─────────────────────────────────────────────────
  Widget _buildOptionalInfoCard() {
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
              Text(
                'OPTIONAL INFO',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: AppColors.mutedText,
                ),
              ),
              Text(
                'Fleet Sync',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Serial / VIN with Camera Trailing Icon
          LabeledTextField(
            label: 'Serial / VIN',
            controller: _vinController,
            placeholder: 'E.G. JH2SD0408MK000...',
            helperText: '17 characters, found on the steering stem plate',
            trailingWidget: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.clay,
                borderRadius: BorderRadius.circular(8),
                boxShadow: AppColors.skeuRaisedSmall,
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                size: 16,
                color: AppColors.tacticalOrange,
              ),
            ),
            onChanged: (val) => _controller.setVin(val),
          ),
          const SizedBox(height: 14),

          // License Plate
          LabeledTextField(
            label: 'License Plate',
            controller: _plateNumberController,
            placeholder: 'e.g. ABC-1234',
            helperText: 'Shown on Emergency QR card and rescue telemetry',
            errorText: _submittedOnce ? _plateError : null,
            textCapitalization: TextCapitalization.characters,
            onChanged: (val) {
              setState(() {});
              _controller.setPlateNumber(val);
            },
          ),
          const SizedBox(height: 14),

          // Vehicle Colour / Finish
          LabeledTextField(
            label: 'Colour / Finish',
            controller: _colorController,
            placeholder: 'e.g. Matte Black or Red',
            helperText: 'Motorcycle primary body colour',
            errorText: _submittedOnce ? _colorError : null,
            textCapitalization: TextCapitalization.words,
            onChanged: (val) {
              setState(() {});
              _controller.setColor(val);
            },
          ),
          const SizedBox(height: 14),

          // Vehicle Nickname
          LabeledTextField(
            label: 'Vehicle Nickname',
            controller: _nicknameController,
            placeholder: 'e.g. Black Beast',
            onChanged: (val) => _controller.setNickname(val),
          ),
        ],
      ),
    );
  }

  // ── 6. Info Banner ────────────────────────────────────────────────────────
  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.clay,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.8),
          width: 1,
        ),
        boxShadow: AppColors.skeuRaisedSmall,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Color(0xFFFFEDE1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: AppColors.tacticalOrangeDark,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You can edit these details anytime from your Garage.',
              style: GoogleFonts.manrope(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.charcoalLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 7. Continue Button ────────────────────────────────────────────────────
  Widget _buildContinueButton(bool canContinue) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleContinue,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: canContinue
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.tacticalOrangeLight,
                    AppColors.tacticalOrange,
                    AppColors.tacticalOrangeDark,
                  ],
                )
              : null,
          color: canContinue ? null : AppColors.clayDark,
          borderRadius: BorderRadius.circular(AppColors.radiusTile),
          border: Border.all(
            color: canContinue
                ? AppColors.tacticalOrangeLight
                : Colors.white.withValues(alpha: 0.4),
            width: 1.2,
          ),
          boxShadow: canContinue
              ? AppColors.orangeGlow
              : AppColors.skeuRaisedSmall,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Continue',
              style: GoogleFonts.manrope(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: canContinue ? Colors.white : AppColors.mutedLight,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: canContinue ? Colors.white : AppColors.mutedLight,
            ),
          ],
        ),
      ),
    );
  }
}
