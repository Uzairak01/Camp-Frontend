import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';

/// Horizontally scrollable filter chip row for Ride History.
/// Renders "All rides (n)" plus one chip per terrain that exists in the saved rides.
class RideFilterChipsWidget extends StatelessWidget {
  const RideFilterChipsWidget({
    super.key,
    this.totalCount = 0,
    this.terrainCounts = const {},
    this.selectedTerrain,
    this.onTerrainSelected,
    this.initialSelected,
    this.onFilterChanged,
  });

  /// Total count of all rides.
  final int totalCount;

  /// Counts of rides grouped by terrain tag.
  final Map<String, int> terrainCounts;

  /// Currently active terrain filter (null indicates "All rides").
  final String? selectedTerrain;

  /// Callback when terrain filter selection changes.
  final ValueChanged<String?>? onTerrainSelected;

  /// Optional legacy index support.
  final int? initialSelected;
  final ValueChanged<int>? onFilterChanged;

  @override
  Widget build(BuildContext context) {
    // Only display terrains that actually exist in the saved rides
    final activeTerrains = terrainCounts.entries
        .where((e) => e.value > 0)
        .toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      clipBehavior: Clip.none,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LabelChip(
            label: 'All rides',
            count: totalCount,
            isSelected: selectedTerrain == null,
            onTap: () {
              if (selectedTerrain == null) return;
              HapticFeedback.selectionClick();
              onTerrainSelected?.call(null);
              onFilterChanged?.call(0);
            },
          ),
          for (int i = 0; i < activeTerrains.length; i++) ...[
            const SizedBox(width: 8),
            _LabelChip(
              label: activeTerrains[i].key,
              count: activeTerrains[i].value,
              isSelected: selectedTerrain == activeTerrains[i].key,
              onTap: () {
                if (selectedTerrain == activeTerrains[i].key) return;
                HapticFeedback.selectionClick();
                onTerrainSelected?.call(activeTerrains[i].key);
                onFilterChanged?.call(i + 1);
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ── Private chip helper ─────────────────────────────────────────────────────

class _LabelChip extends StatelessWidget {
  const _LabelChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.tacticalOrange : AppColors.clay,
          borderRadius: BorderRadius.circular(AppColors.radiusPill),
          border: Border.all(
            color: isSelected ? Colors.transparent : AppColors.clayDark,
            width: 1.2,
          ),
          boxShadow:
              isSelected ? AppColors.orangeGlow : AppColors.skeuRaisedSmall,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.darkCharcoal,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : AppColors.clayDark,
                borderRadius: BorderRadius.circular(AppColors.radiusPill),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : AppColors.mutedText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
