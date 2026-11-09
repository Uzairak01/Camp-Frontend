import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';

class ViewToggleWidget extends StatelessWidget {
  const ViewToggleWidget({
    required this.isListView,
    required this.onToggle,
    super.key,
  });
  final bool isListView;
  final ValueChanged<bool> onToggle;

  static const LinearGradient _orangeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.tacticalOrangeLight, AppColors.tacticalOrange],
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.clayDark,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.clayDark, width: 1),
          boxShadow: AppColors.skeuRecessed,
        ),
        padding: const EdgeInsets.all(4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tabWidth = (constraints.maxWidth) / 2;

            return Stack(
              children: [
                // Animated Orange Slider Indicator
                AnimatedAlign(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOutCubic,
                  alignment: isListView
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: Container(
                    width: tabWidth,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: _orangeGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppColors.orangeGlow,
                    ),
                  ),
                ),

                // Row with Two Clickable Tabs
                Row(
                  children: [
                    // List View Tab
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onToggle(true),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.format_list_bulleted_rounded,
                                size: 18,
                                color: isListView
                                    ? Colors.white
                                    : AppColors.mutedText,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'List View',
                                style: AppTextStyles.body.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isListView
                                      ? Colors.white
                                      : AppColors.mutedText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Map View Tab
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onToggle(false),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.map_outlined,
                                size: 18,
                                color: !isListView
                                    ? Colors.white
                                    : AppColors.mutedText,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Map View',
                                style: AppTextStyles.body.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: !isListView
                                      ? Colors.white
                                      : AppColors.mutedText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
