import '../storage/local_store.dart';
import 'account_repository.dart';
import 'account_repository_local.dart';
import 'bike_repository.dart';
import 'bike_repository_local.dart';
import 'finance_repository.dart';
import 'finance_repository_local.dart';
import 'in_progress_ride_repository.dart';
import 'in_progress_ride_repository_local.dart';
import 'last_known_place_repository.dart';
import 'last_known_place_repository_local.dart';
import 'maintenance_repository.dart';
import 'maintenance_repository_local.dart';
import 'mechanic_repository.dart';
import 'mechanic_repository_local.dart';
import 'place_repository.dart';
import 'place_repository_local.dart';
import 'profile_repository.dart';
import 'profile_repository_local.dart';
import 'ride_report_repository.dart';
import 'ride_report_repository_local.dart';
import 'service_visit_repository.dart';
import 'service_visit_repository_local.dart';
import 'session_repository.dart';
import 'session_repository_local.dart';
import 'settings_repository.dart';
import 'settings_repository_local.dart';
import 'voice_chat_repository.dart';
import 'voice_chat_repository_local.dart';

/// Central container for all app repositories.
/// Built in [main.dart] using local repositories, and swappable for tests.
class AppRepositories {
  AppRepositories({
    AccountRepository? accountRepository,
    ProfileRepository? profileRepository,
    BikeRepository? bikeRepository,
    MechanicRepository? mechanicRepository,
    RideReportRepository? rideReportRepository,
    SettingsRepository? settingsRepository,
    MaintenanceRepository? maintenanceRepository,
    FinanceRepository? financeRepository,
    PlaceRepository? placeRepository,
    ServiceVisitRepository? serviceVisitRepository,
    SessionRepository? sessionRepository,
    VoiceChatRepository? voiceChatRepository,
    LastKnownPlaceRepository? lastKnownPlaceRepository,
    InProgressRideRepository? inProgressRideRepository,
  })  : accountRepository = accountRepository ?? AccountRepositoryLocal(),
        profileRepository = profileRepository ?? ProfileRepositoryLocal(),
        bikeRepository = bikeRepository ?? BikeRepositoryLocal(),
        mechanicRepository = mechanicRepository ?? MechanicRepositoryLocal(),
        rideReportRepository = rideReportRepository ?? RideReportRepositoryLocal(),
        settingsRepository = settingsRepository ?? SettingsRepositoryLocal(),
        maintenanceRepository = maintenanceRepository ?? MaintenanceRepositoryLocal(),
        financeRepository = financeRepository ?? FinanceRepositoryLocal(),
        placeRepository = placeRepository ?? PlaceRepositoryLocal(),
        serviceVisitRepository = serviceVisitRepository ?? ServiceVisitRepositoryLocal(),
        sessionRepository = sessionRepository ?? SessionRepositoryLocal(),
        voiceChatRepository = voiceChatRepository ?? VoiceChatRepositoryLocal(),
        lastKnownPlaceRepository = lastKnownPlaceRepository ?? LastKnownPlaceRepositoryLocal(),
        inProgressRideRepository = inProgressRideRepository ?? InProgressRideRepositoryLocal();

  static AppRepositories instance = AppRepositories();

  final AccountRepository accountRepository;
  final ProfileRepository profileRepository;
  final BikeRepository bikeRepository;
  final MechanicRepository mechanicRepository;
  final RideReportRepository rideReportRepository;
  final SettingsRepository settingsRepository;
  final MaintenanceRepository maintenanceRepository;
  final FinanceRepository financeRepository;
  final PlaceRepository placeRepository;
  final ServiceVisitRepository serviceVisitRepository;
  final SessionRepository sessionRepository;
  final VoiceChatRepository voiceChatRepository;
  final LastKnownPlaceRepository lastKnownPlaceRepository;
  final InProgressRideRepository inProgressRideRepository;

  /// Initialize persistent storage backing the repositories.
  Future<void> init() async {
    await LocalStore.instance.init();
  }

  /// Flush pending writes to disk across all repositories.
  Future<void> flush() async {
    await LocalStore.instance.flush();
  }

  static void resetWith({
    AccountRepository? accountRepository,
    ProfileRepository? profileRepository,
    BikeRepository? bikeRepository,
    MechanicRepository? mechanicRepository,
    RideReportRepository? rideReportRepository,
    SettingsRepository? settingsRepository,
    MaintenanceRepository? maintenanceRepository,
    FinanceRepository? financeRepository,
    PlaceRepository? placeRepository,
    ServiceVisitRepository? serviceVisitRepository,
    SessionRepository? sessionRepository,
    VoiceChatRepository? voiceChatRepository,
    LastKnownPlaceRepository? lastKnownPlaceRepository,
    InProgressRideRepository? inProgressRideRepository,
  }) {
    instance = AppRepositories(
      accountRepository: accountRepository,
      profileRepository: profileRepository,
      bikeRepository: bikeRepository,
      mechanicRepository: mechanicRepository,
      rideReportRepository: rideReportRepository,
      settingsRepository: settingsRepository,
      maintenanceRepository: maintenanceRepository,
      financeRepository: financeRepository,
      placeRepository: placeRepository,
      serviceVisitRepository: serviceVisitRepository,
      sessionRepository: sessionRepository,
      voiceChatRepository: voiceChatRepository,
      lastKnownPlaceRepository: lastKnownPlaceRepository,
      inProgressRideRepository: inProgressRideRepository,
    );
  }

  static void resetToDefault() {
    instance = AppRepositories();
  }
}
