import 'package:flutter/material.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../garage/controllers/active_bike_controller.dart';
import '../../../maintenance/controllers/post_ride_report_controller.dart';
import '../../../maintenance/controllers/service_visit_controller.dart';
import '../../../maintenance/controllers/trip_budget_controller.dart';
import '../../../maintenance/domain/expense_model.dart';
import '../../../mechanics/controllers/mechanic_controller.dart';
import '../../../settings/controllers/settings_controller.dart';

/// Represents a single activity item derived strictly from user-logged records.
class RiderActivityItem {
  const RiderActivityItem({
    required this.id,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.icon,
    required this.iconColor,
    required this.route,
    this.routeArgs,
  });

  final String id;
  final String title;
  final String description;
  final DateTime timestamp;
  final IconData icon;
  final Color iconColor;
  final String route;
  final Object? routeArgs;
}

/// Recent Activity Feed — built strictly from real user logs:
/// refuels, expenses, maintenance done, rides, and bikes/mechanics added.
/// Sorted newest first, capped at ~5 entries. Free of seeded fake entries or claims.
class RecentUpdatesFeedWidget extends StatelessWidget {
  const RecentUpdatesFeedWidget({
    super.key,
    this.onViewRadar,
    this.onLocateBeacon,
    this.onMarkAllRead,
  });

  final VoidCallback? onViewRadar;
  final VoidCallback? onLocateBeacon;
  final VoidCallback? onMarkAllRead;

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inDays == 0 && now.day == dt.day) {
      return 'Today';
    } else if (difference.inDays <= 1 || (now.day - dt.day == 1 && difference.inDays < 2)) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final month = (dt.month >= 1 && dt.month <= 12) ? months[dt.month - 1] : '';
      return '$month ${dt.day}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        PostRideReportController.instance,
        TripBudgetController.instance,
        ServiceVisitController.instance,
        ActiveBikeController.instance,
        MechanicController.instance,
        SettingsController.instance,
      ]),
      builder: (context, _) {
        final List<RiderActivityItem> items = [];

        // 1. Post-ride reports
        for (final r in PostRideReportController.instance.reports) {
          items.add(
            RiderActivityItem(
              id: 'ride-${r.id}',
              title: 'Ride Logged • ${r.distanceKm.round()} km',
              description: r.terrainTags.isNotEmpty
                  ? 'Terrain: ${r.terrainTags.join(', ')}'
                  : (r.notes ?? 'Completed motorcycle ride'),
              timestamp: r.date,
              icon: Icons.route_rounded,
              iconColor: AppColors.statusGreen,
              route: CampRoutes.rideHistory,
            ),
          );
        }

        // 2. Expenses & Refuels
        for (final e in TripBudgetController.instance.expenses) {
          final isFuel = e.category == ExpenseCategory.fuel;
          final dt = e.dateRecorded ?? e.createdAt ?? DateTime.now();
          items.add(
            RiderActivityItem(
              id: 'expense-${e.id}',
              title: isFuel ? 'Fuel Refill' : e.title,
              description: '${formatPkr(e.amount)} • ${isFuel ? 'Fuel' : e.category.displayName}',
              timestamp: dt,
              icon: isFuel
                  ? Icons.local_gas_station_rounded
                  : Icons.receipt_long_rounded,
              iconColor: isFuel
                  ? AppColors.tacticalOrange
                  : const Color(0xFF6366F1),
              route: CampRoutes.financeRigHealth,
            ),
          );
        }

        // 3. Maintenance visits
        for (final v in ServiceVisitController.instance.visits) {
          items.add(
            RiderActivityItem(
              id: 'service-${v.id}',
              title: 'Service • ${v.shopName}',
              description: v.note ?? 'Scheduled maintenance visit',
              timestamp: v.dateTime,
              icon: Icons.build_circle_rounded,
              iconColor: AppColors.terracotta,
              route: CampRoutes.financeRigHealth,
            ),
          );
        }

        // 4. Bikes added
        for (final b in ActiveBikeController.instance.bikes) {
          final ts = b.createdAt ?? b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          items.add(
            RiderActivityItem(
              id: 'bike-${b.id}',
              title: 'Motorcycle Added • ${b.name}',
              description: '${b.odometerKm} km logged',
              timestamp: ts,
              icon: Icons.two_wheeler_rounded,
              iconColor: AppColors.tacticalOrange,
              route: CampRoutes.garage,
            ),
          );
        }

        // 5. Mechanics added
        for (final m in MechanicController.instance.mechanics) {
          final ts = m.createdAt ?? m.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final location = m.durationOrLocation.isNotEmpty
              ? m.durationOrLocation
              : (m.address ?? 'Field workshop');
          items.add(
            RiderActivityItem(
              id: 'mechanic-${m.id}',
              title: 'Mechanic • ${m.name}',
              description: location,
              timestamp: ts,
              icon: Icons.handyman_rounded,
              iconColor: const Color(0xFF0D9488),
              route: CampRoutes.mechanics,
            ),
          );
        }

        // Filter out items older than clearedAt (Clear button timestamp)
        final clearedAt = SettingsController.instance.recentActivityClearedAt;
        final activeItems = clearedAt == null
            ? items
            : items.where((i) => i.timestamp.isAfter(clearedAt)).toList();

        // Sort newest first
        activeItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        final recentItems = activeItems.take(5).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section Header with Clear button ──
            SectionHeader(
              title: 'Recent activity',
              actionLabel: recentItems.isNotEmpty ? 'Clear' : null,
              onAction: recentItems.isNotEmpty ? () => _confirmClear(context) : null,
            ),

            if (recentItems.isEmpty)
              CampCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.history_rounded,
                        size: 32,
                        color: AppColors.mutedText,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No recent activity yet',
                        style: AppTextStyles.itemTitle.copyWith(
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your rides, refills, expenses, and maintenance logs will appear here.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...recentItems.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: CampCard(
                      borderRadius: AppColors.radiusTile + 2,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pushNamed(
                          item.route,
                          arguments: item.routeArgs,
                        ),
                        borderRadius: BorderRadius.circular(AppColors.radiusTile + 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            IconTile(
                              icon: item.icon,
                              iconColor: item.iconColor,
                              size: 42,
                              borderRadius: 14,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          item.title,
                                          style: AppTextStyles.itemTitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatTimestamp(item.timestamp),
                                        style: AppTextStyles.caption,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    item.description,
                                    style: AppTextStyles.bodySecondary,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.mutedLight,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )),
          ],
        );
      },
    );
  }

  void _confirmClear(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.clay,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusTile + 4),
        ),
        title: Text(
          'Clear recent activity?',
          style: AppTextStyles.itemTitle.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.darkCharcoal,
          ),
        ),
        content: Text(
          'This hides previous activity from your Home feed. Your logged rides, fuel entries, expenses, and maintenance logs will remain safely saved in your records.',
          style: AppTextStyles.bodySecondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: AppTextStyles.itemTitle.copyWith(
                fontSize: 14,
                color: AppColors.mutedText,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alertRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusTile),
              ),
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              SettingsController.instance.clearRecentActivity();
            },
            child: Text(
              'Clear',
              style: AppTextStyles.itemTitle.copyWith(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}