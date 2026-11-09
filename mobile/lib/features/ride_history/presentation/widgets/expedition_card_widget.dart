import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/expedition_log_model.dart';
import 'date_chip_widget.dart';
import 'expedition_footer_widget.dart';
import 'stat_tile_widget.dart';

/// Reusable expedition card.
/// DateChipWidget + StatusChip(tag) + small menu icon button top row;
/// title; route→bike subtitle; row of 4 stats; footer row.
class ExpeditionCardWidget extends StatelessWidget {
  const ExpeditionCardWidget({
    required this.log,
    super.key,
    this.onMoreTap,
    this.onLinkTap,
    this.onShare,
    this.onDelete,
  });

  final ExpeditionLog log;
  final VoidCallback? onMoreTap;
  final VoidCallback? onLinkTap;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return CampCard(
      padding: const EdgeInsets.all(AppColors.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: date chip, status chip, icon / menu ──────────────────
          Row(
            children: [
              DateChipWidget(label: log.date),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: StatusChip(
                    label: log.tag,
                    variant: log.tagVariant,
                    icon: log.tagIcon,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (onShare != null || onDelete != null)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.clay,
                    shape: BoxShape.circle,
                    boxShadow: AppColors.skeuRaisedSmall,
                  ),
                  child: PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.more_horiz_rounded,
                      size: 16,
                      color: AppColors.darkCharcoal,
                    ),
                    color: AppColors.dockBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 1,
                      ),
                    ),
                    onSelected: (val) {
                      if (val == 'share') onShare?.call();
                      if (val == 'delete') onDelete?.call();
                    },
                    itemBuilder: (context) => [
                      if (onShare != null)
                        PopupMenuItem(
                          value: 'share',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.share_outlined,
                                size: 16,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Share Ride',
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (onDelete != null)
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.delete_outline_rounded,
                                size: 16,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Delete ride',
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                )
              else
                GestureDetector(
                  onTap: onMoreTap,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.clay,
                      shape: BoxShape.circle,
                      boxShadow: AppColors.skeuRaisedSmall,
                    ),
                    child: Center(
                      child: Icon(
                        log.icon,
                        size: 15,
                        color: log.tagVariant == StatusChipVariant.neutral
                            ? AppColors.mutedText
                            : AppColors.tacticalOrange,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Title ──────────────────────────────────────────────────────────
          Text(
            log.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.itemTitle,
          ),

          const SizedBox(height: 3),

          // ── Route → bike subtitle ─────────────────────────────────────────
          Text(
            '${log.route} • ${log.bike}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySecondary,
          ),

          if (log.stats.isNotEmpty) ...[
            const SizedBox(height: 12),
            // ── Stats row ──────────────────────────────────────────────────
            Row(
              children: [
                for (int i = 0; i < log.stats.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: InsetTile(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      child: StatTileWidget(stat: log.stats[i]),
                    ),
                  ),
                ],
              ],
            ),
          ],

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1),
          ),

          // ── Footer ────────────────────────────────────────────────────────
          ExpeditionFooterWidget(
            footer: log.footer,
            linkLabel: log.footerLink,
            onLinkTap: onLinkTap,
          ),
        ],
      ),
    );
  }
}
