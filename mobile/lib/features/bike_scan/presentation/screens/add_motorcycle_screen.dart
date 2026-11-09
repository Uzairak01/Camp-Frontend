import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../dashboard/presentation/widgets/app_drawer_widget.dart';
import '../../../garage/controllers/active_bike_controller.dart';
import '../../../garage/domain/bike_model.dart';
import 'bike_details_screen.dart';

/// CAMP Add Motorcycle Screen.
/// Allows riders to scan their motorcycle with the optical scanner,
/// quickly enter details (plate number, colour, make, model), or view their garage.
class AddMotorcycleScreen extends StatefulWidget {
  const AddMotorcycleScreen({super.key});

  @override
  State<AddMotorcycleScreen> createState() => _AddMotorcycleScreenState();
}

class _AddMotorcycleScreenState extends State<AddMotorcycleScreen> {
  final TextEditingController _makeController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  bool _submittedOnce = false;

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _plateController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  String? get _plateError {
    final text = _plateController.text.trim();
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

  void _handleQuickSave() {
    setState(() => _submittedOnce = true);

    final make = _makeController.text.trim();
    final model = _modelController.text.trim();

    if (make.isEmpty || model.isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            make.isEmpty ? 'Please enter a make (e.g. Honda)' : 'Please enter a model name (e.g. Africa Twin)',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          backgroundColor: AppColors.alertRed,
          behavior: SnackBarBehavior.floating,
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
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          backgroundColor: AppColors.alertRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    final newBike = Bike(
      id: 'bike-${DateTime.now().millisecondsSinceEpoch}',
      make: make,
      modelName: model,
      modelYear: DateTime.now().year,
      odometerKm: 0,
      plateNumber: _plateController.text.trim().isNotEmpty
          ? _plateController.text.trim().toUpperCase()
          : null,
      color: _colorController.text.trim().isNotEmpty
          ? _colorController.text.trim()
          : null,
    );

    ActiveBikeController.instance.addBike(newBike, setActive: true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added $make $model to your garage!'),
        backgroundColor: AppColors.darkCharcoal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    Navigator.of(context).pushNamed(CampRoutes.garage);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        drawer: const AppDrawerWidget(),
        backgroundColor: AppColors.clay,
        body: SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Scrollable Body Content ─────────────────────────────────────
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppColors.screenPadding),
                      child: CampAppBar(
                        leading: CampAppBarLeading.back,
                        actionText: 'ADD BIKE',
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          AppColors.screenPadding,
                          16.0,
                          AppColors.screenPadding,
                          120.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [

                      // 2. Title & Subtitle
                      Text(
                        'Add a Motorcycle',
                        style: AppTextStyles.title,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Add a photo or enter details manually.',
                        style: AppTextStyles.bodySecondary,
                      ),

                      const SizedBox(height: 24),

                      // 3. "Take Bike Photo" Card
                      _buildScanBikeCard(context),

                      const SizedBox(height: AppColors.cardGap),

                      // 4. "View Garage" Card
                      _buildViewGarageCard(context),

                      const SizedBox(height: AppColors.cardGap),

                      // 5. Quick Registration Card with Plate & Colour Inputs
                      _buildQuickAddCard(),

                      const SizedBox(height: AppColors.cardGap),

                      // 6. Tip Card
                      _buildTipCard(),
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
      ),
    );
  }

  // ── Option 1: Take Bike Photo Card ──────────────────────────────────────────
  Widget _buildScanBikeCard(BuildContext context) {
    return CampCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      borderRadius: AppColors.radiusCard,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.tacticalOrangeLight,
          AppColors.tacticalOrangeDark,
        ],
      ),
      shadows: AppColors.orangeGlow,
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).pushNamed(CampRoutes.bikeScan);
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(AppColors.radiusTile),
            ),
            child: const Center(
              child: Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Take Bike Photo',
                  style: GoogleFonts.manrope(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Take or choose a photo of your motorcycle',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.92),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.chevron_right_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Option 2: Quick Registration Form with Plate & Colour ──────────────────
  Widget _buildQuickAddCard() {
    return CampCard(
      padding: const EdgeInsets.all(AppColors.cardPadding),
      borderRadius: AppColors.radiusCard,
      color: Colors.white,
      shadows: AppColors.skeuRaised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconTile(
                icon: Icons.edit_note_rounded,
                size: 38,
                iconSize: 20,
                borderRadius: AppColors.radiusTile,
                isInset: true,
                backgroundColor: AppColors.clayDark,
                iconColor: AppColors.darkCharcoal,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manual Registration',
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkCharcoal,
                      ),
                    ),
                    Text(
                      'Enter bike details and license plate',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Make & Model Row
          Row(
            children: [
              Expanded(
                child: LabeledTextField(
                  label: 'Make',
                  controller: _makeController,
                  placeholder: 'e.g. Honda',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LabeledTextField(
                  label: 'Model',
                  controller: _modelController,
                  placeholder: 'e.g. Africa Twin',
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // License Plate input with validation
          LabeledTextField(
            label: 'License Plate (Optional)',
            controller: _plateController,
            placeholder: 'e.g. ABC-1234',
            helperText: 'Saved to Emergency QR and rescue ID',
            errorText: _submittedOnce ? _plateError : null,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),

          // Colour input with validation
          LabeledTextField(
            label: 'Colour / Finish (Optional)',
            controller: _colorController,
            placeholder: 'e.g. Matte Black or Red',
            errorText: _submittedOnce ? _colorError : null,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // Quick Add Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _handleQuickSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkCharcoal,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Add to Garage',
                style: GoogleFonts.manrope(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Link to Full Spec Onboarding
          Center(
            child: TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const BikeDetailsScreen(prefilled: false),
                  ),
                );
              },
              child: Text(
                'Configure full mechanical specs & carburetor →',
                style: GoogleFonts.manrope(
                  fontSize: 12.5,
                  color: AppColors.tacticalOrange,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Option 3: View Garage Card ────────────────────────────────────────────
  Widget _buildViewGarageCard(BuildContext context) {
    return CampCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      borderRadius: AppColors.radiusCard,
      color: Colors.white,
      shadows: AppColors.skeuRaised,
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).pushNamed(CampRoutes.garage);
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const IconTile(
            icon: Icons.garage_rounded,
            size: 48,
            iconSize: 24,
            borderRadius: AppColors.radiusTile,
            isInset: true,
            backgroundColor: AppColors.clayDark,
            iconColor: AppColors.darkCharcoal,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'View Garage',
                  style: AppTextStyles.cardTitle,
                ),
                const SizedBox(height: 4),
                Text(
                  'See your registered bikes',
                  style: AppTextStyles.bodySecondary,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.clay,
              shape: BoxShape.circle,
              boxShadow: AppColors.skeuRaisedSmall,
            ),
            child: const Center(
              child: Icon(
                Icons.chevron_right_rounded,
                color: AppColors.mutedText,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tip Card ──────────────────────────────────────────────────────────────
  Widget _buildTipCard() {
    return InsetTile(
      borderRadius: AppColors.radiusCard,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.tacticalOrange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Icon(
                Icons.lightbulb_rounded,
                color: AppColors.tacticalOrange,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tip: a clear side-view photo works best.',
              style: AppTextStyles.bodySecondary,
            ),
          ),
        ],
      ),
    );
  }
}
