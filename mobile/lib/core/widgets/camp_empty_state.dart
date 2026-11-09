import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import 'camp_card.dart';

/// Reusable Empty State widget providing an icon, single-line message,
/// and an actionable CTA button adhering to CAMP design tokens.
class CampEmptyState extends StatelessWidget {
  const CampEmptyState({
    required this.icon,
    required this.message,
    required this.ctaLabel,
    required this.onCta,
    this.subMessage,
    super.key,
  });

  final IconData icon;
  final String message;
  final String? subMessage;
  final String ctaLabel;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    return CampCard(
      borderRadius: AppColors.radiusTile,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.clayDark,
              shape: BoxShape.circle,
              boxShadow: AppColors.skeuInset,
            ),
            child: Center(
              child: Icon(
                icon,
                size: 24,
                color: AppColors.tacticalOrange,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.darkCharcoal,
            ),
          ),
          if (subMessage != null) ...[
            const SizedBox(height: 4),
            Text(
              subMessage!,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.mutedText,
              ),
            ),
          ],
          const SizedBox(height: 14),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onCta,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.clay,
                borderRadius: BorderRadius.circular(AppColors.radiusPill),
                boxShadow: AppColors.skeuRaisedSmall,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.add_rounded,
                    size: 15,
                    color: AppColors.tacticalOrange,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    ctaLabel,
                    style: AppTextStyles.overlineTerracotta.copyWith(
                      fontSize: 11,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
