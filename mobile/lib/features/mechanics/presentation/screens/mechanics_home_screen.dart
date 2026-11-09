import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/keyboard_visibility.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../navigation/domain/geocoding_service.dart';
import '../../../navigation/domain/roadside_map_models.dart';
import '../../../navigation/presentation/widgets/topographic_map_canvas.dart';
import '../../controllers/mechanic_controller.dart';
import '../../domain/mechanic_model.dart';
import '../../domain/mechanic_open_status.dart';

import '../widgets/custom_app_bar.dart';
import '../widgets/filter_chips_widget.dart';
import '../widgets/mechanic_card.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/view_toggle_widget.dart';
import 'add_mechanic_screen.dart';

class MechanicsHomeScreen extends StatefulWidget {
  const MechanicsHomeScreen({
    super.key,
    this.currentDateTime,
    this.geocodingService,
  });

  /// Optional fixed time for deterministic testing of opening hours.
  final DateTime? currentDateTime;
  final GeocodingService? geocodingService;

  @override
  State<MechanicsHomeScreen> createState() => _MechanicsHomeScreenState();
}

class _MechanicsHomeScreenState extends State<MechanicsHomeScreen>
    with WidgetsBindingObserver {
  static const Color _mapDarkBg = Color(0xFF141210);

  static const LinearGradient _orangeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.tacticalOrangeLight, AppColors.tacticalOrange],
  );

  bool _isListView = true;
  String _selectedFilter = 'all';
  String _searchQuery = '';
  CampTab _currentTab = CampTab.mechanics;
  final TextEditingController _searchController = TextEditingController();
  late final GeocodingService _geocodingService;
  double? _userLatitude;
  double? _userLongitude;
  late DateTime _screenNow;

  int get _openNowCount {
    return MechanicController.instance.mechanics.where((m) {
      return mechanicOpenStatus(m, _screenNow).isOpen;
    }).length;
  }

  int get _emergencyCount {
    return MechanicController.instance.mechanics.where((m) {
      return m.badgeType == BadgeType.emergency;
    }).length;
  }

  List<Mechanic> get _filteredMechanics {
    final allMechanics = MechanicController.instance.mechanics;
    return allMechanics.where((mechanic) {
      // Filter logic
      if (_selectedFilter == 'open_now') {
        final status = mechanicOpenStatus(mechanic, _screenNow);
        if (!status.isOpen) {
          return false;
        }
      } else if (_selectedFilter == 'emergency') {
        if (mechanic.badgeType != BadgeType.emergency) {
          return false;
        }
      }

      // Search query logic
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesName = mechanic.name.toLowerCase().contains(query);
        final matchesTags1 =
            mechanic.tags1.any((t) => t.toLowerCase().contains(query));
        final matchesTags2 =
            mechanic.tags2.any((t) => t.toLowerCase().contains(query));
        return matchesName || matchesTags1 || matchesTags2;
      }

      return true;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _geocodingService = widget.geocodingService ?? NominatimGeocodingService();
    _screenNow = widget.currentDateTime ?? DateTime.now();
    WidgetsBinding.instance.addObserver(this);
    _fetchLocation();
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _screenNow = widget.currentDateTime ?? DateTime.now();
    });
    await _fetchLocation();
    await MechanicController.instance.load();
  }

  Future<void> _fetchLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _userLatitude = pos.latitude;
          _userLongitude = pos.longitude;
        });
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant MechanicsHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentDateTime != oldWidget.currentDateTime) {
      _screenNow = widget.currentDateTime ?? DateTime.now();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {
        _screenNow = widget.currentDateTime ?? DateTime.now();
      });
    }
  }

  void _navigateToAddMechanic() {
    Navigator.pushNamed(context, CampRoutes.addMechanic);
  }

  void _navigateToEditMechanic(Mechanic mechanic) {
    Navigator.pushNamed(
      context,
      CampRoutes.addMechanic,
      arguments: mechanic,
    );
  }

  void _confirmDeleteMechanic(Mechanic mechanic) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.clay,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Mechanic?', style: AppTextStyles.cardTitle),
        content: Text(
          'Are you sure you want to remove ${mechanic.name} from your saved mechanics?',
          style: AppTextStyles.bodySecondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              MechanicController.instance.deleteMechanic(mechanic.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Removed ${mechanic.name}'),
                  backgroundColor: AppColors.darkCharcoal,
                ),
              );
            },
            child: Text(
              'Delete',
              style: AppTextStyles.body.copyWith(
                color: AppColors.alertRed,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToMapScreen() async {
    setState(() {
      _currentTab = CampTab.navigation;
    });
    await Navigator.pushNamed(
      context,
      CampRoutes.navigationMap,
    );
    if (mounted) {
      // Strictly open Mechanic Screen (Index 3)
      setState(() {
        _currentTab = CampTab.mechanics;
        _isListView = true;
      });
    }
  }

  void _showCallModal(Mechanic mechanic) {
    final phone = (mechanic.phoneNumber ?? mechanic.phone).trim();
    if (phone.isEmpty) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.clay,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'No number saved',
            style: AppTextStyles.cardTitle.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.darkCharcoal,
            ),
          ),
          content: Text(
            'No phone number has been saved for ${mechanic.name}.',
            style: AppTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute<Mechanic>(
                    builder: (_) => AddMechanicScreen(mechanic: mechanic),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.tacticalOrange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add number'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.clay,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.tacticalOrange.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.phone_in_talk_rounded,
                color: AppColors.tacticalOrange,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Call Workshop',
              style: AppTextStyles.cardTitle.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.darkCharcoal,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mechanic.name,
              style: AppTextStyles.itemTitle.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.darkCharcoal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              phone,
              style: AppTextStyles.cardTitle.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.tacticalOrange,
              ),
            ),
            Builder(
              builder: (context) {
                final status = mechanicOpenStatus(mechanic, _screenNow);
                final scheduleText = formatMechanicSchedule(mechanic);
                final text = !status.isNotSet
                    ? status.displayText
                    : (scheduleText ??
                        (mechanic.openStatus.isNotEmpty
                            ? mechanic.openStatus
                            : null));
                if (text == null || text.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Operating: $text',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.mutedText,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.mutedLight,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              launchUrl(
                Uri(scheme: 'tel', path: phone),
                mode: LaunchMode.externalApplication,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.tacticalOrange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Call Now',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRouteModal(Mechanic mechanic) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.clay,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.tacticalOrange.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.navigation_rounded,
                color: AppColors.tacticalOrange,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Navigation Route',
              style: AppTextStyles.cardTitle.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.darkCharcoal,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Routing to: ${mechanic.name}',
              style: AppTextStyles.itemTitle.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.darkCharcoal,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.clayDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.directions_bike_rounded,
                    color: AppColors.tacticalOrange,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        String? distStr;
                        if (mechanic.hasCoordinates &&
                            _userLatitude != null &&
                            _userLongitude != null) {
                          final km = computeStraightLineDistanceKm(
                            lat1: _userLatitude!,
                            lon1: _userLongitude!,
                            lat2: mechanic.latitude!,
                            lon2: mechanic.longitude!,
                          );
                          distStr = formatDistance(km);
                        }
                        final loc = mechanic.address ??
                            (mechanic.durationOrLocation.isNotEmpty &&
                                    mechanic.durationOrLocation != 'Nearby' &&
                                    mechanic.durationOrLocation != 'Local Workshop' &&
                                    !mechanic.durationOrLocation.contains('min')
                                ? mechanic.durationOrLocation
                                : null);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (distStr != null)
                              Text(
                                distStr,
                                style: AppTextStyles.body.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: AppColors.darkCharcoal,
                                ),
                              ),
                            if (loc != null)
                              Text(
                                'Location: $loc',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.mutedText,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Dismiss',
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.mutedLight,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => _handleStartGuidance(ctx, mechanic),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.tacticalOrange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Start Guidance',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleStartGuidance(
    BuildContext dialogCtx,
    Mechanic mechanic,
  ) async {
    Navigator.pop(dialogCtx);

    // 1. Shop with saved coordinates
    if (mechanic.hasCoordinates) {
      Navigator.pushNamed(
        context,
        CampRoutes.navigationMap,
        arguments: PlaceSearchResult(
          name: mechanic.name,
          displayName: mechanic.address ?? mechanic.name,
          location: LatLng(mechanic.latitude!, mechanic.longitude!),
        ),
      );
      return;
    }

    // 2. Shop with only a text address
    final rawAddress = mechanic.address?.trim() ?? '';
    final fallbackLoc = (mechanic.durationOrLocation.isNotEmpty &&
            mechanic.durationOrLocation != 'Nearby' &&
            mechanic.durationOrLocation != 'Local Workshop' &&
            !mechanic.durationOrLocation.contains('min'))
        ? mechanic.durationOrLocation.trim()
        : '';
    final addressQuery = rawAddress.isNotEmpty ? rawAddress : fallbackLoc;

    if (addressQuery.isNotEmpty) {
      // Look the address up once through GeocodingService
      List<PlaceSearchResult> results = [];
      try {
        results = await _geocodingService.search(addressQuery);
      } catch (_) {}

      if (!mounted) return;

      if (results.isNotEmpty) {
        final found = results.first;
        // Show "Found: <result>" with Confirm and Cancel.
        showDialog<void>(
          context: context,
          builder: (foundCtx) => AlertDialog(
            backgroundColor: AppColors.clay,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Text(
              'Found: ${found.displayName}',
              style: AppTextStyles.cardTitle.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.darkCharcoal,
              ),
            ),
            content: Text(
              'Save coordinates and start route guidance to ${mechanic.name}?',
              style: AppTextStyles.body.copyWith(
                fontSize: 14,
                color: AppColors.mutedText,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(foundCtx),
                child: Text(
                  'Cancel',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedLight,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(foundCtx);
                  final updatedMech = mechanic.copyWith(
                    latitude: found.location.latitude,
                    longitude: found.location.longitude,
                  );
                  MechanicController.instance.updateMechanic(updatedMech);
                  if (mounted) {
                    Navigator.pushNamed(
                      context,
                      CampRoutes.navigationMap,
                      arguments: PlaceSearchResult(
                        name: updatedMech.name,
                        displayName: updatedMech.address ?? updatedMech.name,
                        location: found.location,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.tacticalOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Confirm'),
              ),
            ],
          ),
        );
      } else {
        // Nothing found: "Couldn't find this address. Add the shop's location." with a button to edit the shop.
        showDialog<void>(
          context: context,
          builder: (notFoundCtx) => AlertDialog(
            backgroundColor: AppColors.clay,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            content: Text(
              "Couldn't find this address. Add the shop's location.",
              style: AppTextStyles.body.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.darkCharcoal,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(notFoundCtx),
                child: Text(
                  'Cancel',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedLight,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(notFoundCtx);
                  _navigateToEditMechanic(mechanic);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.tacticalOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Edit Shop'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // 3. No address and no coordinates:
    // No route. Message "This shop has no location saved." with an Edit button.
    showDialog<void>(
      context: context,
      builder: (noLocCtx) => AlertDialog(
        backgroundColor: AppColors.clay,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        content: Text(
          'This shop has no location saved.',
          style: AppTextStyles.body.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.darkCharcoal,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(noLocCtx),
            child: Text(
              'Cancel',
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.mutedLight,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(noLocCtx);
              _navigateToEditMechanic(mechanic);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.tacticalOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Edit Shop'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MechanicController.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.clay,
          body: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Column(
                  children: [
                    // Custom AppBar with Recessed Search & Filter
                    CustomAppBar(
                      onBackTap: () => Navigator.pop(context),
                    ),

                    // Tactile Skeuomorphic Search Bar
                    SearchBarWidget(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),

                    // View Toggle (List View vs Map View)
                    ViewToggleWidget(
                      isListView: _isListView,
                      onToggle: (isList) {
                        setState(() {
                          _isListView = isList;
                          _currentTab = CampTab.mechanics;
                        });
                      },
                    ),

                    // Filter Chips
                    FilterChipsWidget(
                      selectedFilter: _selectedFilter,
                      allCount: MechanicController.instance.mechanics.length,
                      openNowCount: _openNowCount,
                      emergencyCount: _emergencyCount,
                      onFilterSelected: (filterId) {
                        setState(() {
                          _selectedFilter = filterId;
                        });
                      },
                    ),

                    const SizedBox(height: 8),

                    // Content View (List vs Map)
                    Expanded(
                      child: _isListView ? _buildListView() : _buildMapView(),
                    ),
                  ],
                ),

                // Floating "+ Add Mechanic" Button (FAB bottom: 96, does not overlap bottom dock at bottom: 24)
                // Automatically hides when keyboard is open via KeyboardVisibilityBuilder
                if (_currentTab == CampTab.mechanics || _isListView)
                  Positioned(
                    right: 16,
                    bottom: 96,
                    child: KeyboardVisibilityBuilder(
                      builder: (context, isKeyboardVisible, _) {
                        if (isKeyboardVisible) return const SizedBox.shrink();
                        return GestureDetector(
                          onTap: _navigateToAddMechanic,
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            decoration: BoxDecoration(
                              gradient: _orangeGradient,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: AppColors.orangeGlow,
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  '+ Add Mechanic',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                // Floating Bottom Navigation Dock (Centered, bottom: 24)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 24,
                  child: Center(
                    child: CampBottomNav(
                      selected: CampTab.mechanics,
                      onTabChanged: (tab) {
                        if (tab == CampTab.mechanics) {
                          setState(() {
                            _currentTab = CampTab.mechanics;
                            _isListView = true;
                          });
                        } else {
                          CampBottomNav.navigateToTab(context, tab, currentTab: CampTab.mechanics);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildListView() {
    final mechanics = _filteredMechanics;

    if (mechanics.isEmpty) {
      return RefreshIndicator(
        color: AppColors.tacticalOrange,
        onRefresh: _handleRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          children: [
            const SizedBox(height: 60),
            CampEmptyState(
              icon: Icons.handyman_rounded,
              message: _searchQuery.isNotEmpty
                  ? 'No mechanics match "$_searchQuery"'
                  : 'No mechanics saved yet',
              ctaLabel: '+ Add Mechanic',
              onCta: _navigateToAddMechanic,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.tacticalOrange,
      onRefresh: _handleRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 180),
        itemCount: mechanics.length,
        itemBuilder: (context, index) {
          final mechanic = mechanics[index];
          return MechanicCard(
            mechanic: mechanic,
            userLatitude: _userLatitude,
            userLongitude: _userLongitude,
            onTap: () => showMechanicDetailSheet(
              context,
              mechanic,
              userLatitude: _userLatitude,
              userLongitude: _userLongitude,
              onCallShop: () => _showCallModal(mechanic),
              onRouteGps: () => _showRouteModal(mechanic),
              onEdit: () => _navigateToEditMechanic(mechanic),
              onDelete: () => _confirmDeleteMechanic(mechanic),
            ),
            onCallShop: () => _showCallModal(mechanic),
            onRouteGps: () => _showRouteModal(mechanic),
            onEdit: () => _navigateToEditMechanic(mechanic),
            onDelete: () => _confirmDeleteMechanic(mechanic),
          );
        },
      ),
    );
  }

  Widget _buildMapView() {
    final mechanicsWithCoords = MechanicController.instance.mechanics
        .where((m) => m.hasCoordinates)
        .map((m) => RoadsideMechanic(
              id: m.id,
              name: m.name,
              vehicleType: 'Workshop',
              distance: m.distance ?? '',
              eta: m.openStatus,
              rating: m.rating,
              reviews: m.reviewCount,
              phone: m.phone,
              location: LatLng(m.latitude!, m.longitude!),
              isMobileVan: false,
              isEmergencyVerified: m.badgeType == BadgeType.emergency,
              capabilities: m.tags1,
              supportedBikes: const ['Universal'],
              openHours: m.openStatus,
            ))
        .toList();

    final center = _userLatitude != null && _userLongitude != null
        ? LatLng(_userLatitude!, _userLongitude!)
        : (mechanicsWithCoords.isNotEmpty
            ? mechanicsWithCoords.first.location
            : const LatLng(31.5204, 74.3587));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      decoration: BoxDecoration(
        color: _mapDarkBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: AppColors.dockShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: TopographicMapCanvas(
              initialCenter: center,
              mechanics: mechanicsWithCoords,
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: GestureDetector(
              onTap: _navigateToMapScreen,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  gradient: _orangeGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppColors.orangeGlow,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.navigation_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Open Full Expedition Route',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
