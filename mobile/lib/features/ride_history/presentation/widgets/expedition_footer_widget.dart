import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/expedition_log_model.dart';

/// Widget #11 — Footer row inside expedition cards.
/// Either renders a Wrap of outlined chips or a muted note string,
/// always with an orange link label on the right.
class ExpeditionFooterWidget extends StatelessWidget {
  const ExpeditionFooterWidget({
    required this.footer,
    required this.linkLabel,
    super.key,
    this.onLinkTap,
  });

  final ExpeditionFooter footer;
  final String linkLabel;
  final VoidCallback? onLinkTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: _buildLeft()),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onLinkTap,
          behavior: HitTestBehavior.opaque,
          child: Text(linkLabel, style: AppTextStyles.orangeLink),
        ),
      ],
    );
  }

  Widget _buildLeft() {
    return switch (footer) {
      ExpeditionFooterChips(:final chips) => Wrap(
          spacing: 6,
          runSpacing: 4,
          children: chips
              .map(
                (chip) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.clayDark,
                      width: 1.2,
                    ),
                    borderRadius:
                        BorderRadius.circular(AppColors.radiusPill),
                  ),
                  child: Text(
                    chip,
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mutedText,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ExpeditionFooterNote(:final note) => Text(
          note,
          style: AppTextStyles.caption,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
    };
  }
}
