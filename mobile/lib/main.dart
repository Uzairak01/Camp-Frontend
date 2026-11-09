import 'dart:async';
import 'package:flutter/material.dart';
import 'app/routes.dart';
import 'app/theme/app_theme.dart';
import 'core/data/app_repositories.dart';
import 'core/widgets/app_messenger.dart';
import 'features/auth/controllers/auth_controller.dart';
import 'features/auth/presentation/screens/forgot_password_screen.dart';
import 'features/auth/presentation/screens/sign_in_screen.dart';
import 'features/auth/presentation/screens/sign_up_screen.dart';
import 'features/bike_scan/presentation/screens/add_motorcycle_screen.dart';
import 'features/bike_scan/presentation/screens/bike_details_screen.dart';
import 'features/bike_scan/presentation/screens/bike_scan_screen.dart';
import 'features/dashboard/controllers/profile_controller.dart';
import 'features/dashboard/presentation/screens/edit_profile_screen.dart';
import 'features/dashboard/presentation/screens/home_screen.dart';
import 'features/dashboard/presentation/screens/profile_screen.dart';
import 'features/dashboard/presentation/screens/weather_detail_screen.dart';
import 'features/emergency_sos/presentation/screens/emergency_qr_screen.dart';
import 'features/emergency_sos/presentation/screens/emergency_sos_screen.dart';
import 'features/garage/controllers/active_bike_controller.dart';
import 'features/garage/presentation/screens/bike_profile_screen.dart';
import 'features/garage/presentation/screens/garage_screen.dart';
import 'features/maintenance/controllers/post_ride_report_controller.dart';
import 'features/maintenance/controllers/service_visit_controller.dart';
import 'features/maintenance/controllers/trip_budget_controller.dart';
import 'features/maintenance/presentation/screens/finance_rig_health_screen.dart';
import 'features/maintenance/presentation/screens/maintenance_screen.dart';
import 'features/maintenance/presentation/screens/post_ride_debrief_screen.dart';
import 'features/maintenance/presentation/screens/service_schedule_screen.dart';
import 'features/mechanics/controllers/mechanic_controller.dart';
import 'features/mechanics/domain/mechanic_model.dart';
import 'features/mechanics/presentation/screens/add_mechanic_screen.dart';
import 'features/mechanics/presentation/screens/mechanics_home_screen.dart';
import 'features/navigation/controllers/current_place_controller.dart';
import 'features/navigation/domain/geocoding_service.dart';
import 'features/navigation/presentation/screens/navigation_map_screen.dart';
import 'features/navigation/presentation/screens/route_packs_screen.dart';
import 'features/ride_history/presentation/screens/ride_history_screen.dart';
import 'features/settings/controllers/settings_controller.dart';
import 'features/settings/presentation/screens/settings_screen.dart';
import 'features/settings/presentation/screens/tracking_diagnostics_screen.dart';
import 'features/voice_copilot/presentation/screens/voice_assistant_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final repos = AppRepositories.instance;
    await repos.init();
    try {
      await ActiveBikeController.instance.load(repos.bikeRepository);
    } catch (_) {}
    try {
      await SettingsController.instance.load(repos.settingsRepository);
    } catch (_) {}
    try {
      await PostRideReportController.instance.load(repos.rideReportRepository);
    } catch (_) {}
    try {
      await TripBudgetController.instance.load(repos.financeRepository);
    } catch (_) {}
    try {
      await ProfileController.instance.load(repos.profileRepository);
    } catch (_) {}
    try {
      await MechanicController.instance.load(repos.mechanicRepository);
    } catch (_) {}
    try {
      await ServiceVisitController.instance.load(repos.serviceVisitRepository);
    } catch (_) {}
    try {
      await AuthController.instance.load(repos.accountRepository);
    } catch (_) {}
    try {
      await CurrentPlaceController.instance.initialize();
    } catch (_) {}
    try {
      if (await repos.bikeRepository.isFirstRun()) {
        await repos.bikeRepository.markFirstRunCompleted();
      }
    } catch (_) {}
  } catch (_) {
    // If storage system initialization fails, app gracefully proceeds with in-memory defaults
  }
  runApp(const CampApp());
}

class CampApp extends StatefulWidget {
  const CampApp({super.key});

  @override
  State<CampApp> createState() => _CampAppState();
}

class _CampAppState extends State<CampApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      unawaited(AppRepositories.instance.flush());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CAMP',
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AuthController.instance.isAuthenticated
          ? CampRoutes.home
          : CampRoutes.signIn,
      routes: {
        CampRoutes.home: (context) => const HomeScreen(),
        CampRoutes.signIn: (context) => const SignInScreen(),
        CampRoutes.signUp: (context) => const SignUpScreen(),
        CampRoutes.forgotPassword: (context) => const ForgotPasswordScreen(),
        CampRoutes.addBike: (context) => const AddMotorcycleScreen(),
        CampRoutes.bikeDetails: (context) => const BikeDetailsScreen(),
        CampRoutes.bikeScan: (context) => const BikeScanScreen(),
        CampRoutes.bikeProfile: (context) => const BikeProfileScreen(),
        CampRoutes.garage: (context) => const GarageScreen(),
        CampRoutes.profile: (context) => const ProfileScreen(),
        CampRoutes.editProfile: (context) => const EditProfileScreen(),
        CampRoutes.mechanics: (context) => const MechanicsHomeScreen(),
        CampRoutes.addMechanic: (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          return AddMechanicScreen(mechanic: args is Mechanic ? args : null);
        },
        CampRoutes.navigationMap: (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          return NavigationMapScreen(
            initialDestination: args is PlaceSearchResult ? args : null,
          );
        },
        CampRoutes.voiceCopilot: (context) => const VoiceAssistantScreen(),
        CampRoutes.routePacks: (context) => const RoutePacksScreen(),
        CampRoutes.rideHistory: (context) => const RideHistoryScreen(),
        CampRoutes.financeRigHealth: (context) => const FinanceRigHealthScreen(),
        CampRoutes.maintenance: (context) => const MaintenanceScreen(),
        CampRoutes.serviceSchedule: (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          return ServiceScheduleScreen(bikeId: args is String ? args : null);
        },
        CampRoutes.predictiveMaintenance: (context) =>
            const MaintenanceScreen(initialTab: MaintenanceTab.diagnostics),
        CampRoutes.carburetorTuning: (context) =>
            const MaintenanceScreen(initialTab: MaintenanceTab.carburetor),
        CampRoutes.postRideDebrief: (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          return PostRideDebriefScreen(bikeId: args is String ? args : null);
        },
        CampRoutes.settings: (context) => const SettingsScreen(),
        CampRoutes.emergencySos: (context) => const EmergencySosScreen(),
        CampRoutes.emergencyQr: (context) => const EmergencyQrScreen(),
        CampRoutes.weatherDetail: (context) => const WeatherDetailScreen(),
        CampRoutes.trackingDiagnostics: (context) =>
            const TrackingDiagnosticsScreen(),
      },
      onUnknownRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (context) => const HomeScreen(),
      ),
    );
  }
}
