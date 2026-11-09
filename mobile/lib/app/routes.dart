/// Central route-name constants for the CAMP application.
/// Strictly one canonical constant per screen.
abstract final class CampRoutes {
  static const String home = '/';
  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';
  static const String forgotPassword = '/forgot-password';

  static const String addBike = '/add-bike';
  static const String addMotorcycle = addBike;
  static const String bikeDetails = '/bike-details';
  static const String bikeScan = '/bike-scan';
  static const String bikeProfile = '/bike-profile';
  static const String garage = '/garage';

  static const String profile = '/profile';
  static const String editProfile = '/edit-profile';

  static const String mechanics = '/mechanics';
  static const String addMechanic = '/add-mechanic';

  static const String navigationMap = '/navigation/map';
  static const String voiceCopilot = '/voice-copilot';

  static const String routePacks = '/route-packs';
  static const String rideHistory = '/ride-history';
  static const String financeRigHealth = '/finance-rig-health';
  static const String maintenance = '/maintenance';
  static const String serviceSchedule = '/service-schedule';
  static const String predictiveMaintenance = '/predictive-maintenance';
  static const String carburetorTuning = '/carburetor-tuning';
  static const String postRideDebrief = '/post-ride-debrief';
  static const String settings = '/settings';
  static const String emergencySos = '/emergency-sos';
  static const String emergencyQr = '/emergency-qr';
  static const String weatherDetail = '/weather-detail';
  static const String trackingDiagnostics = '/settings/tracking-diagnostics';

  /// All non-legacy canonical routes (one per screen / entry point).
  static const List<String> canonicalRoutes = [
    home,
    signIn,
    signUp,
    forgotPassword,
    addBike,
    bikeDetails,
    bikeScan,
    bikeProfile,
    garage,
    profile,
    editProfile,
    mechanics,
    addMechanic,
    navigationMap,
    voiceCopilot,
    routePacks,
    rideHistory,
    financeRigHealth,
    maintenance,
    serviceSchedule,
    predictiveMaintenance,
    carburetorTuning,
    postRideDebrief,
    settings,
    emergencySos,
    emergencyQr,
    weatherDetail,
    trackingDiagnostics,
  ];
}
