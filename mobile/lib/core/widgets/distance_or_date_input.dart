import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../features/garage/domain/bike_model.dart';

/// Reusable input widget for capturing maintenance milestones either "By Distance" or "By Date".
/// Features a two-tab segmented pill header and a dynamic input area that swaps between
/// a numeric km field (with "km ago" suffix) and a tactile date picker.
class DistanceOrDateInput extends StatefulWidget {
  const DistanceOrDateInput({
    required this.label,
    super.key,
    this.value,
    this.placeholderKm = 'e.g. 3,200',
    this.onChanged,
  });

  final String label;
  final ServiceRecord? value;
  final String placeholderKm;
  final ValueChanged<ServiceRecord>? onChanged;

  @override
  State<DistanceOrDateInput> createState() => _DistanceOrDateInputState();
}

class _DistanceOrDateInputState extends State<DistanceOrDateInput> {
  late TrackingMode _currentMode;
  late TextEditingController _kmController;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.value?.mode ?? TrackingMode.byDistance;
    final initialKm = widget.value?.km;
    _kmController = TextEditingController(
      text: initialKm != null ? initialKm.toString() : '',
    );
    _selectedDate = widget.value?.date;
  }

  @override
  void didUpdateWidget(covariant DistanceOrDateInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != null && widget.value != oldWidget.value) {
      if (_currentMode != widget.value!.mode) {
        _currentMode = widget.value!.mode;
      }
      final newKmText =
          widget.value!.km != null ? widget.value!.km.toString() : '';
      if (_kmController.text != newKmText) {
        _kmController.text = newKmText;
      }
      _selectedDate = widget.value!.date;
    }
  }

  @override
  void dispose() {
    _kmController.dispose();
    super.dispose();
  }

  void _notifyChange() {
    final parsedKm = int.tryParse(
      _kmController.text.replaceAll(',', '').trim(),
    );
    final record = ServiceRecord(
      mode: _currentMode,
      km: parsedKm,
      date: _selectedDate,
    );
    widget.onChanged?.call(record);
  }

  void _setMode(TrackingMode mode) {
    if (_currentMode == mode) return;
    HapticFeedback.selectionClick();
    setState(() {
      _currentMode = mode;
    });
    _notifyChange();
  }

  Future<void> _pickDate() async {
    HapticFeedback.lightImpact();
    final now = DateTime.now();
    final initial = _selectedDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(1980),
      lastDate: now,
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
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _notifyChange();
    }
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final m = months[dt.month - 1];
    final d = dt.day.toString().padLeft(2, '0');
    return '$m $d, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header Row: Label + Segmented Mode Tabs ──────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkCharcoal,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                color: AppColors.clayDark,
                borderRadius: BorderRadius.circular(AppColors.radiusPill),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.65),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTab(
                    title: 'By Distance',
                    isSelected: _currentMode == TrackingMode.byDistance,
                    onTap: () => _setMode(TrackingMode.byDistance),
                  ),
                  _buildTab(
                    title: 'By Date',
                    isSelected: _currentMode == TrackingMode.byDate,
                    onTap: () => _setMode(TrackingMode.byDate),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),

        // ── Input Container (Swaps between numeric km and date picker) ─────────
        if (_currentMode == TrackingMode.byDistance)
          Container(
            decoration: BoxDecoration(
              color: AppColors.clayDark,
              borderRadius: BorderRadius.circular(AppColors.radiusTile),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.45),
                width: 1,
              ),
              boxShadow: AppColors.skeuRecessed,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _kmController,
                    keyboardType: TextInputType.number,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    cursorColor: AppColors.tacticalOrange,
                    onChanged: (_) => _notifyChange(),
                    decoration: InputDecoration(
                      hintText: widget.placeholderKm,
                      hintStyle: GoogleFonts.manrope(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.mutedLight,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Text(
                    'km ago',
                    style: GoogleFonts.manrope(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mutedText,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          GestureDetector(
            onTap: _pickDate,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              decoration: BoxDecoration(
                color: AppColors.clayDark,
                borderRadius: BorderRadius.circular(AppColors.radiusTile),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.45),
                  width: 1,
                ),
                boxShadow: AppColors.skeuRecessed,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedDate != null
                          ? _formatDate(_selectedDate!)
                          : 'Select service date',
                      style: GoogleFonts.manrope(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: _selectedDate != null
                            ? AppColors.darkCharcoal
                            : AppColors.mutedLight,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 18,
                    color: AppColors.tacticalOrange,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTab({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.tacticalOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(AppColors.radiusPill),
          boxShadow: isSelected ? AppColors.orangeGlow : null,
        ),
        child: Text(
          title,
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.mutedText,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
