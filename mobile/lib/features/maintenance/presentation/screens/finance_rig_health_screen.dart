import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../dashboard/presentation/widgets/app_drawer_widget.dart';
import '../../../garage/controllers/active_bike_controller.dart';
import '../../controllers/maintenance_controller.dart';
import '../../controllers/service_visit_controller.dart';
import '../../controllers/trip_budget_controller.dart';
import '../../domain/expense_model.dart';
import '../../domain/maintenance_item_model.dart';
import '../../domain/trip_budget_model.dart';
import '../../services/pdf_report_service.dart';
import '../widgets/download_report_card_widget.dart';
import '../widgets/hero_photo_widget.dart';
import '../widgets/maintenance_list_widget.dart';
import '../widgets/service_visit_card_widget.dart';
import '../widgets/trip_budget_card_widget.dart';
import 'add_expense_screen.dart';
import 'add_maintenance_item_screen.dart';
import 'edit_trip_budget_screen.dart';
import 'service_schedule_screen.dart';

/// CAMP Finances & Rig Health Screen (Main Expedition Cockpit Feature Slice)
/// Displays expedition telemetry, trip budget & fuel economics, maintenance schedule,
/// pitstop bookings, and PDF report downloads.
class FinanceRigHealthScreen extends StatefulWidget {
  const FinanceRigHealthScreen({super.key});

  @override
  State<FinanceRigHealthScreen> createState() => _FinanceRigHealthScreenState();
}

