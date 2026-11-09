import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../garage/controllers/active_bike_controller.dart';
import '../../../mechanics/controllers/mechanic_controller.dart';
import '../../../mechanics/domain/mechanic_model.dart';
import '../../controllers/service_visit_controller.dart';
import '../../controllers/trip_budget_controller.dart';
import '../../domain/expense_model.dart';
import '../../domain/service_visit_model.dart';
import '../../domain/trip_budget_model.dart';

/// Modal bottom sheet for scheduling or editing a motorcycle service appointment.
class PlanServiceVisitSheet extends StatefulWidget {
  const PlanServiceVisitSheet({super.key, this.initialVisit});

  final ServiceVisit? initialVisit;

  static Future<void> show(BuildContext context, {ServiceVisit? initialVisit}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PlanServiceVisitSheet(initialVisit: initialVisit),
    );
  }

  @override
  State<PlanServiceVisitSheet> createState() => _PlanServiceVisitSheetState();
}

class _PlanServiceVisitSheetState extends State<PlanServiceVisitSheet> {
  final _shopNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _costCtrl = TextEditingController();

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  double? _latitude;
  double? _longitude;
  String? _selectedMechanicId;
  String? _selectedBikeId;

  @override
  void initState() {
    super.initState();
    if (widget.initialVisit != null) {
      final v = widget.initialVisit!;
      _selectedBikeId = v.bikeId;
      _shopNameCtrl.text = v.shopName;
      _phoneCtrl.text = v.phone ?? '';
      _noteCtrl.text = v.note ?? '';
      if (v.cost != null && v.cost! > 0) {
        _costCtrl.text = v.cost!.round().toString();
      }
      _selectedDate = v.dateTime;
      _selectedTime =
          TimeOfDay(hour: v.dateTime.hour, minute: v.dateTime.minute);
      _latitude = v.latitude;
      _longitude = v.longitude;
      _selectedMechanicId = v.mechanicId;
    } else {
      _selectedDate = DateTime.now().add(const Duration(days: 3));
      _selectedTime = const TimeOfDay(hour: 10, minute: 0);
      _selectedBikeId = ActiveBikeController.instance.activeBike?.id;
    }
  }

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _phoneCtrl.dispose();
    _noteCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(DateTime.now())
          ? DateTime.now()
          : _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.tacticalOrange,
              onPrimary: Colors.white,
              surface: AppColors.clay,
              onSurface: AppColors.darkCharcoal,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.tacticalOrange,
              onPrimary: Colors.white,
              surface: AppColors.clay,
              onSurface: AppColors.darkCharcoal,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _selectSavedMechanic(Mechanic mechanic) {
    setState(() {
      _selectedMechanicId = mechanic.id;
      _shopNameCtrl.text = mechanic.name;
      if (mechanic.phoneNumber != null && mechanic.phoneNumber!.isNotEmpty) {
        _phoneCtrl.text = mechanic.phoneNumber!;
      }
    });
  }

