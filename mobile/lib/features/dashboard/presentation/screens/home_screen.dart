import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/data/app_repositories.dart';
import '../../../../core/widgets/camp_bottom_nav.dart';
import '../../../garage/controllers/active_bike_controller.dart';
import '../../../garage/services/fuel_tracker_service.dart';
import '../../../maintenance/controllers/maintenance_controller.dart';
import '../../../settings/controllers/settings_controller.dart';
import '../widgets/active_bike_card_widget.dart';
import '../widgets/app_drawer_widget.dart';
import '../widgets/app_header_widget.dart';
import '../widgets/cockpit_status_card_widget.dart';
import '../widgets/group_beacon_card_widget.dart';
import '../widgets/home_weather_card_widget.dart';
import '../widgets/maintenance_alert_card_widget.dart';
import '../widgets/recent_updates_feed_widget.dart';
import '../widgets/unfinished_ride_recovery_sheet.dart';
import '../widgets/voice_copilot_bar_widget.dart';

/// CAMP Explore Home / Dashboard Screen
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUnfinishedRide();
    });
  }

  /// Checks for an unfinished ride persisted from a prior session (crash/kill recovery).
  /// Returns early if a ride is currently active in memory so returning to Home mid-ride
  /// does not falsely show the recovery sheet.
  Future<void> _checkUnfinishedRide() async {
    if (FuelTrackerService.instance.isRiding) return;
    final savedRide = await AppRepositories
        .instance.inProgressRideRepository
        .loadInProgressRide();
    if (savedRide != null &&
        mounted &&
        !FuelTrackerService.instance.isRiding) {
      await UnfinishedRideRecoverySheet.show(context, savedRide);
    }
  }

  void _showNotification(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.darkCharcoal,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(milliseconds: 2000),
      ),
    );
  }


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
            // Scrollable Content
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
                    // 1. App Header
                    AppHeaderWidget(
                      onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
                      onBadgePressed: () => _showNotification('Explore mode active'),
                    ),

                    const SizedBox(height: 14),

                    // 2. Cockpit Status Card (Hero)
                    CockpitStatusCardWidget(
                      onProfilePressed: () => Navigator.of(context).pushNamed(CampRoutes.profile),
                      onCtaPressed: () => Navigator.of(context).pushNamed(CampRoutes.navigationMap),
                    ),

                    const SizedBox(height: AppColors.cardGap),

                    // 3. Voice Copilot Input Bar
                    VoiceCopilotBarWidget(
                      onVoicePressed: () => Navigator.of(context).pushNamed(CampRoutes.voiceCopilot),
                      onAiPressed: () => Navigator.of(context).pushNamed(CampRoutes.voiceCopilot),
                      onSubmitted: (query) {
                        Navigator.of(context).pushNamed(CampRoutes.voiceCopilot);
                      },
                    ),

                    const SizedBox(height: AppColors.cardGap),

                    // 4. Maintenance Alert Card (dismissible with persistence)
                    ListenableBuilder(
                      listenable: Listenable.merge([
                        ActiveBikeController.instance,
                        MaintenanceController.instance,
                        SettingsController.instance,
                      ]),
                      builder: (context, _) {
                        final bike = ActiveBikeController.instance.activeBike;
                        final urgent = MaintenanceController.instance.mostUrgentItem(bike?.id);
                        final isDismissed = urgent != null &&
                            SettingsController.instance.isAlertDismissed(
                              urgent.item.id,
                              urgent.scheduleStatus.name,
                            );
                        if (isDismissed) {
                          return const SizedBox.shrink();
                        }
                        return Column(
                          children: [
                            MaintenanceAlertCardWidget(
                              onDismiss: urgent != null
                                  ? () {
                                      SettingsController.instance.dismissAlert(
                                        urgent.item.id,
                                        urgent.scheduleStatus.name,
                                      );
                                      _showNotification('Maintenance alert dismissed');
                                    }
                                  : null,
                            ),
                            const SizedBox(height: AppColors.cardGap),
                          ],
                        );
                      },
                    ),

                    // 5. Active Motorcycle Overview Card
                    ActiveBikeCardWidget(
                      onDetailsPressed: () => Navigator.of(context).pushNamed(CampRoutes.garage),
                    ),

                    const SizedBox(height: AppColors.cardGap),

                    // 6. Restored Weather Card (outside Recent activity)
                    const HomeWeatherCardWidget(),

                    const SizedBox(height: AppColors.cardGap),

                    // 7. Restored Group Beacon Card (outside Recent activity)
                    const GroupBeaconCardWidget(),

                    const SizedBox(height: AppColors.cardGap),

                    // 8. Recent Activity Feed
                    const RecentUpdatesFeedWidget(),
                  ],
                ),
              ),
            ),

            // 7. Tactical Bottom Dock (Floating)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Center(
                child: CampBottomNav(
                  selected: CampTab.home,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
