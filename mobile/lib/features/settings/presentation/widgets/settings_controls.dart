import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/units_system.dart';

/// Tactile orange toggle switch with smooth animated thumb and glow effect.
class TacticalSwitch extends StatelessWidget {
  const TacticalSwitch({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: 48,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? AppColors.tacticalOrange : AppColors.clayDark,
          borderRadius: BorderRadius.circular(AppColors.radiusPill),
          border: Border.all(
            color: value
                ? AppColors.tacticalOrangeDark.withValues(alpha: 0.6)
                : const Color(0x18000000),
            width: 1.2,
          ),
          boxShadow: value ? AppColors.orangeGlow : AppColors.skeuRecessed,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact inline segmented control for switching between Metric and Imperial unit systems.
class InlineUnitsToggle extends StatelessWidget {
  const InlineUnitsToggle({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final UnitsSystem selected;
  final ValueChanged<UnitsSystem> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.clayDark,
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 1,
        ),
        boxShadow: AppColors.skeuRecessed,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOption(
            label: 'Metric (km, °C)',
            isSelected: selected == UnitsSystem.metric,
            onTap: () => onChanged(UnitsSystem.metric),
          ),
          _buildOption(
            label: 'Imperial (mi, °F)',
            isSelected: selected == UnitsSystem.imperial,
            onTap: () => onChanged(UnitsSystem.imperial),
          ),
        ],
      ),
    );
  }

  Widget _buildOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.tacticalOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(AppColors.radiusPill),
          boxShadow: isSelected ? AppColors.orangeGlow : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.mutedText,
          ),
        ),
      ),
    );
  }
}
