import 'package:flutter/material.dart';

import '../../../../core/widgets/camp_app_bar.dart';
import '../../../../core/widgets/gps_live_pill.dart';
import '../../../navigation/domain/location_service.dart';

/// Top Navigation Bar — thin wrapper delegating to [CampAppBar].
/// Displays [GpsLivePill] when real GPS is active with recent fixes; hides otherwise.
class AppHeaderWidget extends StatelessWidget {
  const AppHeaderWidget({
    super.key,
    this.onMenuPressed,
    this.onBadgePressed,
    this.locationService = const GeolocatorLocationService(),
  });

  final VoidCallback? onMenuPressed;
  final VoidCallback? onBadgePressed;
  final LocationService locationService;

  @override
  Widget build(BuildContext context) {
    return CampAppBar(
      leading: CampAppBarLeading.menu,
      onLeadingPressed: onMenuPressed,
      showLogo: true,
      actionWidget: GpsLivePill(locationService: locationService),
    );
  }
}