class _FinanceRigHealthScreenState extends State<FinanceRigHealthScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ── Notifications ─────────────────────────────────────────────────────────

  void _showNotification(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.darkCharcoal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(milliseconds: 2000),
      ),
    );
  }

  // ── Navigation helpers ────────────────────────────────────────────────────

  Future<void> _pushEditTripBudget() async {
    final result = await Navigator.of(context).push<TripBudget>(
      MaterialPageRoute(
        builder: (context) => EditTripBudgetScreen(
          initialBudget: TripBudgetController.instance.budget,
        ),
      ),
    );
    if (result != null && mounted) {
      TripBudgetController.instance.setBudget(result);
      _showNotification('Budget updated for ${result.tripName}');
    }
  }

  Future<void> _pushAddExpense() async {
    final result = await Navigator.of(context).push<Expense>(
      MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
    );
    if (result != null && mounted) {
      if (!TripBudgetController.instance.expenses.any((e) => e.id == result.id)) {
        TripBudgetController.instance.addExpense(result);
      }
      _showNotification('Added ${result.title} (${formatPkr(result.amount)})');
    }
  }

  // ── Rider-added maintenance item handlers (restored) ─────────────────────

  Future<void> _pushAddMaintenanceItem() async {
    final result = await Navigator.of(context).push<MaintenanceItem>(
      MaterialPageRoute(builder: (context) => const AddMaintenanceItemScreen()),
    );
    if (result != null && mounted) {
      await MaintenanceController.instance.addMaintenanceItem(result, context);
      _showNotification('Added ${result.name} to maintenance list');
    }
  }

  void _handleDeleteTrip() {
    TripBudgetController.instance.deleteTrip();
    _showNotification('Trip deleted. Maintenance records preserved.');
  }

  void _showMaintenanceItemActions(MaintenanceItem item) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.clay,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: AppColors.skeuRaised,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.clayDark,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                IconTile(
                  icon: item.icon ?? Icons.build_circle_rounded,
                  size: 36,
                  iconSize: 18,
                  isInset: true,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                      Text(
                        item.statusValueDisplay ?? item.status.name.toUpperCase(),
                        style: GoogleFonts.manrope(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppColors.darkCharcoal),
              title: Text(
                'Edit Maintenance Item',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkCharcoal,
                ),
              ),
              onTap: () async {
                Navigator.of(ctx).pop();
                final updated = await Navigator.of(context).push<MaintenanceItem>(
                  MaterialPageRoute(
                    builder: (context) => AddMaintenanceItemScreen(initialItem: item),
                  ),
                );
                if (updated != null && mounted) {
                  await MaintenanceController.instance.updateMaintenanceItem(updated, context);
                  _showNotification('Updated ${updated.name}');
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.alertRed),
              title: Text(
                'Delete Item',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.alertRed,
                ),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _confirmDeleteMaintenanceItem(item);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteMaintenanceItem(MaintenanceItem item) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.clay,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Maintenance Item?',
          style: GoogleFonts.manrope(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.darkCharcoal,
          ),
        ),
        content: Text(
          'Are you sure you want to remove ${item.name} from the maintenance list?',
          style: AppTextStyles.bodySecondary.copyWith(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                color: AppColors.mutedText,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alertRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop(true);
              _handleDismissMaintenanceItem(item);
            },
            child: Text(
              'Delete',
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

  void _handleDismissMaintenanceItem(MaintenanceItem item) {
    final removedIndex = MaintenanceController.instance.maintenanceItems.indexOf(item);
    Expense? linkedExpense;
    int? linkedExpenseIndex;
    if (item.expenseId != null) {
      linkedExpenseIndex = TripBudgetController.instance.expenses
          .indexWhere((e) => e.id == item.expenseId);
      if (linkedExpenseIndex != -1) {
        linkedExpense = TripBudgetController.instance.expenses[linkedExpenseIndex];
      }
    }

    MaintenanceController.instance.deleteMaintenanceItem(item.id, context);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted ${item.name}'),
        backgroundColor: AppColors.darkCharcoal,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppColors.tacticalOrange,
          onPressed: () {
            if (!mounted) return;
            MaintenanceController.instance.insertMaintenanceItem(
              removedIndex,
              item,
              context,
            );

            if (linkedExpense != null) {
              TripBudgetController.instance.insertExpense(
                linkedExpenseIndex ?? 0,
                linkedExpense,
              );
            }
          },
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        key: _scaffoldKey,
        drawer: const AppDrawerWidget(),
        backgroundColor: AppColors.clay,
        body: Stack(
          children: [
            // ── Scrollable Body ────────────────────────────────────────────
            SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppColors.screenPadding,
                  8.0,
                  AppColors.screenPadding,
                  110.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. App Bar with Menu and actionText pill
                    CampAppBar(
                      leading: CampAppBarLeading.menu,
                      onLeadingPressed: () =>
                          _scaffoldKey.currentState?.openDrawer(),
                      actionText: 'FINANCES & RIG HEALTH',
                      onActionPressed: () =>
                          _showNotification('Finances & Rig Health active'),
                    ),

                    const SizedBox(height: 14),

                    // 2. Section Header Block: EXPEDITION STATS + Title + LOCAL pill
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('EXPEDITION STATS', style: AppTextStyles.overline),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                'Finances & Rig Health',
                                style: AppTextStyles.title,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.clayDark,
                                borderRadius: BorderRadius.circular(
                                  AppColors.radiusPill,
                                ),
                                boxShadow: AppColors.skeuRaisedSmall,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.sync_rounded,
                                    size: 13,
                                    color: AppColors.statusGreen,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'LOCAL',
                                    style: GoogleFonts.manrope(
                                      color: AppColors.darkCharcoal,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // 3. Hero Photo Widget (Active Rig + masked VIN)
                    ListenableBuilder(
                      listenable: ActiveBikeController.instance,
                      builder: (context, _) {
                        final bike = ActiveBikeController.instance.activeBike;
                        return HeroPhotoWidget(
                          bikeName: bike != null
                              ? '🏍 ${bike.make} ${bike.modelName}'
                              : '🏍 No Active Motorcycle',
                          vinSnippet: bike != null &&
                                  bike.vin != null &&
                                  bike.vin!.isNotEmpty
                              ? 'VIN ••${bike.vin!.substring(bike.vin!.length >= 4 ? bike.vin!.length - 4 : 0)}'
                              : 'GARAGE FLEET',
                          imagePath: (bike?.imagePath != null &&
                                  bike!.imagePath!.isNotEmpty)
                              ? bike.imagePath!
                              : 'assets/images/bmw_r1250_scan_placeholder.jpg',
                        );
                      },
                    ),

                    const SizedBox(height: AppColors.cardGap),

                    // 4. Trip Budget & Fuel Economics Card
                    ListenableBuilder(
                      listenable: TripBudgetController.instance,
                      builder: (context, _) => TripBudgetCardWidget(
                        tripBudget: TripBudgetController.instance.budget,
                        expenses: TripBudgetController.instance.expenses,
                        onEditTrip: _pushEditTripBudget,
                        onDeleteTrip: _handleDeleteTrip,
                        onAddExpense: _pushAddExpense,
                      ),
                    ),

                    const SizedBox(height: AppColors.cardGap),

                    // 5. Upcoming & Required Maintenance (schedule-driven due items +
                    //    Configure Schedule row + rider-added items + Add button)
                    ListenableBuilder(
                      listenable: Listenable.merge([
                        MaintenanceController.instance,
                        ActiveBikeController.instance,
                      ]),
                      builder: (context, _) {
                        final bike = ActiveBikeController.instance.activeBike;
                        final hasSchedule = MaintenanceController.instance
                            .hasMaintenanceData(bike);
                        final due = MaintenanceController.instance
                            .dueItems(bike?.id);

                        return MaintenanceListWidget(
                          // Schedule-driven
                          dueItems: due,
                          hasSchedule: hasSchedule,
                          onSetUpSchedule: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  ServiceScheduleScreen(bikeId: bike?.id),
                            ),
                          ),
                          onScheduleItemTapped: (item) =>
                              Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ServiceScheduleScreen(
                                bikeId: bike?.id,
                                focusItemType: item.type,
                              ),
                            ),
                          ),
                          // Rider-added (restored)
                          items: MaintenanceController.instance.maintenanceItems,
                          onAddMaintenanceItem: _pushAddMaintenanceItem,
                          onItemTapped: _showMaintenanceItemActions,
                          onItemDismissed: _handleDismissMaintenanceItem,
                        );
                      },
                    ),

                    const SizedBox(height: AppColors.cardGap),

                    // 6. Download Maintenance Report Card
                    DownloadReportCardWidget(
                      label: 'Download Maintenance Report (PDF)',
                      subtitle: 'Receipts, service logs & schedule',
                      onTap: () {
                        final activeBike =
                            ActiveBikeController.instance.activeBike;
                        final bikeName = activeBike != null
                            ? '${activeBike.make} ${activeBike.modelName}'
                            : 'Motorcycle Fleet';
                        final odo = activeBike?.odometerKm;

                        PdfReportService.shareMaintenanceReport(
                          context,
                          MaintenanceReportData(
                            bikeName: bikeName,
                            bikeId: activeBike?.id,
                            odometerKm: odo,
                            items: MaintenanceController.instance.maintenanceItems,
                            visits: ServiceVisitController.instance.visits,
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: AppColors.cardGap),

                    // 7. Next Service Visit Card
                    ListenableBuilder(
                      listenable: ServiceVisitController.instance,
                      builder: (context, _) => const ServiceVisitCardWidget(),
                    ),
                  ],
                ),
              ),
            ),

            // 8. Floating Tactical Bottom Dock
            const Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Center(
                child: CampBottomNav(
                  selected: CampTab.finances,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
