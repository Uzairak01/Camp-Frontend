import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';

class FilterChipsWidget extends StatelessWidget {
  const FilterChipsWidget({
    required this.selectedFilter,
    required this.onFilterSelected,
    this.allCount = 0,
    this.openNowCount = 0,
    this.emergencyCount = 0,
    super.key,
  });

  final String selectedFilter;
  final ValueChanged<String> onFilterSelected;
  final int allCount;
  final int openNowCount;
  final int emergencyCount;

  static const LinearGradient _orangeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.tacticalOrangeLight, AppColors.tacticalOrange],
  );

  @override
  Widget build(BuildContext context) {
    final filters = [
      {'id': 'all', 'label': 'All', 'count': allCount.toString()},
      {'id': 'open_now', 'label': 'Open now', 'count': openNowCount.toString()},
      {'id': 'emergency', 'label': 'Emergency Pitstop', 'count': emergencyCount.toString()},
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final id = filter['id']!;
          final label = filter['label']!;
          final isSelected = selectedFilter == id;
          final count = filter['count'];

          return GestureDetector(
            onTap: () => onFilterSelected(id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: isSelected ? _orangeGradient : null,
                color: isSelected ? null : AppColors.clay,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : AppColors.clayDark,
                  width: 1.2,
                ),
                boxShadow: isSelected
                    ? AppColors.orangeGlow
                    : AppColors.skeuRaisedSmall,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppColors.darkCharcoal,
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.tacticalOrangeDark
                            : AppColors.clayDark,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        count,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? Colors.white
                              : AppColors.mutedText,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
