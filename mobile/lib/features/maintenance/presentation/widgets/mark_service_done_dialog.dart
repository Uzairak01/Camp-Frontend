import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/camp_card.dart';
import '../../../garage/domain/bike_model.dart';
import '../../controllers/maintenance_controller.dart';
import '../../domain/service_schedule_item.dart';

/// Modal dialog allowing the rider to mark a service item as completed.
///
/// Collects odometer reading (prefilled from bike, editable), completion date (today),
/// and an optional cost entered strictly by the rider (never estimated).
class MarkServiceDoneDialog extends StatefulWidget {
  const MarkServiceDoneDialog({
    required this.bike,
    required this.item,
    super.key,
  });

  final Bike bike;
  final ServiceScheduleItem item;

  static Future<void> show(
    BuildContext context, {
    required Bike bike,
    required ServiceScheduleItem item,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => MarkServiceDoneDialog(bike: bike, item: item),
    );
  }

  @override
  State<MarkServiceDoneDialog> createState() => _MarkServiceDoneDialogState();
}

class _MarkServiceDoneDialogState extends State<MarkServiceDoneDialog> {
  late final TextEditingController _odoController;
  late final TextEditingController _costController;
  DateTime _selectedDate = DateTime.now();
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _odoController = TextEditingController(text: widget.bike.odometerKm.toString());
    _costController = TextEditingController();
  }

  @override
  void dispose() {
    _odoController.dispose();
    _costController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final odoText = _odoController.text.trim();
    final odo = double.tryParse(odoText);
    if (odo == null || odo < 0) {
      setState(() {
        _errorText = 'Enter a valid odometer reading in km';
      });
      return;
    }

    final costText = _costController.text.trim();
    final double? cost = costText.isNotEmpty ? parsePkr(costText) ?? double.tryParse(costText) : null;

    try {
      await MaintenanceController.instance.markItemDone(
        widget.bike.id,
        widget.item.id,
        odometerKm: odo,
        date: _selectedDate,
        cost: cost,
        context: context,
      );
    } catch (_) {
      return;
    }

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.item.type.displayName} marked as done!'),
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.statusGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: CampCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Header
            Row(
              children: [
                Icon(widget.item.type.icon, color: AppColors.tacticalOrange, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mark Service Done',
                        style: GoogleFonts.manrope(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                      Text(
                        widget.item.type.displayName,
                        style: GoogleFonts.manrope(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  color: AppColors.mutedText,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24, color: AppColors.clayDark),

            // Odometer Field
            Text(
              'Odometer at service (km)',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.darkCharcoal,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _odoController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                suffixText: 'km',
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusTile - 4),
                  borderSide: const BorderSide(color: AppColors.clayDark),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Service Date Picker
            Text(
              'Date completed',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.darkCharcoal,
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() {
                    _selectedDate = picked;
                  });
                }
              },
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppColors.radiusTile - 4),
                  border: Border.all(color: AppColors.clayDark),
                ),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.mutedText),
                    const SizedBox(width: 8),
                    Text(
                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkCharcoal,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.edit_calendar_rounded, size: 16, color: AppColors.mutedLight),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Optional Cost Field (Entered by rider only, never estimated)
            Text(
              'Service cost in PKR (optional)',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.darkCharcoal,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _costController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                prefixText: 'Rs ',
                hintText: 'e.g. 1500 (rider-entered only)',
                hintStyle: GoogleFonts.manrope(fontSize: 12, color: AppColors.mutedLight),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusTile - 4),
                  borderSide: const BorderSide(color: AppColors.clayDark),
                ),
              ),
            ),

            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorText!,
                style: GoogleFonts.manrope(fontSize: 12, color: AppColors.alertRed, fontWeight: FontWeight.w600),
              ),
            ],

            const SizedBox(height: 20),

            // Confirm Button
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppColors.radiusTile - 4),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.tacticalOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppColors.radiusTile - 4),
                      ),
                    ),
                    onPressed: _submit,
                    child: Text(
                      'Save Record',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
