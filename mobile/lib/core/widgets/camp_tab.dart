import '../../app/routes.dart';

/// Navigation tabs displayed in [CampBottomNav].
enum CampTab {
  home,
  garage,
  navigation,
  mechanics,
  finances,
  profile;

  /// Root canonical route associated with this tab.
  String get rootRoute {
    switch (this) {
      case CampTab.home:
        return CampRoutes.home;
      case CampTab.garage:
        return CampRoutes.addBike;
      case CampTab.navigation:
        return CampRoutes.navigationMap;
      case CampTab.mechanics:
        return CampRoutes.mechanics;
      case CampTab.finances:
        return CampRoutes.financeRigHealth;
      case CampTab.profile:
        return CampRoutes.profile;
    }
  }
}