  Future<void> _save() async {
    final shop = _shopNameCtrl.text.trim();
    if (shop.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter or select a workshop / mechanic name'),
          backgroundColor: AppColors.alertRed,
        ),
      );
      return;
    }

    final combinedDt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final phone = _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null;
    final note = _noteCtrl.text.trim().isNotEmpty ? _noteCtrl.text.trim() : null;
    final cost = double.tryParse(_costCtrl.text.trim());
    final visitId = widget.initialVisit?.id ??
        'visit-${DateTime.now().millisecondsSinceEpoch}';
    String? expenseId = widget.initialVisit?.expenseId;
    final isDone = widget.initialVisit?.isDone ?? false;

    // Existing linked expenses or visits that are done: keep linked expense in sync.
    if (isDone || (expenseId != null && expenseId.isNotEmpty)) {
      if (expenseId != null && expenseId.isNotEmpty) {
        final existingExp = TripBudgetController.instance.expenses
            .cast<Expense?>()
            .firstWhere((e) => e?.id == expenseId, orElse: () => null);
        if (existingExp != null) {
          if (cost != null && cost > 0) {
            TripBudgetController.instance.updateExpense(
              existingExp.copyWith(
                amount: cost,
                bikeId: _selectedBikeId,
                title: '$shop Service',
                category: ExpenseCategory.service,
                dateRecorded: combinedDt,
                updatedAt: DateTime.now().toUtc(),
              ),
            );
          } else {
            TripBudgetController.instance.deleteExpense(expenseId);
            expenseId = null;
          }
        }
      } else if (isDone && cost != null && cost > 0) {
        final newExpId = 'exp-visit-${DateTime.now().millisecondsSinceEpoch}';
        final newExp = Expense(
          id: newExpId,
          title: '$shop Service',
          amount: cost,
          category: ExpenseCategory.service,
          trackingMode: ExpenseTrackingMode.manualEntry,
          dateRecorded: combinedDt,
          bikeId: _selectedBikeId,
          maintenanceItemId: visitId,
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        );
        TripBudgetController.instance.addExpense(newExp);
        expenseId = newExpId;
      }
    }
    // New planned visits do not create an expense yet: cost is stored on the visit only.

    final visit = widget.initialVisit != null
        ? widget.initialVisit!.copyWith(
            dateTime: combinedDt,
            shopName: shop,
            bikeId: _selectedBikeId,
            phone: phone,
            latitude: _latitude,
            longitude: _longitude,
            note: note,
            cost: cost != null && cost > 0 ? cost : null,
            expenseId: expenseId,
            mechanicId: _selectedMechanicId,
            isDone: isDone,
            updatedAt: DateTime.now().toUtc(),
          )
        : ServiceVisit(
            id: visitId,
            dateTime: combinedDt,
            shopName: shop,
            bikeId: _selectedBikeId,
            phone: phone,
            latitude: _latitude,
            longitude: _longitude,
            note: note,
            cost: cost != null && cost > 0 ? cost : null,
            expenseId: expenseId,
            mechanicId: _selectedMechanicId,
            isDone: false,
          );

    try {
      if (widget.initialVisit != null) {
        await ServiceVisitController.instance.updateVisit(visit);
      } else {
        await ServiceVisitController.instance.addVisit(visit);
      }
    } catch (_) {
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Service visit planned for ${formatTripDate(combinedDt)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.darkCharcoal,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final savedMechanics = MechanicController.instance.mechanics;
    final timeStr = _selectedTime.format(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.clay,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: AppColors.skeuRaised,
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.clayDark,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.initialVisit != null
                      ? 'Edit Service Visit'
                      : 'Plan Service Visit',
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkCharcoal,
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded,
                        size: 20, color: AppColors.mutedText),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Saved Mechanics quick chips
            if (savedMechanics.isNotEmpty) ...[
              Text(
                'PICK FROM SAVED MECHANICS',
                style: AppTextStyles.overline.copyWith(fontSize: 9),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: savedMechanics.map((m) {
                  final isSelected = _selectedMechanicId == m.id ||
                      _shopNameCtrl.text == m.name;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _selectSavedMechanic(m),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.tacticalOrange
                            : AppColors.clayDark,
                        borderRadius:
                            BorderRadius.circular(AppColors.radiusPill),
                      ),
                      child: Text(
                        '🛠 ${m.name}',
                        style: GoogleFonts.manrope(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : AppColors.darkCharcoal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
            ],

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
                final bike =
                    ActiveBikeController.instance.getBikeById(id);
                return bike != null ? bike.name : 'Deleted bike';
              },
              onChanged: (val) => setState(() => _selectedBikeId = val),
            ),
            const SizedBox(height: 14),

            // Workshop name input
            LabeledTextField(
              label: 'WORKSHOP / MECHANIC NAME',
              controller: _shopNameCtrl,
              placeholder: 'e.g. Babusar Trail Works, Ali Motors',
            ),
            const SizedBox(height: 14),

            // Date & Time pickers row
            Row(
              children: [
                // Date picker button
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _pickDate,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DATE', style: AppTextStyles.overline),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.clayDark,
                            borderRadius:
                                BorderRadius.circular(AppColors.radiusTile),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 16,
                                color: AppColors.tacticalOrange,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  formatTripDate(_selectedDate),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.manrope(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.darkCharcoal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Time picker button
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _pickTime,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TIME', style: AppTextStyles.overline),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.clayDark,
                            borderRadius:
                                BorderRadius.circular(AppColors.radiusTile),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                size: 16,
                                color: AppColors.tacticalOrange,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  timeStr,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.manrope(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.darkCharcoal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Contact phone
            LabeledTextField(
              label: 'PHONE NUMBER (OPTIONAL)',
              controller: _phoneCtrl,
              placeholder: 'e.g. +92 300 1234567',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),

            // Expected cost (optional) or Actual cost (optional) if already done
            LabeledTextField(
              label: widget.initialVisit?.isDone == true
                  ? 'Actual cost (optional)'
                  : 'Expected cost (optional)',
              controller: _costCtrl,
              prefixText: 'Rs ',
              placeholder: '0',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 14),

            // Note / service details
            LabeledTextField(
              label: 'NOTES / SERVICE REQUESTED (OPTIONAL)',
              controller: _noteCtrl,
              placeholder: 'e.g. 5,000 km oil change & chain tension check',
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            // Save button
            PrimaryButton(
              label: widget.initialVisit != null
                  ? 'Update Service Visit'
                  : 'Schedule Visit',
              onTap: _save,
            ),
          ],
        ),
      ),
    );
  }
}
