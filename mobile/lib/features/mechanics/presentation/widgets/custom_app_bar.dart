import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

class CustomAppBar extends StatelessWidget {
  const CustomAppBar({
    super.key,
    this.onBackTap,
  });

  final VoidCallback? onBackTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Circular Back Button
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onBackTap,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.clay,
                border: Border.all(color: AppColors.clayDark, width: 1.2),
                boxShadow: AppColors.skeuRaisedSmall,
              ),
              child: const Center(
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 20,
                  color: AppColors.darkCharcoal,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
