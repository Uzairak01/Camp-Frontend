import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// Widget #12 — Full-width "Load 20 Earlier Expedition Logs (2023–2024)" button.
///
/// GhostButton assessment: GhostButton renders as a borderless text+icon row
/// with no container/border/shadow — it is purely typographic and has no pill
/// border. The "Load More" button in the spec shows a bordered pill outline
/// consistent with a raised CampCard treatment, not GhostButton's borderless
/// style. Therefore this widget wraps a CampCard (raised pill) rather than
/// GhostButton, which would be invisible without a border.
class LoadMoreButtonWidget extends StatelessWidget {
  const LoadMoreButtonWidget({
    super.key,
    this.onTap,
    this.label = 'Load 20 Earlier Expedition Logs (2023–2024)',
  });

  final VoidCallback? onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return CampCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.history_rounded,
            size: 16,
            color: AppColors.tacticalOrangeDark,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                color: AppColors.tacticalOrangeDark,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
