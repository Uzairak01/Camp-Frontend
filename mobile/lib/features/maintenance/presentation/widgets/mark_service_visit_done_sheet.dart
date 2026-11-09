import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../garage/controllers/active_bike_controller.dart';
import '../../controllers/service_visit_controller.dart';
import '../../domain/service_visit_model.dart';

/// Modal bottom sheet for marking a planned or past service visit done.
/// Prompts for actual cost (prefilled with expected cost, editable, optional)
/// and bike (prefilled with visit's bike).
class MarkServiceVisitDoneSheet extends StatefulWidget {
  const MarkServiceVisitDoneSheet({required this.visit, super.key});

  final ServiceVisit visit;

  static Future<void> show(BuildContext context, {required ServiceVisit visit}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MarkServiceVisitDoneSheet(visit: visit),
    );
  }

  @override
  State<MarkServiceVisitDoneSheet> createState() =>
      _MarkServiceVisitDoneSheetState();
}

class _MarkServiceVisitDoneSheetState extends State<MarkServiceVisitDoneSheet> {
  late final TextEditingController _costCtrl;
  String? _selectedBikeId;

  @override
  void initState() {
    super.initState();
    _selectedBikeId =
        widget.visit.bikeId ?? ActiveBikeController.instance.activeBike?.id;
    final costVal = widget.visit.cost;
    final costStr = (costVal != null && costVal > 0)
        ? (costVal % 1 == 0 ? costVal.toInt().toString() : costVal.toString())
        : '';
    _costCtrl = TextEditingController(text: costStr);
  }

  @override
  void dispose() {
    _costCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final costText = _costCtrl.text.trim();
    final actualCost = costText.isNotEmpty ? double.tryParse(costText) : null;

    try {
      await ServiceVisitController.instance.markVisitDone(
        visit: widget.visit,
        actualCost: actualCost,
        bikeId: _selectedBikeId,
        context: context,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Marked visit to ${widget.visit.shopName} as done'),
          backgroundColor: AppColors.darkCharcoal,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.clay,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pill drag handle
            Center(
              child: Container(
                width: 36,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mark Visit Done',
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.visit.shopName,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
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
                final bike = ActiveBikeController.instance.getBikeById(id);
                return bike != null ? bike.name : 'Deleted bike';
              },
              onChanged: (val) => setState(() => _selectedBikeId = val),
            ),
            const SizedBox(height: 14),

            // Actual cost field
            LabeledTextField(
              label: 'ACTUAL COST (OPTIONAL)',
              controller: _costCtrl,
              prefixText: 'Rs ',
              placeholder: '0',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 20),

            // Save button
            PrimaryButton(
              label: 'Mark Done',
              onTap: _save,
            ),
          ],
        ),
      ),
    );
  }
}
