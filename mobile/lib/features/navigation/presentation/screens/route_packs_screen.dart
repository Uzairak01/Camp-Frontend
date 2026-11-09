import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/camp_app_bar.dart';
import '../../../../core/widgets/camp_bottom_nav.dart';
import '../../../../core/widgets/gps_live_pill.dart';
import '../../../dashboard/presentation/widgets/app_drawer_widget.dart';
import '../../domain/location_service.dart';
import '../../domain/route_pack_model.dart';
import '../widgets/route_pack_card_widget.dart';
import '../widgets/route_packs_section_header_widget.dart';
import '../widgets/route_packs_title_widget.dart';

/// Screen displaying route packs.
/// Conforms to the official CAMP design system and honesty rules:
/// - Every pack shows "Coming soon" with no sizes or fake download states.
/// - Header GPS LIVE pill shows strictly when location service is active with recent fix.
/// - Unbacked Wi-Fi switch and telemetry claims removed.
class RoutePacksScreen extends StatefulWidget {
  const RoutePacksScreen({
    super.key,
    this.locationService = const GeolocatorLocationService(),
  });

  final LocationService locationService;

  @override
  State<RoutePacksScreen> createState() => _RoutePacksScreenState();
}

class _RoutePacksScreenState extends State<RoutePacksScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late List<RoutePack> _packs;

  @override
  void initState() {
    super.initState();
    _packs = List.from(RoutePack.defaultPacks);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawerWidget(),
      backgroundColor: AppColors.clay,
      body: Stack(
        children: [
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
                  // ── 1. Top App Bar ─────────────────────────────────────────
                  CampAppBar(
                    leading: CampAppBarLeading.menu,
                    onLeadingPressed: () =>
                        _scaffoldKey.currentState?.openDrawer(),
                    actionWidget: GpsLivePill(
                      locationService: widget.locationService,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── 2. Title Block ─────────────────────────────────────────
                  const RoutePacksTitleWidget(),

                  const SizedBox(height: AppColors.cardGap + 2),

                  // ── 3. Section Header ──────────────────────────────────────
                  const RoutePacksSectionHeaderWidget(
                    eyebrow: 'ROUTE PACKS',
                    trailingLabel: 'Coming soon',
                  ),

                  const SizedBox(height: 12),

                  // ── 4. Five Route Pack Cards ───────────────────────────────
                  for (int i = 0; i < _packs.length; i++) ...[
                    RoutePackCardWidget(
                      pack: _packs[i],
                    ),
                    if (i < _packs.length - 1)
                      const SizedBox(height: AppColors.cardGap),
                  ],
                ],
              ),
            ),
          ),

          // ── 5. Floating Tactical Bottom Dock (Index 2: Navigation) ─────────
          const Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: CampBottomNav(
                selected: CampTab.navigation,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
