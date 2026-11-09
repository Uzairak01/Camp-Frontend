import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../maintenance/controllers/trip_budget_controller.dart';
import '../../../maintenance/domain/expense_model.dart';
import '../../../maintenance/domain/refill_calculator.dart';
import '../../../settings/controllers/settings_controller.dart';
import '../../controllers/active_bike_controller.dart';
import '../../domain/bike_model.dart';
import '../../domain/fuel_estimator.dart';
import '../../services/fuel_refill_service.dart';

/// Modal bottom sheet allowing riders to set their current fuel in liters
/// or log/edit a refill with live 3-field recalculation.
class UpdateFuelSheet extends StatefulWidget {
  const UpdateFuelSheet({
    required this.bike,
    this.initialExpense,
    super.key,
  });

  final Bike bike;
  final Expense? initialExpense;

  static Future<void> show(
    BuildContext context,
    Bike bike, {
    Expense? initialExpense,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => UpdateFuelSheet(
        bike: bike,
        initialExpense: initialExpense,
      ),
    );
  }

  @override
  State<UpdateFuelSheet> createState() => _UpdateFuelSheetState();
}

class _UpdateFuelSheetState extends State<UpdateFuelSheet> {
  late double _tankCapacity;
  late double _liters;
  bool _showRefillSection = false;

  late final TextEditingController _litresController;
  late final TextEditingController _pricePerLitreController;
  late final TextEditingController _totalPaidController;

  late final RefillCalculator _calculator;
  bool _isUpdatingProgrammatically = false;
  bool _isFullTank = false;
  String? _errorMessage;
  String? _selectedBikeId;

  @override
  void initState() {
    super.initState();
    if (widget.initialExpense != null) {
      _selectedBikeId = widget.initialExpense!.bikeId;
    } else {
      _selectedBikeId =
          ActiveBikeController.instance.activeBike?.id ?? widget.bike.id;
    }
    _tankCapacity = widget.bike.fuelTankCapacityLiters ?? 20.0;
    if (_tankCapacity <= 0) _tankCapacity = 20.0;

    final initial = widget.bike.fuelRemainingLiters ??
        (widget.bike.fuelLevelPercent != null
            ? (widget.bike.fuelLevelPercent! * _tankCapacity / 100.0)
            : _tankCapacity * 0.5);

    _liters = initial.clamp(0.0, _tankCapacity);
    _showRefillSection = widget.initialExpense != null;
    _isFullTank = widget.initialExpense?.isFullTank ?? false;

    final settingsPrice = SettingsController.instance.fuelPricePerLiter;
    final hasSettingsPrice = settingsPrice != null && settingsPrice > 0;

    if (widget.initialExpense != null) {
      final exp = widget.initialExpense!;
      _litresController = TextEditingController(
        text: exp.litres != null ? RefillCalculator.formatLitres(exp.litres!) : '',
      );
      _pricePerLitreController = TextEditingController(
        text: exp.pricePerLitre != null
            ? RefillCalculator.formatPrice(exp.pricePerLitre!)
            : (hasSettingsPrice ? RefillCalculator.formatPrice(settingsPrice) : ''),
      );
      _totalPaidController = TextEditingController(
        text: exp.amount > 0 ? exp.amount.round().toString() : '',
      );

      _calculator = RefillCalculator();
      if (exp.litres != null && exp.pricePerLitre != null) {
        _calculator.initForExisting();
      } else {
        _calculator.initForExisting(hasAllThree: false);
      }
    } else {
      _litresController = TextEditingController();
      _pricePerLitreController = TextEditingController(
        text: hasSettingsPrice ? RefillCalculator.formatPrice(settingsPrice) : '',
      );
      _totalPaidController = TextEditingController();
      _calculator = RefillCalculator(prefilledPrice: hasSettingsPrice);
    }
  }

  @override
  void dispose() {
    _litresController.dispose();
    _pricePerLitreController.dispose();
    _totalPaidController.dispose();
    super.dispose();
  }

