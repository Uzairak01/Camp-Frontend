import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/maintenance_item_model.dart';

/// One row entry for a maintenance telemetry or inspection item
class MaintenanceItemCardWidget extends StatelessWidget {
  const MaintenanceItemCardWidget({
    required this.item,
    super.key,
    this.onTap,
  });

  final MaintenanceItem item;
  final VoidCallback? onTap;

  static String _formatThousands(int num) {
    final str = num.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (Match m) => '${m[1]},');
  }

  String _formatConditionNote(MaintenanceItem item) {
    final note = item.conditionNote;
    if (note == null || note.isEmpty) {
      if (item.status == MaintenanceStatus.dueSoon) return 'Due soon';
      if (item.status == MaintenanceStatus.overdue) return 'Maintenance due';
      return '';
    }

    final trimmed = note.trim();
    final dueSoonReg = RegExp(r'^Due soon\s*[•:]\s*(.*)$', caseSensitive: false);
    final match = dueSoonReg.firstMatch(trimmed);
    if (match != null) {
      final rawVal = match.group(1)?.trim() ?? '';
      if (rawVal.isEmpty) return 'Due soon';

      final plainNum = int.tryParse(rawVal.replaceAll(',', '').replaceAll(' ', ''));
      if (plainNum != null) {
        final formattedNum = _formatThousands(plainNum);
        if (item.dueDate != null && item.dueDate!.isNotEmpty) {
          return 'Due soon • in $formattedNum days';
        } else {
          return 'Due soon • in $formattedNum km';
        }
      }

      final kmReg = RegExp(r'^(?:in\s+)?(\d[\d,]*)\s*km$', caseSensitive: false);
      final kmMatch = kmReg.firstMatch(rawVal);
      if (kmMatch != null) {
        final n = int.tryParse(kmMatch.group(1)!.replaceAll(',', ''));
        if (n != null) {
          return 'Due soon • in ${_formatThousands(n)} km';
        }
      }

      final daysReg = RegExp(r'^(?:in\s+)?(\d[\d,]*)\s*days?$', caseSensitive: false);
      final daysMatch = daysReg.firstMatch(rawVal);
      if (daysMatch != null) {
        final n = int.tryParse(daysMatch.group(1)!.replaceAll(',', ''));
        if (n != null) {
          return 'Due soon • in ${_formatThousands(n)} days';
        }
      }
    }

    return trimmed;
  }

  Widget _buildStatusValueWidget() {
    if (item.cost != null && item.cost! > 0) {
      return Text(
        formatPkr(item.cost!),
        style: GoogleFonts.manrope(
          color: AppColors.darkCharcoal,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      );
    }

    final val = item.statusValueDisplay ?? '';
    if (val == 'OK') {
      return const StatusChip(
        label: 'OK',
        variant: StatusChipVariant.success,
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      );
    } else if (val == 'DIY') {
      return const StatusChip(
        label: 'DIY',
        variant: StatusChipVariant.gold,
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      );
    } else if (val.startsWith('T-')) {
      return Text(
        val,
        style: GoogleFonts.manrope(
          color: AppColors.tacticalOrangeDark,
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
        ),
      );
    } else if (val.isNotEmpty && !val.contains(r'$')) {
      return Text(
        val,
        style: GoogleFonts.manrope(
          color: AppColors.darkCharcoal,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      );
    } else {
      return Text(
        'Add your cost',
        style: GoogleFonts.manrope(
          color: AppColors.mutedText,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontStyle: FontStyle.italic,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isSuccess = item.status == MaintenanceStatus.ok;

    return CampCard(
      padding: const EdgeInsets.all(14),
      borderRadius: AppColors.radiusTile,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Upper Item Info Row ───────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left Icon
              IconTile(
                icon: item.icon ?? Icons.build_circle_rounded,
                size: 38,
                iconSize: 18,
                isInset: true,
              ),
              const SizedBox(width: 12),

              // Title, Mode chip & Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.itemTitle.copyWith(
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        StatusChip(
                          label: item.trackingMode == MaintenanceTrackingMode.auto
                              ? 'Auto'
                              : 'Manual',
                          variant: item.trackingMode ==
                                  MaintenanceTrackingMode.manual
                              ? StatusChipVariant.gold
                              : StatusChipVariant.neutral,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    BikeLabelChip(bikeId: item.bikeId),
                    if (item.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Right status value (e.g. $85, OK, DIY, T-45%, $65)
              _buildStatusValueWidget(),
            ],
          ),

          // ── Bottom Warning / Condition Row ────────────────────────────────
          Builder(
            builder: (context) {
              final conditionText = _formatConditionNote(item);
              if (conditionText.isEmpty && item.trailingNote == null) {
                return const SizedBox.shrink();
              }
              return Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSuccess
                          ? const Color(0xFFDCFCE7).withValues(alpha: 0.5)
                          : const Color(0xFFFFEDD5).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSuccess
                              ? Icons.check_circle_outline_rounded
                              : Icons.warning_amber_rounded,
                          size: 14,
                          color: isSuccess
                              ? AppColors.statusGreen
                              : AppColors.tacticalOrangeDark,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            conditionText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: isSuccess
                                  ? AppColors.statusGreen
                                  : AppColors.tacticalOrangeDark,
                            ),
                          ),
                        ),
                        if (item.trailingNote != null)
                          Text(
                            item.trailingNote!,
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSuccess
                                  ? AppColors.statusGreen
                                  : AppColors.tacticalOrangeDark,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
