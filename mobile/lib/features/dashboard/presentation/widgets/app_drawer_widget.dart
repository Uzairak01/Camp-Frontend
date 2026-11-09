import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/skeuomorphic_container.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/controllers/auth_controller.dart';
import '../../../garage/controllers/active_bike_controller.dart';
import '../../../maintenance/controllers/maintenance_controller.dart';
import '../../../maintenance/controllers/post_ride_report_controller.dart';
import '../../../mechanics/controllers/mechanic_controller.dart';
import '../../controllers/profile_controller.dart';

/// CAMP's soft-tactile side navigation overlay.
/// All badges and counts come strictly from repositories (hide when count is 0).
class AppDrawerWidget extends StatelessWidget {
  const AppDrawerWidget({super.key});

  static const _orange = AppColors.tacticalOrange;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.sizeOf(context).width * .88,
      backgroundColor: AppColors.clay,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(AppColors.radiusCard),
          bottomRight: Radius.circular(AppColors.radiusCard),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
          child: Column(children: [
            _topBar(context),
            const SizedBox(height: 18),
            _riderSummary(context),
            const SizedBox(height: 18),
            Expanded(
              child: ListenableBuilder(
                listenable: Listenable.merge([
                  ActiveBikeController.instance,
                  PostRideReportController.instance,
                  MechanicController.instance,
                  MaintenanceController.instance,
                ]),
                builder: (context, _) {
                  final activeBike = ActiveBikeController.instance.activeBike;
                  final bikeCount = ActiveBikeController.instance.bikes.length;
                  final ridesCount = PostRideReportController.instance.reports.length;
                  final dueCount = MaintenanceController.instance.countDueItems(activeBike?.id);
                  final mechCount = MechanicController.instance.mechanics.length;

                  return ListView(
                    padding: EdgeInsets.zero,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _menuItem(
                        context,
                        icon: Icons.person_outline_rounded,
                        title: 'User Profile',
                        route: CampRoutes.profile,
                      ),
                      _menuItem(
                        context,
                        icon: Icons.garage_rounded,
                        iconColor: _orange,
                        title: 'My Garage',
                        subtitle: 'Manage Fleet & Active Rig',
                        badge: bikeCount > 0 ? '$bikeCount' : null,
                        orangeBadge: true,
                        route: CampRoutes.garage,
                      ),
                      _menuItem(
                        context,
                        icon: Icons.directions_bike_rounded,
                        title: 'Bike Profile',
                        badge: activeBike != null ? 'Active' : null,
                        route: CampRoutes.bikeProfile,
                      ),
                      _menuItem(
                        context,
                        icon: Icons.cloud_download_outlined,
                        title: 'Route Packs',
                        subtitle: 'Offline Topo & Maps',
                        route: CampRoutes.routePacks,
                      ),
                      _menuItem(
                        context,
                        icon: Icons.access_time_rounded,
                        title: 'Ride History',
                        subtitle: 'GPS Tracks & Stats',
                        badge: ridesCount > 0 ? '$ridesCount' : null,
                        route: CampRoutes.rideHistory,
                      ),
                      _menuItem(
                        context,
                        icon: Icons.compass_calibration_rounded,
                        title: 'Predictive Maintenance',
                        notification: dueCount > 0 ? '$dueCount' : null,
                        route: CampRoutes.predictiveMaintenance,
                      ),
                      _menuItem(
                        context,
                        icon: Icons.handyman_rounded,
                        iconColor: _orange,
                        title: 'Find a Mechanic',
                        subtitle: 'Community Pitstops & Roadside',
                        badge: mechCount > 0 ? '$mechCount' : null,
                        orangeBadge: true,
                        route: CampRoutes.mechanics,
                      ),
                      _menuItem(
                        context,
                        icon: Icons.build_outlined,
                        iconColor: _orange,
                        title: 'Add a Mechanic',
                        subtitle: 'Community Pitstops',
                        route: CampRoutes.addMechanic,
                      ),
                      _menuItem(
                        context,
                        icon: Icons.settings_outlined,
                        title: 'Settings',
                        route: CampRoutes.settings,
                      ),
                      _menuItem(
                        context,
                        icon: Icons.emergency_rounded,
                        iconColor: AppColors.alertRed,
                        title: 'Emergency SOS',
                        route: CampRoutes.emergencySos,
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            _logout(context),
          ]),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) => Row(children: [
        const CampLogo(fontSize: 22, dotSize: 7, iconSize: 28, showDot: true),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.clay,
              shape: BoxShape.circle,
              boxShadow: AppColors.skeuRaisedSmall,
            ),
            child: const Center(child: Icon(Icons.close_rounded, size: 21, color: AppColors.charcoalLight)),
          ),
        ),
      ]);

  Widget _riderSummary(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([
          ProfileController.instance,
          ActiveBikeController.instance,
          MaintenanceController.instance,
        ]),
        builder: (context, _) {
          final profile = ProfileController.instance;
          final riderName = profile.fullName;
          final riderFirstName = profile.firstName;
          final activeBike = ActiveBikeController.instance.activeBike;
          final bikeName = activeBike?.name ?? 'No active bike';
          final loggedKm = activeBike != null
              ? '${activeBike.odometerKm} km logged'
              : '0 km logged';

          Widget avatarContent;
          if (profile.avatarPath != null && profile.avatarPath!.isNotEmpty) {
            final file = File(profile.avatarPath!);
            if (file.existsSync()) {
              avatarContent = ClipOval(
                child: Image.file(file, width: 50, height: 50, fit: BoxFit.cover),
              );
            } else {
              avatarContent = Text(
                riderFirstName.isNotEmpty
                    ? riderFirstName[0].toUpperCase()
                    : 'R',
                style: GoogleFonts.manrope(
                  color: AppColors.terracotta,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              );
            }
          } else {
            avatarContent = Text(
              riderFirstName.isNotEmpty
                  ? riderFirstName[0].toUpperCase()
                  : 'R',
              style: GoogleFonts.manrope(
                color: AppColors.terracotta,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            );
          }

          String? statusBadge;
          if (activeBike != null && MaintenanceController.instance.hasMaintenanceData(activeBike)) {
            final due = MaintenanceController.instance.countDueItems(activeBike.id);
            statusBadge = due > 0 ? '$due due' : 'Up to date';
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed(CampRoutes.profile);
            },
            child: SkeuomorphicContainer(
              borderRadius: AppColors.radiusTile,
              color: Colors.white.withValues(alpha: .88),
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                Row(children: [
                  Container(
                    width: 54,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.clay,
                      border: Border.all(color: _orange, width: 2),
                    ),
                    child: avatarContent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(riderName, style: AppTextStyles.cardTitle),
                        const SizedBox(height: 3),
                        Text(bikeName, style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                ]),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: Color(0x11000000)),
                ),
                Row(children: [
                  if (statusBadge != null)
                    _pill(statusBadge, icon: Icons.build_circle_rounded, orange: statusBadge.contains('due')),
                  const Spacer(),
                  Text(
                    loggedKm,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ]),
              ]),
            ),
          );
        },
      );

