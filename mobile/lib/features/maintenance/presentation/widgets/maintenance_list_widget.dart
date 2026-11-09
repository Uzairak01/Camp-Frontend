import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../garage/controllers/active_bike_controller.dart';
import '../../domain/maintenance_item_model.dart';
import '../../domain/service_schedule_engine.dart';
import '../../domain/service_schedule_item.dart';
import 'maintenance_item_card_widget.dart';

/// List widget for upcoming & required maintenance items in the Finances hub.
///
/// Shows:
///  1. Section header with wrench icon (opens Add Maintenance Item)
///  2. Schedule-driven due items (Overdue / Due soon) from [ServiceScheduleEngine]
///  3. Configure Service Schedule row
///  4. Rider-added [MaintenanceItem] cards (with swipe-to-delete and undo)
///  5. "+ Add Maintenance Item" expandable button
class MaintenanceListWidget extends StatelessWidget {
  const MaintenanceListWidget({
    // ── Schedule-driven section (new) ─────────────────────────────────────
    required this.dueItems,
    required this.hasSchedule,
    required this.onSetUpSchedule,
    // ── Rider-added items section (restored) ──────────────────────────────
    required this.items,
    required this.onAddMaintenanceItem,
    super.key,
    this.onItemTapped,
    this.onItemDismissed,
    // ── Schedule item tap (new) ────────────────────────────────────────────
    this.onScheduleItemTapped,
  });

  // Schedule-driven
  final List<ServiceSchedulePrediction> dueItems;
  final bool hasSchedule;
  final VoidCallback onSetUpSchedule;

  // Rider-added (restored)
  final List<MaintenanceItem> items;
  final VoidCallback onAddMaintenanceItem;
  final ValueChanged<MaintenanceItem>? onItemTapped;
  final ValueChanged<MaintenanceItem>? onItemDismissed;

  // Schedule item tap (new)
  final ValueChanged<ServiceSchedulePrediction>? onScheduleItemTapped;

  // ── Formatters ─────────────────────────────────────────────────────────

  /// Formats the remaining/overdue description using the shared formatter.
  static String _formatRemaining(ServiceSchedulePrediction item) {
    return item.friendlyStatus.headline;
  }

  @override
  Widget build(BuildContext context) {
    final activeBikeId = ActiveBikeController.instance.activeBike?.id;
    final sortedItems = List<MaintenanceItem>.from(items)
      ..sort((a, b) {
        final aActive = a.bikeId != null && a.bikeId == activeBikeId;
        final bActive = b.bikeId != null && b.bikeId == activeBikeId;
        if (aActive && !bActive) return -1;
        if (!aActive && bActive) return 1;
        return 0;
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Eyebrow Overline ─────────────────────────────────────────────
        Text('RIG CONDITION', style: AppTextStyles.overline),
        const SizedBox(height: 4),

        // ── Section Header with Wrench IconTile (opens Add Item) ─────────
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              const Expanded(
                child: SectionHeader(
                  title: 'Upcoming & Required\nMaintenance',
                  maxLines: 2,
                  padding: EdgeInsets.zero,
                ),
              ),
              IconTile(
                icon: Icons.build_rounded,
                size: 32,
                iconSize: 16,
                isInset: false,
                iconColor: AppColors.tacticalOrangeDark,
                onTap: onAddMaintenanceItem,
              ),
            ],
          ),
        ),

        // ──────────────────────────────────────────────────────────────────
        // 1. SCHEDULE-DRIVEN DUE ITEMS (Overdue / Due soon)
        // ──────────────────────────────────────────────────────────────────
        if (!hasSchedule) ...[
          // Empty state: no schedule configured
          CampCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            borderRadius: AppColors.radiusTile,
            child: Center(
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: AppColors.clayDark,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: AppColors.tacticalOrange,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Set up your service schedule',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkCharcoal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Configure service intervals to track due components and get timely reminders.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 12,
                      color: AppColors.mutedText,
                    ),
                  ),
                  const SizedBox(height: 14),
                  PrimaryButton(
                    label: 'Set up your service schedule',
                    onTap: onSetUpSchedule,
                  ),
                ],
              ),
            ),
          ),
        ] else if (dueItems.isEmpty) ...[
          // Configured but nothing due
          CampCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            borderRadius: AppColors.radiusTile,
            child: Center(
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: AppColors.clayDark,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppColors.statusGreen,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Nothing due right now',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkCharcoal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'All scheduled maintenance items are up to date.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 12,
                      color: AppColors.mutedText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          // Due items — most urgent first
          ...dueItems.map((item) {
            final isOverdue = item.scheduleStatus == ScheduleItemStatus.overdue;
            final remainingText = _formatRemaining(item);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CampCard(
                padding: const EdgeInsets.all(14),
                borderRadius: AppColors.radiusTile,
                onTap: () => onScheduleItemTapped?.call(item),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconTile(
                      icon: item.type.icon,
                      iconColor: isOverdue ? AppColors.alertRed : AppColors.terracotta,
                      size: 40,
                      iconSize: 20,
                      isInset: true,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkCharcoal,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            remainingText,
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isOverdue ? AppColors.alertRed : AppColors.mutedText,
                            ),
                          ),
                          if (item.friendlyStatus.actionLabel != null) ...[
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () => onScheduleItemTapped?.call(item),
                              child: Text(
                                item.friendlyStatus.actionLabel!,
                                style: GoogleFonts.manrope(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.alertRed,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusChip(
                      label: isOverdue ? 'OVERDUE' : 'DUE SOON',
                      variant: isOverdue ? StatusChipVariant.danger : StatusChipVariant.warning,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],

        const SizedBox(height: 12),

        // ──────────────────────────────────────────────────────────────────
        // 2. CONFIGURE SERVICE SCHEDULE ROW (new, kept)
        // ──────────────────────────────────────────────────────────────────
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onSetUpSchedule,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.clay,
              borderRadius: BorderRadius.circular(AppColors.radiusTile),
              boxShadow: AppColors.skeuRaisedSmall,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 18,
                        color: AppColors.tacticalOrangeDark,
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Configure Service Schedule',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.tacticalOrangeDark,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.mutedText,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ──────────────────────────────────────────────────────────────────
        // 3. RIDER-ADDED MAINTENANCE ITEM CARDS (restored)
        // ──────────────────────────────────────────────────────────────────
        ...sortedItems.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Dismissible(
              key: ValueKey(item.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: AppColors.alertRed,
                  borderRadius: BorderRadius.circular(AppColors.radiusTile),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              onDismissed: (_) => onItemDismissed?.call(item),
              child: MaintenanceItemCardWidget(
                item: item,
                onTap: () => onItemTapped?.call(item),
              ),
            ),
          );
        }),

        // ──────────────────────────────────────────────────────────────────
        // 4. "+ ADD MAINTENANCE ITEM" BUTTON (restored)
        // ──────────────────────────────────────────────────────────────────
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onAddMaintenanceItem,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.clay,
              borderRadius: BorderRadius.circular(AppColors.radiusTile),
              boxShadow: AppColors.skeuRaisedSmall,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: AppColors.tacticalOrangeDark,
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '+ Add Maintenance Item',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.tacticalOrangeDark,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: AppColors.mutedText,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