  void _onLitresChanged(String val) {
    if (_isUpdatingProgrammatically) return;
    setState(() => _errorMessage = null);
    _calculator.registerEdit(RefillField.litres);
    _applyCalculation();
  }

  void _onPriceChanged(String val) {
    if (_isUpdatingProgrammatically) return;
    setState(() => _errorMessage = null);
    _calculator.registerEdit(RefillField.price);
    _applyCalculation();
  }

  void _onTotalPaidChanged(String val) {
    if (_isUpdatingProgrammatically) return;
    setState(() => _errorMessage = null);
    _calculator.registerEdit(RefillField.total);
    _applyCalculation();
  }

  void _applyCalculation() {
    final result = _calculator.calculate(
      litresText: _litresController.text,
      priceText: _pricePerLitreController.text,
      totalText: _totalPaidController.text,
    );

    if (result.calculatedField != null) {
      _isUpdatingProgrammatically = true;
      switch (result.calculatedField!) {
        case RefillField.litres:
          _litresController.text = result.calculatedValue;
          break;
        case RefillField.price:
          _pricePerLitreController.text = result.calculatedValue;
          break;
        case RefillField.total:
          _totalPaidController.text = result.calculatedValue;
          break;
      }
      _isUpdatingProgrammatically = false;
    }
    setState(() {});
  }

  void _saveCurrentFuel() {
    FuelRefillService.setFuelLevel(
      bikeId: widget.bike.id,
      litres: _liters,
    );
    Navigator.of(context).pop();
  }