  Widget _menuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? route,
    VoidCallback? onTap,
    String? subtitle,
    String? badge,
    String? notification,
    Color? iconColor,
    bool orangeBadge = false,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GestureDetector(
          onTap: () async {
            Navigator.of(context).pop();
            if (onTap != null) {
              onTap();
            } else if (route != null) {
              Navigator.of(context).pushNamed(route);
            }
          },
          child: SkeuomorphicContainer(
            borderRadius: AppColors.radiusTile,
            shadows: AppColors.skeuRaisedSmall,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              IconTile(
                icon: icon,
                iconColor: iconColor ?? AppColors.charcoalLight,
                size: 38,
                borderRadius: 12,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.itemTitle),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.caption),
                  ],
                ]),
              ),
              if (badge != null) ...[const SizedBox(width: 8), _pill(badge, orange: orangeBadge)],
              if (notification != null) ...[const SizedBox(width: 8), _notification(notification)],
              const SizedBox(width: 7),
              const Icon(Icons.chevron_right_rounded, color: AppColors.mutedLight, size: 21),
            ]),
          ),
        ),
      );

  Widget _pill(String label, {IconData? icon, bool orange = false}) => Container(
        constraints: const BoxConstraints(maxWidth: 86),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: orange ? const Color(0xFFFFF0DB) : AppColors.clayDark,
          borderRadius: BorderRadius.circular(7),
          border: orange ? Border.all(color: const Color(0x33F56500)) : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 12, color: _orange), const SizedBox(width: 4)],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                color: orange ? _orange : AppColors.charcoalLight,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ]),
      );

  Widget _notification(String label) => Container(
        width: 18,
        height: 18,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: Color(0xFFFF4C2E), shape: BoxShape.circle),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
      );

  Widget _logout(BuildContext context) => GestureDetector(
        onTap: () async {
          final navigator = Navigator.of(context);
          final messenger = ScaffoldMessenger.of(context);
          navigator.pop();
          await AuthController.instance.signOut();
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              content: const Text(
                'Logged out successfully',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
              backgroundColor: AppColors.darkCharcoal,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(milliseconds: 2000),
            ),
          );
          navigator.pushNamedAndRemoveUntil(CampRoutes.signIn, (route) => false);
        },
        child: SkeuomorphicContainer(
          borderRadius: AppColors.radiusTile,
          shadows: AppColors.skeuRaisedSmall,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          child: Row(children: [
            const Icon(Icons.logout_rounded, color: AppColors.alertRed, size: 20),
            const SizedBox(width: 10),
            Text('Log Out', style: AppTextStyles.itemTitle.copyWith(color: AppColors.alertRed)),
          ]),
        ),
      );
}
