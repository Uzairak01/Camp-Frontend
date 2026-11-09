import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/data/app_repositories.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/controllers/auth_controller.dart';
import '../../../garage/controllers/active_bike_controller.dart';
import '../../../garage/domain/bike_model.dart';
import '../../../maintenance/controllers/post_ride_report_controller.dart';
import '../../../maintenance/domain/maintenance_item_model.dart';
import '../../../maintenance/domain/post_ride_report.dart';
import '../../../settings/controllers/settings_controller.dart';
import '../../controllers/profile_controller.dart';
import '../../domain/emergency_phone_helper.dart';
import '../../domain/profile_stats.dart';
import '../widgets/app_drawer_widget.dart';

/// CAMP Rider Profile Screen
/// High-fidelity skeuomorphic cockpit profile displaying rider profile,
/// touring tiers, trail badges, garage fleet, health status, and settings.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<MaintenanceItem> _maintenanceItems = [];

  @override
  void initState() {
    super.initState();
    _loadMaintenanceItems();
  }

  Future<void> _loadMaintenanceItems() async {
    try {
      final items = await AppRepositories.instance.maintenanceRepository.loadMaintenanceItems();
      if (mounted) {
        setState(() {
          _maintenanceItems = items;
        });
      }
    } catch (_) {}
  }

  /// Navigation height constants for strict anti-overlap calculation:
  /// CampBottomNav container height (48 + 16 = 64px) + floating bottom margin (24px) + clearance (32px) = 120px
  static const double _kNavHeight = 64.0;
  static const double _kNavBottomMargin = 24.0;
  static const double _kScrollBottomPadding = _kNavHeight + _kNavBottomMargin + 32.0;

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
        duration: const Duration(milliseconds: 2200),
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
            // ── Scrollable Body Content ─────────────────────────────────────
            SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppColors.screenPadding,
                  8.0,
                  AppColors.screenPadding,
                  _kScrollBottomPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Top Header Bar (Circular Back, CAMP with orange dot, PROFILE pill)
                    CampAppBar(
                      leading: CampAppBarLeading.back,
                      actionWidget: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.clay,
                          borderRadius: BorderRadius.circular(AppColors.radiusPill),
                          boxShadow: AppColors.skeuRaisedSmall,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: const BoxDecoration(
                                color: AppColors.tacticalOrange,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Text(
                              'PROFILE',
                              style: GoogleFonts.manrope(
                                color: AppColors.terracotta,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 2. Cockpit Hero Card
                    _buildCockpitHeroCard(),

                    const SizedBox(height: AppColors.cardGap),

                    // 3, 4, 5. Stat Cards, Touring Tier Progress, and Trail Badges
                    ListenableBuilder(
                      listenable: PostRideReportController.instance,
                      builder: (context, _) {
                        return Column(
                          children: [
                            _buildStatsGrid(),
                            const SizedBox(height: AppColors.cardGap),
                            _buildTouringTierCard(),
                            const SizedBox(height: AppColors.cardGap),
                            _buildTrailBadgesSection(),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: AppColors.cardGap),

                    // 6. My Garage (Horizontal Bike Carousel)
                    _buildMyGarageSection(),

                    const SizedBox(height: AppColors.cardGap),

                    // 7. Maintenance Health Card
                    _buildMaintenanceHealthCard(),

                    const SizedBox(height: AppColors.cardGap),

                    // 8. Recent Trips
                    _buildRecentTripsSection(),

                    const SizedBox(height: AppColors.cardGap),

                    // 9. Rider Medical & SOS ID Card
                    _buildMedicalSosCard(),

                    const SizedBox(height: AppColors.cardGap),

                    // 10. Settings List Card
                    _buildSettingsSection(),

                    const SizedBox(height: AppColors.cardGap),

                    // 11. Full-width Log Out Button
                    _buildLogOutButton(),
                  ],
                ),
              ),
            ),

            // ── Floating Bottom Dock (Index 5: Profile Active) ───────────────
            const Positioned(
              left: 0,
              right: 0,
              bottom: _kNavBottomMargin,
              child: Center(
                child: CampBottomNav(
                  selected: CampTab.profile,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 2. Cockpit Hero Card ───────────────────────────────────────────────────
  Widget _buildCockpitHeroCard() {
    return ListenableBuilder(
      listenable: Listenable.merge([ProfileController.instance, ActiveBikeController.instance]),
      builder: (context, _) {
        final profile = ProfileController.instance;
        final avatarPath = profile.avatarPath;
        final displayName = profile.fullName.isNotEmpty ? profile.fullName : 'Welcome back';
        final firstName = profile.firstName;
        final activeBike = ActiveBikeController.instance.activeBike;
        final bikeSubtitle = activeBike != null
            ? 'Cockpit Link Active • ${activeBike.name}'
            : 'No bike added yet';
        return CockpitHeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top section: Avatar + Info
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar with orange border
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.tacticalOrange,
                      width: 2.2,
                    ),
                    gradient: avatarPath == null
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF4A3223), Color(0xFF2B1A10)],
                          )
                        : null,
                  ),
                  child: ClipOval(
                    child: avatarPath != null && File(avatarPath).existsSync()
                        ? Image.file(File(avatarPath), fit: BoxFit.cover)
                        : Center(
                            child: firstName.isNotEmpty
                                ? Text(
                                    firstName[0].toUpperCase(),
                                    style: GoogleFonts.manrope(
                                      color: const Color(0xFFFDE68A),
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  )
                                : const Icon(
                                    Icons.person_rounded,
                                    color: Color(0xFFFDE68A),
                                    size: 24,
                                  ),
                          ),
                  ),
                ),
                const SizedBox(width: 14),

                // Name, ADV PRO tag, and vehicle link
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              displayName,
                              style: GoogleFonts.manrope(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        bikeSubtitle,
                        style: GoogleFonts.manrope(
                          color: const Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Bottom Action Row: "Edit Profile" + QR Code Icon Button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pushNamed(CampRoutes.editProfile),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppColors.radiusTile),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.edit_note_rounded,
                            size: 19,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Edit Profile',
                            style: GoogleFonts.manrope(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pushNamed(CampRoutes.emergencyQr),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppColors.radiusTile),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 1,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.qr_code_2_rounded,
                        color: Colors.white,
                        size: 21,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  // ── 3. Stat Cards (2x2 Grid) ───────────────────────────────────────────────
  Widget _buildStatsGrid() {
    final stats = ProfileStats(PostRideReportController.instance.reports);

    final String distVal = stats.lifetimeDistanceDisplay;
    final String distSub = stats.hasRides ? 'Lifetime distance' : 'No rides yet';

    final String ridesVal = stats.ridesCountDisplay;
    final String ridesSub = stats.hasRides
        ? (stats.ridesCount == 1 ? '1 ride completed' : '${stats.ridesCount} rides completed')
        : 'No rides yet';

    final String saddleVal = stats.saddleTimeDisplay;
    final String saddleSub = stats.hasRides ? 'Saddle time' : 'No rides yet';

    final String longestVal = stats.longestRideDisplay;
    final String longestUnit = stats.hasRides ? 'KM' : '';
    final String longestSub = stats.hasRides ? 'Longest single ride' : 'No rides yet';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatTile(
                title: 'LIFETIME DISTANCE',
                icon: Icons.explore_outlined,
                iconColor: AppColors.tacticalOrange,
                statValue: distVal,
                statUnit: 'KM',
                isUnitOrange: true,
                subtitle: distSub,
              ),
            ),
            const SizedBox(width: AppColors.cardGap),
            Expanded(
              child: _buildStatTile(
                title: 'RIDES COMPLETED',
                icon: Icons.route_rounded,
                iconColor: AppColors.tacticalOrange,
                statValue: ridesVal,
                statUnit: stats.ridesCount == 1 ? 'Ride' : 'Rides',
                isUnitOrange: false,
                subtitle: ridesSub,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppColors.cardGap),
        Row(
          children: [
            Expanded(
              child: _buildStatTile(
                title: 'SADDLE TIME',
                icon: Icons.access_time_rounded,
                iconColor: AppColors.mutedText,
                statValue: saddleVal,
                statUnit: '',
                isUnitOrange: false,
                subtitle: saddleSub,
              ),
            ),
            const SizedBox(width: AppColors.cardGap),
            Expanded(
              child: _buildStatTile(
                title: 'LONGEST SINGLE RIDE',
                icon: Icons.bolt_rounded,
                iconColor: AppColors.mutedText,
                statValue: longestVal,
                statUnit: longestUnit,
                isUnitOrange: true,
                subtitle: longestSub,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatTile({
    required String title,
    required IconData icon,
    required Color iconColor,
    required String statValue,
    required String statUnit,
    required bool isUnitOrange,
    required String subtitle,
  }) {
    return CampCard(
      padding: const EdgeInsets.all(14),
      borderRadius: AppColors.radiusCard,
      color: AppColors.clay,
      shadows: AppColors.skeuRaised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.overline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.clayDark,
                  boxShadow: AppColors.skeuRecessed,
                ),
                child: Center(
                  child: Icon(icon, size: 14, color: iconColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                statValue,
                style: GoogleFonts.manrope(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.darkCharcoal,
                  letterSpacing: -0.5,
                ),
              ),
              if (statUnit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  statUnit,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isUnitOrange ? AppColors.tacticalOrange : AppColors.darkCharcoal,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.mutedText,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── 4. Touring Tier Progress ───────────────────────────────────────────────
  Widget _buildTouringTierCard() {
    final stats = ProfileStats(PostRideReportController.instance.reports);
    final tier = stats.currentTier;
    final bool isTop = stats.isTopTier;

    return CampCard(
      padding: const EdgeInsets.all(AppColors.cardPadding),
      borderRadius: AppColors.radiusCard,
      color: AppColors.clay,
      shadows: AppColors.skeuRaised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOURING TIER PROGRESS',
            style: AppTextStyles.overline,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tier.displayName,
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkCharcoal,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDD5),
                  borderRadius: BorderRadius.circular(AppColors.radiusPill),
                ),
                child: Text(
                  isTop ? 'TOP' : '${stats.tierProgressPercent}%',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppColors.tacticalOrangeDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress track
          ClipRRect(
            borderRadius: BorderRadius.circular(AppColors.radiusPill),
            child: Container(
              height: 8,
              color: AppColors.clayDeep,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: stats.tierProgressFraction.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.tacticalOrange,
                    borderRadius: BorderRadius.circular(AppColors.radiusPill),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Current: ${stats.lifetimeDistanceDisplay} KM',
                  style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  isTop
                      ? 'Top tier reached'
                      : 'Next tier: ${stats.nextTier!.thresholdKm.round()} KM (${stats.kmToNextTier.round()} KM to go)',
                  style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 5. Earned Trail Badges ─────────────────────────────────────────────────
  Widget _buildTrailBadgesSection() {
    final stats = ProfileStats(PostRideReportController.instance.reports);
    final badges = stats.badges;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'EARNED TRAIL BADGES',
              style: AppTextStyles.overline,
            ),
            Text(
              '${stats.unlockedBadgeCount}/${badges.length} UNLOCKED',
              style: GoogleFonts.manrope(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: AppColors.tacticalOrangeDark,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: badges.map((b) {
              final isUnlocked = b.isUnlocked;
              return Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Column(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: isUnlocked ? Colors.white : AppColors.clayDark,
                        borderRadius: BorderRadius.circular(AppColors.radiusTile),
                        boxShadow: isUnlocked ? AppColors.skeuRaisedSmall : AppColors.skeuRecessed,
                        border: isUnlocked
                            ? Border.all(
                                color: AppColors.tacticalOrange.withValues(alpha: 0.35),
                                width: 1.2,
                              )
                            : Border.all(
                                color: Colors.black.withValues(alpha: 0.05),
                                width: 1,
                              ),
                      ),
                      child: Center(
                        child: Icon(
                          b.icon,
                          size: 26,
                          color: isUnlocked ? AppColors.tacticalOrange : AppColors.mutedLight,
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    SizedBox(
                      width: 84,
                      child: Text(
                        b.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: GoogleFonts.manrope(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: isUnlocked ? AppColors.darkCharcoal : AppColors.mutedText,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      width: 84,
                      child: Text(
                        b.requirementText,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: GoogleFonts.manrope(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: isUnlocked ? AppColors.tacticalOrangeDark : AppColors.mutedLight,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── 6. My Garage (Horizontal Bike Carousel) ────────────────────────────────
  Widget _buildMyGarageSection() {
    return ListenableBuilder(
      listenable: ActiveBikeController.instance,
      builder: (context, _) {
        final bikeController = ActiveBikeController.instance;
        final bikes = bikeController.bikes;
        final activeBike = bikeController.activeBike;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'MY GARAGE',
              actionWidget: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pushNamed(CampRoutes.addBike),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.clay,
                    borderRadius: BorderRadius.circular(AppColors.radiusPill),
                    border: Border.all(
                      color: AppColors.tacticalOrange.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                    boxShadow: AppColors.skeuRaisedSmall,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.camera_alt_outlined,
                        size: 15,
                        color: AppColors.tacticalOrange,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Recognize bike with camera',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (bikes.isEmpty)
              CampCard(
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                borderRadius: AppColors.radiusCard,
                color: AppColors.clay,
                shadows: AppColors.skeuRaised,
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.clayDark,
                          boxShadow: AppColors.skeuRecessed,
                        ),
                        child: const Center(
                          child: Icon(Icons.two_wheeler_rounded, size: 26, color: AppColors.mutedText),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No motorcycles in garage',
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add your motorcycle to track maintenance and stats.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption.copyWith(color: AppColors.mutedText),
                      ),
                      const SizedBox(height: 14),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(context).pushNamed(CampRoutes.addBike),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.tacticalOrange,
                            borderRadius: BorderRadius.circular(AppColors.radiusPill),
                            boxShadow: AppColors.orangeGlow,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                              const SizedBox(width: 5),
                              Text(
                                'Add motorcycle',
                                style: GoogleFonts.manrope(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    for (int i = 0; i < bikes.length; i++) ...[
                      if (i > 0) const SizedBox(width: 14),
                      _buildBikeGarageCard(
                        bike: bikes[i],
                        isActive: bikes[i].id == activeBike?.id,
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildBikeGarageCard({
    required Bike bike,
    required bool isActive,
  }) {
    final bikeItems = isActive ? _maintenanceItems : const <MaintenanceItem>[];
    final String statusLabel;
    final Color statusColor;

    if (bikeItems.isEmpty) {
      statusLabel = 'No data yet';
      statusColor = AppColors.mutedText;
    } else if (bikeItems.any((i) => i.status == MaintenanceStatus.overdue)) {
      statusLabel = 'Overdue';
      statusColor = AppColors.alertRed;
    } else if (bikeItems.any((i) => i.status == MaintenanceStatus.dueSoon)) {
      statusLabel = 'Due soon';
      statusColor = AppColors.tacticalOrange;
    } else if (bikeItems.any((i) => i.status == MaintenanceStatus.diyRec)) {
      statusLabel = 'DIY Rec';
      statusColor = const Color(0xFFF59E0B);
    } else {
      statusLabel = 'OK';
      statusColor = AppColors.statusGreen;
    }

    final subtitle = bike.formattedSubtitle;
    final mileageStr = '${bike.mileageKm.round()} km';
    final hasPlate = bike.plateNumber != null && bike.plateNumber!.isNotEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pushNamed(
        CampRoutes.bikeProfile,
        arguments: bike.id,
      ),
      child: Container(
        width: 236,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.clay,
          borderRadius: BorderRadius.circular(AppColors.radiusCard),
          boxShadow: AppColors.skeuRaised,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bike Image with top-right pill
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppColors.radiusTile),
                  child: SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: CampBikeImage(
                      imagePath: bike.imagePath,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(AppColors.radiusPill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: GoogleFonts.manrope(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              bike.name,
              style: GoogleFonts.manrope(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: AppColors.darkCharcoal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    subtitle.isNotEmpty ? subtitle : (hasPlate ? bike.plateNumber! : 'Motorcycle'),
                    style: AppTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  mileageStr,
                  style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            if (hasPlate && subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'Plate: ${bike.plateNumber!}',
                style: AppTextStyles.caption.copyWith(fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive ? AppColors.statusGreen : AppColors.mutedLight,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isActive ? 'Primary Ride' : 'Standby Fleet',
                      style: GoogleFonts.manrope(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: isActive ? AppColors.statusGreen : AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
                if (isActive)
                  Text(
                    'Active',
                    style: GoogleFonts.manrope(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.statusGreen,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── 7. Maintenance Health Card ─────────────────────────────────────────────
  Widget _buildMaintenanceHealthCard() {
    return ListenableBuilder(
      listenable: ActiveBikeController.instance,
      builder: (context, _) {
        final activeBike = ActiveBikeController.instance.activeBike;
        final items = activeBike != null
            ? _maintenanceItems
            : const <MaintenanceItem>[];

        final String overallStatusLabel;
        final Color overallStatusColor;

        if (items.isEmpty) {
          overallStatusLabel = 'No data yet';
          overallStatusColor = AppColors.mutedText;
        } else if (items.any((i) => i.status == MaintenanceStatus.overdue)) {
          overallStatusLabel = 'Overdue';
          overallStatusColor = AppColors.alertRed;
        } else if (items.any((i) => i.status == MaintenanceStatus.dueSoon)) {
          overallStatusLabel = 'Due soon';
          overallStatusColor = AppColors.tacticalOrange;
        } else if (items.any((i) => i.status == MaintenanceStatus.diyRec)) {
          overallStatusLabel = 'DIY Rec';
          overallStatusColor = const Color(0xFFF59E0B);
        } else {
          overallStatusLabel = 'OK';
          overallStatusColor = AppColors.statusGreen;
        }

        final overdueCount = items.where((i) => i.status == MaintenanceStatus.overdue).length;
        final dueSoonCount = items.where((i) => i.status == MaintenanceStatus.dueSoon).length;
        final okCount = items.where((i) => i.status == MaintenanceStatus.ok).length;

        // Sort items by priority: overdue first, then dueSoon, then diyRec, then ok
        final sortedItems = List<MaintenanceItem>.from(items)
          ..sort((a, b) {
            int priority(MaintenanceStatus s) => switch (s) {
                  MaintenanceStatus.overdue => 0,
                  MaintenanceStatus.dueSoon => 1,
                  MaintenanceStatus.diyRec => 2,
                  MaintenanceStatus.ok => 3,
                };
            return priority(a.status).compareTo(priority(b.status));
          });

        return CampCard(
          padding: const EdgeInsets.all(AppColors.cardPadding),
          borderRadius: AppColors.radiusCard,
          color: AppColors.clay,
          shadows: AppColors.skeuRaised,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with Shield + Title + Health Badge
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEDD5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.shield_outlined,
                        size: 18,
                        color: AppColors.tacticalOrange,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'MAINTENANCE HEALTH',
                      style: GoogleFonts.manrope(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.darkCharcoal,
                        letterSpacing: 0.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: overallStatusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppColors.radiusPill),
                      border: Border.all(
                        color: overallStatusColor.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      overallStatusLabel,
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: overallStatusColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              if (items.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppColors.radiusTile),
                    boxShadow: AppColors.skeuRaisedSmall,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeBike != null
                            ? 'No maintenance items recorded for ${activeBike.name}'
                            : 'No active motorcycle selected',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Track service intervals, component wear, and upcoming maintenance schedules.',
                        style: AppTextStyles.caption.copyWith(color: AppColors.mutedText),
                      ),
                    ],
                  ),
                )
              else ...[
                // Item breakdown summary
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppColors.radiusTile),
                    boxShadow: AppColors.skeuRaisedSmall,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildHealthStatCount('Overdue', overdueCount, AppColors.alertRed),
                      Container(height: 20, width: 1, color: AppColors.clayDark),
                      _buildHealthStatCount('Due Soon', dueSoonCount, AppColors.tacticalOrange),
                      Container(height: 20, width: 1, color: AppColors.clayDark),
                      _buildHealthStatCount('OK', okCount, AppColors.statusGreen),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                Text(
                  'Monitored Components',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkCharcoal,
                  ),
                ),
                const SizedBox(height: 8),

                for (final item in sortedItems.take(3)) ...[
                  _buildRealMaintenanceItemRow(item),
                  const SizedBox(height: 8),
                ],
              ],

              const SizedBox(height: 10),

              // View Full Report Button
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pushNamed(CampRoutes.mechanics),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.clay,
                    borderRadius: BorderRadius.circular(AppColors.radiusTile),
                    border: Border.all(
                      color: const Color(0xFFCBD5E1),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'View Maintenance Details',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.darkCharcoal,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHealthStatCount(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(fontSize: 10.5, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildRealMaintenanceItemRow(MaintenanceItem item) {
    final (statusLabel, statusColor) = switch (item.status) {
      MaintenanceStatus.overdue => ('Overdue', AppColors.alertRed),
      MaintenanceStatus.dueSoon => ('Due soon', AppColors.tacticalOrange),
      MaintenanceStatus.diyRec => ('DIY Rec', const Color(0xFFF59E0B)),
      MaintenanceStatus.ok => ('OK', AppColors.statusGreen),
    };

    final subtitle = item.dueMileage != null && item.dueMileage!.trim().isNotEmpty
        ? 'Service at ${item.dueMileage} km'
        : (item.dueDate != null && item.dueDate!.trim().isNotEmpty
            ? 'Due: ${item.dueDate}'
            : (item.conditionNote ?? item.subtitle ?? 'Recurring check'));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppColors.radiusTile),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkCharcoal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppColors.radiusPill),
            ),
            child: Text(
              statusLabel,
              style: GoogleFonts.manrope(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 8. Recent Trips Section ────────────────────────────────────────────────
  Widget _buildRecentTripsSection() {
    return ListenableBuilder(
      listenable: PostRideReportController.instance,
      builder: (context, _) {
        final reports = PostRideReportController.instance.reports;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'RECENT TRIPS',
              actionLabel: reports.isNotEmpty ? 'See all' : null,
              onAction: reports.isNotEmpty
                  ? () => Navigator.of(context).pushNamed(CampRoutes.rideHistory)
                  : null,
            ),
            if (reports.isEmpty)
              CampCard(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                borderRadius: AppColors.radiusCard,
                color: AppColors.clay,
                shadows: AppColors.skeuRaised,
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.route_rounded, size: 36, color: AppColors.mutedLight),
                      const SizedBox(height: 8),
                      Text(
                        'No rides yet',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Completed rides will appear here with distance, duration, and terrain summary.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption.copyWith(color: AppColors.mutedText),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              for (final report in reports.take(3)) ...[
                _buildRealTripCard(report),
                const SizedBox(height: 10),
              ],
            ],
          ],
        );
      },
    );
  }

  Widget _buildRealTripCard(PostRideReport report) {
    final title = report.routeTitle.isNotEmpty
        ? report.routeTitle
        : 'Ride on ${report.formattedDate}';
    final tag = report.terrain.isNotEmpty ? report.terrain : 'Ride';
    final subtitle = '${report.formattedDate} • ${report.distanceKm.toStringAsFixed(1)} km';
    final duration = report.durationHours != null
        ? '${report.durationHours!.toStringAsFixed(1)} hrs'
        : (report.durationMinutes != null ? '${report.durationMinutes} min' : '—');
    final String note = (report.notes != null && report.notes!.trim().isNotEmpty)
        ? report.notes!
        : 'Logged ride';

    return CampCard(
      padding: const EdgeInsets.all(14),
      borderRadius: AppColors.radiusCard,
      color: AppColors.clay,
      shadows: AppColors.skeuRaised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkCharcoal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDD5),
                  borderRadius: BorderRadius.circular(AppColors.radiusPill),
                ),
                child: Text(
                  tag,
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.tacticalOrangeDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: AppTextStyles.caption),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.explore_outlined, size: 14, color: AppColors.tacticalOrange),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        note,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkCharcoal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                duration,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkCharcoal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 9. Rider Medical & SOS ID Card ─────────────────────────────────────────
  Widget _buildMedicalSosCard() {
    return ListenableBuilder(
      listenable: ProfileController.instance,
      builder: (context, _) {
        final controller = ProfileController.instance;
        final contacts = controller.emergencyContacts;
        final primary = controller.primaryEmergencyContact;
        final hasContacts = contacts.isNotEmpty;

        return CampCard(
          padding: const EdgeInsets.all(AppColors.cardPadding),
          borderRadius: AppColors.radiusCard,
          color: AppColors.clay,
          shadows: AppColors.skeuRaised,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: AppColors.alertRed,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'RIDER MEDICAL & SOS ID',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.darkCharcoal,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (hasContacts)
                    Container(
                      key: const Key('badge_sos_ready'),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(AppColors.radiusPill),
                      ),
                      child: Text(
                        'SOS ready',
                        style: GoogleFonts.manrope(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.statusGreen,
                        ),
                      ),
                    )
                  else
                    GestureDetector(
                      key: const Key('badge_add_contact'),
                      onTap: () => Navigator.of(context).pushNamed(CampRoutes.editProfile),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(AppColors.radiusPill),
                          border: Border.all(color: const Color(0xFFFDE68A), width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add_rounded, size: 11, color: AppColors.tacticalOrange),
                            const SizedBox(width: 3),
                            Text(
                              'Add a contact',
                              style: GoogleFonts.manrope(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.tacticalOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _buildInfoKeyValueRow(
                label: 'Emergency ICE:',
                valueWidget: Text(
                  hasContacts && primary != null
                      ? '${primary.name}${primary.relation.isNotEmpty ? " (${primary.relation})" : ""} • ${EmergencyPhoneHelper.formatPhoneReadable(primary.phone)}${contacts.length > 1 ? " (+${contacts.length - 1} more)" : ""}'
                      : 'Emergency Contact Not Set',
                  style: GoogleFonts.manrope(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkCharcoal,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(height: 8),
              _buildInfoKeyValueRow(
                label: 'Blood & Allergies:',
                valueWidget: Builder(
                  builder: (context) {
                    final blood = controller.bloodGroup.trim();
                    final allergies = controller.allergies.trim();
                    if (blood.isEmpty && allergies.isEmpty) {
                      return Text(
                        'Not set',
                        style: GoogleFonts.manrope(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mutedText,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.right,
                      );
                    }
                    return RichText(
                      textAlign: TextAlign.right,
                      text: TextSpan(
                        style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w800),
                        children: [
                          if (blood.isNotEmpty)
                            TextSpan(
                              text: blood,
                              style: const TextStyle(color: AppColors.alertRed),
                            ),
                          if (allergies.isNotEmpty)
                            TextSpan(
                              text: blood.isNotEmpty ? ' • $allergies' : allergies,
                              style: const TextStyle(color: AppColors.darkCharcoal, fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              _buildInfoKeyValueRow(
                label: 'Emergency SOS Method:',
                valueWidget: Text(
                  'Phone SMS & Dialer',
                  style: GoogleFonts.manrope(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkCharcoal,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(height: 16),
              // View Emergency Protocols button
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showNotification('Emergency ICE & Health Protocols configured via device SMS and dialer'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppColors.clay,
                    borderRadius: BorderRadius.circular(AppColors.radiusTile),
                    border: Border.all(
                      color: AppColors.alertRed.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          'View Emergency Protocols & Health Card',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.alertRed,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.alertRed,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoKeyValueRow({
    required String label,
    required Widget valueWidget,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 12),
        Expanded(child: valueWidget),
      ],
    );
  }

  // ── 10. Settings Section ───────────────────────────────────────────────────
  Widget _buildSettingsSection() {
    return ListenableBuilder(
      listenable: SettingsController.instance,
      builder: (context, _) {
        final settings = SettingsController.instance;
        final notificationsLabel = settings.notificationsEnabled ? 'Enabled' : 'Disabled';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SETTINGS',
              style: AppTextStyles.overline,
            ),
            const SizedBox(height: 10),
            CampCard(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              borderRadius: AppColors.radiusCard,
              color: AppColors.clay,
              shadows: AppColors.skeuRaised,
              child: Column(
                children: [
                  _buildSettingsRow(
                    icon: Icons.person_outline_rounded,
                    title: 'Edit Personal Info',
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.mutedLight, size: 20),
                    onTap: () => Navigator.of(context).pushNamed(CampRoutes.editProfile),
                  ),
                  const Divider(height: 1, color: Color(0x12000000)),
                  _buildSettingsRow(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notifications',
                    subtitle: 'Low fuel alerts',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          notificationsLabel,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: settings.notificationsEnabled ? AppColors.statusGreen : AppColors.mutedText,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.mutedLight, size: 20),
                      ],
                    ),
                    onTap: () => Navigator.of(context).pushNamed(CampRoutes.settings),
                  ),
                  const Divider(height: 1, color: Color(0x12000000)),
                  _buildSettingsRow(
                    icon: Icons.cloud_download_outlined,
                    title: 'Offline Maps',
                    subtitle: 'Coming soon',
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.mutedLight, size: 20),
                    onTap: () => Navigator.of(context).pushNamed(CampRoutes.settings),
                  ),
                  const Divider(height: 1, color: Color(0x12000000)),
                  _buildSettingsRow(
                    icon: Icons.security_rounded,
                    title: 'Privacy & Data',
                    subtitle: 'Your data stays on this phone.',
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.mutedLight, size: 20),
                    onTap: () => Navigator.of(context).pushNamed(CampRoutes.settings),
                  ),
                  const Divider(height: 1, color: Color(0x12000000)),
                  _buildSettingsRow(
                    icon: Icons.help_outline_rounded,
                    title: 'Help & Support',
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.mutedLight, size: 20),
                    onTap: () => Navigator.of(context).pushNamed(CampRoutes.settings),
                  ),
                  const Divider(height: 1, color: Color(0x12000000)),
                  _buildSettingsRow(
                    customLeading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.clayDark,
                        borderRadius: BorderRadius.circular(AppColors.radiusTile),
                        boxShadow: AppColors.skeuRecessed,
                      ),
                      child: Center(
                        child: Text(
                          'CAMP',
                          style: GoogleFonts.manrope(
                            color: AppColors.tacticalOrange,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    title: 'About CAMP',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'v1.0.0 (Build 890-GS)',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mutedText,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.mutedLight, size: 20),
                      ],
                    ),
                    onTap: () => Navigator.of(context).pushNamed(CampRoutes.settings),
                  ),
                  if (kDebugMode) ...[
                    const Divider(height: 1, color: Color(0x12000000)),
                    _buildSettingsRow(
                      key: const ValueKey('profile_tracking_diagnostics_row'),
                      icon: Icons.bug_report_rounded,
                      title: 'Tracking diagnostics (debug)',
                      subtitle: 'Inspect live location fixes & filters',
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.mutedLight, size: 20),
                      onTap: () => Navigator.of(context).pushNamed(CampRoutes.trackingDiagnostics),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSettingsRow({
    required String title,
    required Widget trailing,
    required VoidCallback onTap,
    Key? key,
    IconData? icon,
    Widget? customLeading,
    String? subtitle,
  }) {
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            customLeading ??
                IconTile(
                  icon: icon ?? Icons.settings_outlined,
                  size: 36,
                  iconSize: 18,
                  iconColor: AppColors.darkCharcoal,
                ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkCharcoal,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  // ── 11. Full-width Log Out Button ──────────────────────────────────────────
  Widget _buildLogOutButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleLogout,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.clay,
          borderRadius: BorderRadius.circular(AppColors.radiusTile),
          border: Border.all(
            color: AppColors.alertRed.withValues(alpha: 0.45),
            width: 1.5,
          ),
          boxShadow: AppColors.skeuRaisedSmall,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.logout_rounded,
              size: 19,
              color: AppColors.alertRed,
            ),
            const SizedBox(width: 8),
            Text(
              'Log Out',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.alertRed,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.clay,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusCard),
        ),
        title: Text(
          'Log Out',
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.darkCharcoal,
          ),
        ),
        content: Text(
          'Are you sure you want to log out? Local ride history and bike data will be preserved.',
          style: GoogleFonts.manrope(
            fontSize: 13.5,
            color: AppColors.darkCharcoal,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.mutedText,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Log Out',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.alertRed,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await AuthController.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        CampRoutes.signIn,
        (route) => false,
      );
    }
  }
}
