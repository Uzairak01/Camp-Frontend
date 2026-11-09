import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/widgets.dart';
import '../../controllers/service_visit_controller.dart';
import '../../domain/service_visit_model.dart';
import 'mark_service_visit_done_sheet.dart';
import 'plan_service_visit_sheet.dart';

/// Next Service Visit card showing either empty state ("Plan a visit")
/// or the scheduled appointment details with dynamic Call / Directions actions.
class ServiceVisitCardWidget extends StatelessWidget {
  const ServiceVisitCardWidget({
    super.key,
    this.visit,
    this.onPlanVisit,
    this.onEditVisit,
    this.onDeleteVisit,
    this.onMarkDone,
    this.onCallShop,
    this.onDirections,
  });

  final ServiceVisit? visit;
  final VoidCallback? onPlanVisit;
  final ValueChanged<ServiceVisit>? onEditVisit;
  final ValueChanged<ServiceVisit>? onDeleteVisit;
  final ValueChanged<ServiceVisit>? onMarkDone;
  final ValueChanged<ServiceVisit>? onCallShop;
  final ValueChanged<ServiceVisit>? onDirections;

  void _confirmDelete(BuildContext context, ServiceVisit v,
      {bool isPast = false}) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.clay,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isPast ? 'Delete Service Visit?' : 'Cancel Service Visit?',
          style: GoogleFonts.manrope(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.darkCharcoal,
          ),
        ),
        content: Text(
          isPast
              ? 'Are you sure you want to delete the service visit to ${v.shopName}?'
              : 'Are you sure you want to cancel the scheduled visit to ${v.shopName}?',
          style: AppTextStyles.bodySecondary.copyWith(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Keep Visit',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                color: AppColors.mutedText,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alertRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop(true);
              final removedIndex =
                  ServiceVisitController.instance.visits.indexOf(v);
              if (onDeleteVisit != null) {
                onDeleteVisit!(v);
              } else {
                try {
                  await ServiceVisitController.instance
                      .deleteVisit(v.id, context);
                } catch (_) {
                  return;
                }
              }
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isPast
                      ? 'Deleted service visit to ${v.shopName}'
                      : 'Cancelled service visit to ${v.shopName}'),
                  backgroundColor: AppColors.darkCharcoal,
                  behavior: SnackBarBehavior.floating,
                  action: SnackBarAction(
                    label: 'Undo',
                    textColor: AppColors.tacticalOrange,
                    onPressed: () {
                      ServiceVisitController.instance.insertVisit(
                        removedIndex >= 0 ? removedIndex : 0,
                        v,
                      );
                    },
                  ),
                ),
              );
            },
            child: Text(
              isPast ? 'Delete Visit' : 'Cancel Visit',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ServiceVisitController.instance,
      builder: (context, _) {
        final effectiveVisit =
            visit ?? ServiceVisitController.instance.nextPlannedVisit;

        if (effectiveVisit == null) {
          return CampCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'NEXT SERVICE VISIT',
                      style: AppTextStyles.overline,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: const BoxDecoration(
                          color: AppColors.clayDark,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.event_note_rounded,
                          size: 26,
                          color: AppColors.mutedText,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'No service visit planned',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Keep your machine trail-ready by scheduling upcoming shop time.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 12,
                          color: AppColors.mutedText,
                        ),
                      ),
                      const SizedBox(height: 14),
                      PrimaryButton(
                        label: 'Plan a visit',
                        onTap: onPlanVisit ??
                            () => PlanServiceVisitSheet.show(context),
                      ),
                    ],
                  ),
                ),
                if (ServiceVisitController.instance.pastVisits.isNotEmpty)
                  _buildPastVisitsSection(
                      context, ServiceVisitController.instance.pastVisits),
              ],
            ),
          );
        }

        final hasPhone = effectiveVisit.hasPhone;
        final hasCoords = effectiveVisit.hasCoordinates;
        final showActionRow = hasPhone || hasCoords;

        return CampCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header: Overline + Planned Status Chip + 3-dot Menu ───────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'NEXT SERVICE VISIT',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.overline,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BikeLabelChip(bikeId: effectiveVisit.bikeId),
                      const SizedBox(width: 6),
                      const StatusChip(
                        label: 'Planned',
                        variant: StatusChipVariant.gold,
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      ),
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          size: 18,
                          color: AppColors.mutedText,
                        ),
                        color: AppColors.clay,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (val) {
                          if (val == 'mark_done') {
                            if (onMarkDone != null) {
                              onMarkDone!(effectiveVisit);
                            } else {
                              MarkServiceVisitDoneSheet.show(
                                context,
                                visit: effectiveVisit,
                              );
                            }
                          } else if (val == 'edit') {
                            if (onEditVisit != null) {
                              onEditVisit!(effectiveVisit);
                            } else {
                              PlanServiceVisitSheet.show(
                                context,
                                initialVisit: effectiveVisit,
                              );
                            }
                          } else if (val == 'delete') {
                            _confirmDelete(context, effectiveVisit);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'mark_done',
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline,
                                    size: 16,
                                    color: AppColors.tacticalOrange),
                                const SizedBox(width: 8),
                                Text(
                                  'Mark done',
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.darkCharcoal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                const Icon(Icons.edit_outlined,
                                    size: 16, color: AppColors.darkCharcoal),
                                const SizedBox(width: 8),
                                Text(
                                  'Edit Visit',
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.darkCharcoal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(Icons.delete_outline,
                                    size: 16, color: AppColors.alertRed),
                                const SizedBox(width: 8),
                                Text(
                                  'Cancel Visit',
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.alertRed,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Date, Time & Shop Name Row ────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const IconTile(
                    icon: Icons.calendar_today_rounded,
                    size: 42,
                    iconSize: 20,
                    isInset: true,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          effectiveVisit.formattedDateTime,
                          style: AppTextStyles.cardTitle.copyWith(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          effectiveVisit.shopName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkCharcoal,
                          ),
                        ),
                        if (effectiveVisit.note != null &&
                            effectiveVisit.note!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.clayDark,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              effectiveVisit.note!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: 11.5,
                                color: AppColors.darkCharcoal,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              // ── Action Buttons Row (Hidden if neither phone nor coords) ────────
              if (showActionRow) ...[
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (hasPhone)
                      Expanded(
                        child: Center(
                          child: GhostButton(
                            label: '📞 Call Shop',
                            color: AppColors.darkCharcoal,
                            onTap: () {
                              if (onCallShop != null) {
                                onCallShop!(effectiveVisit);
                              } else {
                                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Dialing ${effectiveVisit.phone}...',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    backgroundColor: AppColors.darkCharcoal,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    if (hasPhone && hasCoords)
                      Container(
                        height: 20,
                        width: 1,
                        color: Colors.black.withValues(alpha: 0.1),
                      ),
                    if (hasCoords)
                      Expanded(
                        child: Center(
                          child: GhostButton(
                            label: '🗺 Directions',
                            color: AppColors.tacticalOrangeDark,
                            onTap: () {
                              if (onDirections != null) {
                                onDirections!(effectiveVisit);
                              } else {
                                Navigator.of(context)
                                    .pushNamed(CampRoutes.navigationMap);
                              }
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (ServiceVisitController.instance.pastVisits.isNotEmpty)
                _buildPastVisitsSection(
                    context, ServiceVisitController.instance.pastVisits),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPastVisitsSection(
      BuildContext context, List<ServiceVisit> pastVisits) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        const Divider(height: 1),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('PAST SERVICE VISITS', style: AppTextStyles.overline),
            Text(
              '${pastVisits.length} recorded',
              style: AppTextStyles.caption.copyWith(fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...pastVisits.map((pv) => _buildPastVisitItem(context, pv)),
      ],
    );
  }

  Widget _buildPastVisitItem(BuildContext context, ServiceVisit pv) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.clayDark,
        borderRadius: BorderRadius.circular(AppColors.radiusTile),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.history_rounded,
            size: 16,
            color: AppColors.mutedText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        pv.shopName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                    ),
                    BikeLabelChip(bikeId: pv.bikeId),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      pv.formattedDateTime,
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                    ),
                    if (pv.isDone) ...[
                      if (pv.cost != null && pv.cost! > 0) ...[
                        const SizedBox(width: 6),
                        Text('•',
                            style:
                                AppTextStyles.caption.copyWith(fontSize: 11)),
                        const SizedBox(width: 6),
                        Text(
                          formatPkr(pv.cost!),
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.tacticalOrangeDark,
                          ),
                        ),
                      ],
                    ] else ...[
                      const SizedBox(width: 6),
                      Text('•',
                          style:
                              AppTextStyles.caption.copyWith(fontSize: 11)),
                      const SizedBox(width: 6),
                      Text(
                        'Not marked done',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              size: 16,
              color: AppColors.mutedText,
            ),
            color: AppColors.clay,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (val) {
              if (val == 'mark_done') {
                if (onMarkDone != null) {
                  onMarkDone!(pv);
                } else {
                  MarkServiceVisitDoneSheet.show(context, visit: pv);
                }
              } else if (val == 'edit') {
                if (onEditVisit != null) {
                  onEditVisit!(pv);
                } else {
                  PlanServiceVisitSheet.show(
                    context,
                    initialVisit: pv,
                  );
                }
              } else if (val == 'delete') {
                _confirmDelete(context, pv, isPast: true);
              }
            },
            itemBuilder: (context) => [
              if (!pv.isDone)
                PopupMenuItem(
                  value: 'mark_done',
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          size: 16, color: AppColors.tacticalOrange),
                      const SizedBox(width: 8),
                      Text(
                        'Mark done',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    const Icon(Icons.edit_outlined,
                        size: 16, color: AppColors.darkCharcoal),
                    const SizedBox(width: 8),
                    Text(
                      'Edit Visit',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkCharcoal,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline,
                        size: 16, color: AppColors.alertRed),
                    const SizedBox(width: 8),
                    Text(
                      'Delete Visit',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.alertRed,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