  Future<void> _saveRefillExpense() async {
    final litresText = _litresController.text.trim();
    final priceText = _pricePerLitreController.text.trim();
    final totalText = _totalPaidController.text.trim();

    final litres = double.tryParse(litresText);
    final price = double.tryParse(priceText);
    final total = parsePkr(totalText);

    if (litres == null || litres <= 0) {
      setState(() => _errorMessage = 'Litres must be greater than 0');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Litres must be greater than 0'),
          backgroundColor: AppColors.alertRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (price == null || price <= 0) {
      setState(() => _errorMessage = 'Price per litre must be greater than 0');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Price per litre must be greater than 0'),
          backgroundColor: AppColors.alertRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (total == null || total <= 0) {
      setState(() => _errorMessage = 'Total paid must be greater than 0');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Total paid must be greater than 0'),
          backgroundColor: AppColors.alertRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final roundedPrice = double.parse(price.toStringAsFixed(2));
    final roundedTotal = total.roundToDouble();

    // Check full-to-full learning opportunity
    double? learnedAvg;
    final currentOdo = widget.bike.preciseOdometerKm ??
        widget.bike.odometerKm.toDouble();
    final prevFullOdo = widget.bike.lastFullRefillOdometer;
    final isFull = _isFullTank || (litres >= _tankCapacity - 0.2);

    if (widget.initialExpense == null &&
        isFull &&
        prevFullOdo != null &&
        litres > 0.5) {
      final distanceTraveled = currentOdo - prevFullOdo;
      if (distanceTraveled > 10.0) {
        final computedAvg = FuelEstimator.computeFullToFullEfficiency(
          distanceTraveled,
          litres,
        );

        if (computedAvg != null && computedAvg > 0) {
          final roundedAvg = double.parse(computedAvg.toStringAsFixed(1));
          final shouldUpdate = await _showLearningDialog(
            distanceTraveled: distanceTraveled,
            litersAdded: litres,
            computedAvg: roundedAvg,
          );
          if (shouldUpdate == true) {
            learnedAvg = roundedAvg;
          }
        }
      }
    }

    await FuelRefillService.recordRefill(
      bikeId: _selectedBikeId ?? widget.bike.id,
      litres: litres,
      pricePerLitre: roundedPrice,
      total: roundedTotal,
      isFullTank: _isFullTank,
      existingExpense: widget.initialExpense,
      fuelAverageKmPerLiter: learnedAvg,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.initialExpense != null
                ? 'Updated refill (${formatPkr(roundedTotal)})'
                : 'Added refill (${formatPkr(roundedTotal)})',
          ),
          backgroundColor: AppColors.darkCharcoal,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Future<bool?> _showLearningDialog({
    required double distanceTraveled,
    required double litersAdded,
    required double computedAvg,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Full-to-Full Refill Learning',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
            color: AppColors.darkCharcoal,
            fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tracked ${distanceTraveled.toStringAsFixed(1)} km between full refills with ${litersAdded.toStringAsFixed(1)} L added.',
              style: GoogleFonts.manrope(
                fontSize: 13.5,
                color: AppColors.darkCharcoal,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.clay,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.speed_rounded,
                    color: AppColors.tacticalOrange,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Calculated: $computedAvg km/L',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.tacticalOrange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Update fuel average to $computedAvg km/L?',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.darkCharcoal,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Keep mine',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                color: AppColors.mutedText,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.tacticalOrange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Yes, update',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteRefill(BuildContext context, Expense expense) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.clay,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Expense?',
          style: GoogleFonts.manrope(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.darkCharcoal,
          ),
        ),
        content: Text(
          'Are you sure you want to delete ${expense.title} (${formatPkr(expense.amount)})?',
          style: AppTextStyles.bodySecondary.copyWith(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.of(ctx).pop(true);
              final removedIndex =
                  TripBudgetController.instance.expenses.indexOf(expense);
              TripBudgetController.instance.deleteExpense(expense.id);
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Deleted ${expense.title}'),
                  backgroundColor: AppColors.darkCharcoal,
                  behavior: SnackBarBehavior.floating,
                  action: SnackBarAction(
                    label: 'Undo',
                    textColor: AppColors.tacticalOrange,
                    onPressed: () {
                      TripBudgetController.instance.insertExpense(
                        removedIndex,
                        expense,
                      );
                    },
                  ),
                ),
              );
            },
            child: Text(
              'Delete',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fuelAvg = widget.bike.fuelAverageKmPerLiter;
    final range = FuelEstimator.rangeKm(_liters, fuelAvg);
    final pct = FuelEstimator.percent(_liters, _tankCapacity) ?? 0.0;
    final isEditing = widget.initialExpense != null;

    final litersNeeded = (_tankCapacity - (widget.bike.fuelRemainingLiters ?? 0.0))
        .clamp(0.0, _tankCapacity);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.clay,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppColors.skeuRaisedSmall,
                ),
                child: const Icon(
                  Icons.local_gas_station_rounded,
                  color: AppColors.tacticalOrange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditing ? 'Edit Fuel Refill' : 'Fuel Level & Refill',
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkCharcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.bike.make} ${widget.bike.modelName} • ${_tankCapacity.toStringAsFixed(0)} L Tank',
                      style: GoogleFonts.manrope(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Mode toggle (hidden when editing a specific expense)
          if (!isEditing) ...[
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showRefillSection = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !_showRefillSection
                            ? AppColors.tacticalOrange
                            : AppColors.clay,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: !_showRefillSection
                            ? AppColors.orangeGlow
                            : AppColors.skeuRaisedSmall,
                      ),
                      child: Center(
                        child: Text(
                          'Set Current Fuel',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: !_showRefillSection
                                ? Colors.white
                                : AppColors.darkCharcoal,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showRefillSection = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _showRefillSection
                            ? AppColors.tacticalOrange
                            : AppColors.clay,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _showRefillSection
                            ? AppColors.orangeGlow
                            : AppColors.skeuRaisedSmall,
                      ),
                      child: Center(
                        child: Text(
                          'I Refilled',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _showRefillSection
                                ? Colors.white
                                : AppColors.darkCharcoal,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
          ],

          if (!_showRefillSection) ...[
            // ── Set Current Fuel Mode (live fuel estimate stays as is) ──
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.clay,
                borderRadius: BorderRadius.circular(AppColors.radiusTile),
                boxShadow: AppColors.skeuInset,
              ),
              child: Column(
                children: [
                  Text(
                    '${_liters.toStringAsFixed(1)} / ${_tankCapacity.toStringAsFixed(0)} L',
                    style: GoogleFonts.manrope(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.darkCharcoal,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    range != null
                        ? 'about ${range.round()} km range • ${pct.toStringAsFixed(0)}%'
                        : '${pct.toStringAsFixed(0)}% • Add fuel average to see range',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.tacticalOrange,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Slider in liters
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.tacticalOrange,
                inactiveTrackColor: const Color(0xFFE5E7EB),
                thumbColor: AppColors.tacticalOrange,
                overlayColor: AppColors.tacticalOrange.withValues(alpha: 0.15),
                trackHeight: 6,
              ),
              child: Slider(
                value: _liters,
                min: 0.0,
                max: _tankCapacity,
                divisions: (_tankCapacity * 10).round().clamp(10, 500),
                onChanged: (val) => setState(() => _liters = val),
              ),
            ),

            // Presets in liters
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _presetLitersChip('Empty', 0.0),
                _presetLitersChip(
                  '${(_tankCapacity * 0.25).toStringAsFixed(1)} L',
                  _tankCapacity * 0.25,
                ),
                _presetLitersChip(
                  '${(_tankCapacity * 0.50).toStringAsFixed(1)} L',
                  _tankCapacity * 0.50,
                ),
                _presetLitersChip(
                  '${(_tankCapacity * 0.75).toStringAsFixed(1)} L',
                  _tankCapacity * 0.75,
                ),
                _presetLitersChip(
                  'Full (${_tankCapacity.toStringAsFixed(0)} L)',
                  _tankCapacity,
                ),
              ],
            ),

            const SizedBox(height: 24),

            PrimaryButton(
              label: 'Save Fuel Level',
              icon: Icons.check_rounded,
              onTap: _saveCurrentFuel,
              isFullWidth: true,
            ),
          ] else ...[
            // ── Refill Mode (3 live calculating fields) ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.clay,
                borderRadius: BorderRadius.circular(AppColors.radiusTile),
                boxShadow: AppColors.skeuRaisedSmall,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Bike picker dropdown
                  LabeledDropdown<String?>(
                    label: 'BIKE',
                    value: _selectedBikeId,
                    items: [
                      null,
                      ...ActiveBikeController.instance.bikes.map((b) => b.id),
                      if (_selectedBikeId != null &&
                          !ActiveBikeController.instance.bikes
                              .any((b) => b.id == _selectedBikeId))
                        _selectedBikeId,
                    ],
                    itemLabelBuilder: (id) {
                      if (id == null) return 'No bike';
                      final b =
                          ActiveBikeController.instance.getBikeById(id);
                      return b != null ? b.name : 'Deleted bike';
                    },
                    onChanged: (val) => setState(() => _selectedBikeId = val),
                  ),
                  const SizedBox(height: 14),

                  // Quick presets for litres
                  if (!isEditing) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'QUICK FILL',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.mutedText,
                          ),
                        ),
                        if (litersNeeded > 0)
                          GestureDetector(
                            onTap: () {
                              _litresController.text = RefillCalculator.formatLitres(litersNeeded);
                              _onLitresChanged(_litresController.text);
                            },
                            child: Text(
                              'To Full (+${RefillCalculator.formatLitres(litersNeeded)} L)',
                              style: GoogleFonts.manrope(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.tacticalOrange,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _quickLitersChip('+2 L', 2.0),
                        const SizedBox(width: 8),
                        _quickLitersChip('+5 L', 5.0),
                        const SizedBox(width: 8),
                        _quickLitersChip('+10 L', 10.0),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Field 1: Litres
                  _buildInputRow(
                    label: 'LITRES',
                    controller: _litresController,
                    hint: '0',
                    suffix: 'L',
                    onChanged: _onLitresChanged,
                    isCalculated: _calculator.calculatedField == RefillField.litres,
                  ),

                  const SizedBox(height: 14),

                  // Field 2: Price per litre
                  _buildInputRow(
                    label: 'PRICE PER LITRE',
                    controller: _pricePerLitreController,
                    hint: '0',
                    prefix: 'Rs ',
                    suffix: '/ L',
                    onChanged: _onPriceChanged,
                    isCalculated: _calculator.calculatedField == RefillField.price,
                  ),

                  const SizedBox(height: 14),

                  // Field 3: Total paid
                  _buildInputRow(
                    label: 'TOTAL PAID',
                    controller: _totalPaidController,
                    hint: '0',
                    prefix: 'Rs ',
                    suffix: 'PKR',
                    onChanged: _onTotalPaidChanged,
                    isCalculated: _calculator.calculatedField == RefillField.total,
                  ),

                  const SizedBox(height: 14),

                  // "Filled the tank" switch
                  // The Step 4 learner uses full-to-full pairs.
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppColors.radiusTile),
                      boxShadow: AppColors.skeuRaisedSmall,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Filled the tank',
                                style: GoogleFonts.manrope(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.darkCharcoal,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Sets fuel level to full capacity',
                                style: GoogleFonts.manrope(
                                  fontSize: 11.5,
                                  color: AppColors.mutedText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: _isFullTank,
                          activeTrackColor: AppColors.tacticalOrange,
                          onChanged: (val) {
                            setState(() => _isFullTank = val);
                          },
                        ),
                      ],
                    ),
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _errorMessage!,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.alertRed,
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  PrimaryButton(
                    label: isEditing ? 'Update Refill' : 'Save Refill',
                    icon: Icons.check_rounded,
                    onTap: _saveRefillExpense,
                    isFullWidth: true,
                  ),

                  if (isEditing) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.alertRed,
                        ),
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 18),
                        label: Text(
                          'Delete Refill',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.alertRed,
                          ),
                        ),
                        onPressed: () {
                          final exp = widget.initialExpense!;
                          Navigator.of(context).pop();
                          _confirmDeleteRefill(context, exp);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

  Widget _quickLitersChip(String label, double val) {
    return GestureDetector(
      onTap: () {
        final current = RefillCalculator.parsePositiveDouble(_litresController.text) ?? 0.0;
        final newLitres = (current <= 0) ? val : current + val;
        _litresController.text = RefillCalculator.formatLitres(newLitres);
        _onLitresChanged(_litresController.text);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppColors.radiusPill),
          boxShadow: AppColors.skeuRaisedSmall,
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: AppColors.darkCharcoal,
          ),
        ),
      ),
    );
  }

  Widget _buildInputRow({
    required String label,
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onChanged,
    String? prefix,
    String? suffix,
    bool isCalculated = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: isCalculated ? AppColors.tacticalOrange : AppColors.mutedText,
                letterSpacing: 0.5,
              ),
            ),
            if (isCalculated)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: AppColors.tacticalOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'CALCULATED',
                  style: GoogleFonts.manrope(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppColors.tacticalOrange,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: isCalculated
                ? Border.all(
                    color: AppColors.tacticalOrange.withValues(alpha: 0.35),
                    width: 1.2,
                  )
                : null,
            boxShadow: AppColors.skeuInset,
          ),
          child: Row(
            children: [
              if (prefix != null)
                Text(
                  prefix,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.mutedText,
                  ),
                ),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkCharcoal,
                  ),
                  cursorColor: AppColors.tacticalOrange,
                  decoration: InputDecoration(
                    hintText: hint,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: onChanged,
                ),
              ),
              if (suffix != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isCalculated
                        ? AppColors.tacticalOrange.withValues(alpha: 0.12)
                        : AppColors.clay,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    suffix,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isCalculated
                          ? AppColors.tacticalOrange
                          : AppColors.darkCharcoal,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _presetLitersChip(String label, double value) {
    final isSelected = (_liters - value).abs() < 0.1;
    return GestureDetector(
      onTap: () => setState(() => _liters = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.tacticalOrange : AppColors.clay,
          borderRadius: BorderRadius.circular(AppColors.radiusPill),
          boxShadow:
              isSelected ? AppColors.orangeGlow : AppColors.skeuRaisedSmall,
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppColors.darkCharcoal,
          ),
        ),
      ),
    );
  }
}

