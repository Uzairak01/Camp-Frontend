import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/roadside_map_models.dart';

class TopographicMapCanvas extends StatefulWidget {

  const TopographicMapCanvas({
    super.key,
    this.onOpenGoogleMaps,
    this.onToggle3D,
    this.onToggleLayers,
    this.onRecenter,
    this.selectedFilter = 'all',
    this.userRole = 'driver',
    this.initialCenter,
    this.locationName,
    this.mechanics = const [],
    this.strandedIncidents = const [],
    this.supplyCaches = const [],
    this.activeRescueRoute = const [],
    this.selectedMechanic,
    this.selectedIncident,
    this.onMechanicTapped,
    this.onIncidentTapped,
    this.onSupplyCacheTapped,
    this.onLocationChanged,
    this.onLocationNameChanged,
  });
  final VoidCallback? onOpenGoogleMaps;
  final VoidCallback? onToggle3D;
  final VoidCallback? onToggleLayers;
  final VoidCallback? onRecenter;
  final String? selectedFilter;
  final String userRole; // 'driver' or 'mechanic'
  final LatLng? initialCenter;
  final String? locationName;
  final List<RoadsideMechanic> mechanics;
  final List<StrandedIncident> strandedIncidents;
  final List<RoadsideSupplyCache> supplyCaches;
  final List<LatLng> activeRescueRoute;
  final RoadsideMechanic? selectedMechanic;
  final StrandedIncident? selectedIncident;
  final ValueChanged<RoadsideMechanic>? onMechanicTapped;
  final ValueChanged<StrandedIncident>? onIncidentTapped;
  final ValueChanged<RoadsideSupplyCache>? onSupplyCacheTapped;
  final ValueChanged<LatLng>? onLocationChanged;
  final ValueChanged<String>? onLocationNameChanged;

  @override
  State<TopographicMapCanvas> createState() => _TopographicMapCanvasState();
}

class _TopographicMapCanvasState extends State<TopographicMapCanvas>
    with SingleTickerProviderStateMixin {
  static const Color _mapDarkBg = Color(0xFF141210);

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final MapController _mapController = MapController();

  int _currentLayer = 0; // 0 = OpenStreetMap Standard, 1 = OpenTopoMap (OSM Topo), 2 = OpenStreetMap Humanitarian
  bool _is3DMode = false;
  bool _isMapReady = false;

  String get _currentTileUrl {
    switch (_currentLayer) {
      case 0:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case 1:
        return 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
      case 2:
        return 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png';
      default:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
  }

  String get _currentLayerName {
    switch (_currentLayer) {
      case 0:
        return 'OpenStreetMap Standard';
      case 1:
        return 'OpenTopoMap (OSM Topo)';
      case 2:
        return 'OpenStreetMap Humanitarian';
      default:
        return 'OpenStreetMap';
    }
  }

  late LatLng _centerCoord;
  late String _locationTitle;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.35).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _centerCoord = widget.initialCenter ?? const LatLng(31.5204, 74.3587);
    _locationTitle = widget.locationName ?? '';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect system-level "disable animations" setting (also set by tests).
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulseController.value = 1.0;
    } else if (!_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant TopographicMapCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.initialCenter != null &&
        (widget.initialCenter != oldWidget.initialCenter ||
            widget.initialCenter != _centerCoord)) {
      setState(() {
        _centerCoord = widget.initialCenter!;
        if (widget.locationName != null) {
          _locationTitle = widget.locationName!;
        }
      });
      if (_isMapReady) {
        try {
          _mapController.move(_centerCoord, 12.5);
        } catch (_) {}
      }
    } else if (widget.locationName != null &&
        widget.locationName != oldWidget.locationName) {
      setState(() {
        _locationTitle = widget.locationName!;
      });
    }

    // Focus on selected incident or mechanic if changed
    if (widget.selectedIncident != null &&
        widget.selectedIncident != oldWidget.selectedIncident) {
      if (_isMapReady) {
        try {
          _mapController.move(widget.selectedIncident!.location, 13.5);
        } catch (_) {}
      }
    } else if (widget.selectedMechanic != null &&
        widget.selectedMechanic != oldWidget.selectedMechanic) {
      if (_isMapReady) {
        try {
          _mapController.move(widget.selectedMechanic!.location, 13.5);
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _handleMapTap(LatLng tappedPoint) {
    setState(() {
      _centerCoord = tappedPoint;
      _locationTitle =
          'Waypoint (${tappedPoint.latitude.toStringAsFixed(3)}°, ${tappedPoint.longitude.toStringAsFixed(3)}°)';
    });

    widget.onLocationChanged?.call(tappedPoint);
    widget.onLocationNameChanged?.call(_locationTitle);
  }

  void _recenterMap() {
    if (!_isMapReady) return;
    try {
      _mapController.move(_centerCoord, 12.5);
    } catch (_) {}
    widget.onRecenter?.call();
  }

  void _zoomIn() {
    if (!_isMapReady) return;
    try {
      final currentZoom = _mapController.camera.zoom;
      _mapController.move(_mapController.camera.center, currentZoom + 1.0);
    } catch (_) {}
  }

  void _zoomOut() {
    if (!_isMapReady) return;
    try {
      final currentZoom = _mapController.camera.zoom;
      _mapController.move(_mapController.camera.center, currentZoom - 1.0);
    } catch (_) {}
  }

  void _toggleMapLayer() {
    setState(() {
      _currentLayer = (_currentLayer + 1) % 3;
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.layers_rounded,
                color: AppColors.tacticalOrange, size: 18),
            const SizedBox(width: 8),
            Text(
              'Switched to $_currentLayerName',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        backgroundColor: AppColors.darkCharcoal,
        duration: const Duration(milliseconds: 1100),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    widget.onToggleLayers?.call();
  }

  void _toggle3D() {
    setState(() {
      _is3DMode = !_is3DMode;
    });
    widget.onToggle3D?.call();
  }

  bool _shouldShowMechanics() {
    final f = widget.selectedFilter ?? 'all';
    return f == 'all' || f == 'mechanics';
  }

  bool _shouldShowStranded() {
    final f = widget.selectedFilter ?? 'all';
    return f == 'all' || f == 'stranded';
  }

  bool _shouldShowSupply() {
    final f = widget.selectedFilter ?? 'all';
    return f == 'all' || f == 'fuel' || f == 'workshops';
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];

    // 1. User Location Pin (Expedition Base / Driver GPS)
    markers.add(
      Marker(
        point: _centerCoord,
        width: 170,
        height: 54,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.darkCharcoal,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.tacticalOrange,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.my_location_rounded,
                    color: AppColors.tacticalOrange,
                    size: 11,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      widget.userRole == 'driver'
                          ? 'MY VEHICLE LOCATION'
                          : 'RESCUE UNIT BASE',
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.overline.copyWith(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  width: 15,
                  height: 15,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.tacticalOrange,
                    border: Border.all(
                      color: Colors.white,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.tacticalOrange.withValues(
                          alpha:
                              (0.8 * _pulseAnimation.value).clamp(0.0, 1.0),
                        ),
                        blurRadius: 10 * _pulseAnimation.value,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );

    // 2. Active Stranded Drivers (SOS Beacons)
    if (_shouldShowStranded()) {
      for (final incident in widget.strandedIncidents) {
        final isSelected = widget.selectedIncident?.id == incident.id;
        markers.add(
          Marker(
            point: incident.location,
            width: 180,
            height: 60,
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () => widget.onIncidentTapped?.call(incident),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF181513),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: incident.severityColor,
                        width: isSelected ? 2.0 : 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: incident.severityColor
                              .withValues(alpha: isSelected ? 0.6 : 0.35),
                          blurRadius: isSelected ? 12 : 6,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          incident.categoryIcon,
                          color: incident.severityColor,
                          size: 13,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'SOS • ${incident.vehicleModel.split(' ').take(2).join(' ')}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: incident.severityColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Container(
                        width: isSelected ? 20 : 16,
                        height: isSelected ? 20 : 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: incident.severityColor,
                          border: Border.all(
                            color: Colors.white,
                            width: 2.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: incident.severityColor.withValues(
                                alpha: (0.9 * _pulseAnimation.value)
                                    .clamp(0.0, 1.0),
                              ),
                              blurRadius: 14 * _pulseAnimation.value,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.priority_high_rounded,
                            color: Colors.white,
                            size: 10,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    // 3. Mobile Mechanics & Rescue Units
    if (_shouldShowMechanics()) {
      for (final mechanic in widget.mechanics) {
        final isSelected = widget.selectedMechanic?.id == mechanic.id;
        markers.add(
          Marker(
            point: mechanic.location,
            width: 175,
            height: 56,
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () => widget.onMechanicTapped?.call(mechanic),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.darkCharcoal,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.tacticalOrange
                            : AppColors.statusGreen,
                        width: isSelected ? 2.0 : 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.statusGreen,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            mechanic.name.length > 15
                                ? '${mechanic.name.substring(0, 13)}..'
                                : mechanic.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          mechanic.eta.split(' ').first,
                          style: const TextStyle(
                            color: AppColors.statusYellow,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? AppColors.tacticalOrange
                          : const Color(0xFF047857),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.statusGreen.withValues(alpha: 0.6),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.build_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    // 4. Roadside Supply & Tools Depots
    if (_shouldShowSupply()) {
      for (final cache in widget.supplyCaches) {
        markers.add(
          Marker(
            point: cache.location,
            width: 155,
            height: 52,
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () => widget.onSupplyCacheTapped?.call(cache),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.darkCharcoal,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.statusYellow,
                        width: 1.2,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_gas_station_rounded,
                          color: AppColors.statusYellow,
                          size: 11,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'PIT / TOOLS',
                          style: TextStyle(
                            color: Color(0xFFFDE68A),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFD97706),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.handyman_rounded,
                        color: Colors.white,
                        size: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return ClipRect(
      child: Container(
        color: _mapDarkBg,
        child: Stack(
          children: [
            // 1. Real Interactive Flutter Map
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _centerCoord,
                  initialZoom: 12.5,
                  minZoom: 4.0,
                  maxZoom: 18.0,
                  backgroundColor: _mapDarkBg,
                  onTap: (tapPosition, point) => _handleMapTap(point),
                  onMapReady: () {
                    _isMapReady = true;
                  },
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                ),
                children: [
                  // Official OpenStreetMap TileLayer (OSM Standard / OpenTopoMap / OSM Humanitarian)
                  TileLayer(
                    urlTemplate: _currentTileUrl,
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'com.camp.mobile',
                    maxNativeZoom: 19,
                    maxZoom: 19,
                  ),

                  // Rescue Dispatch Route Polyline
                  if (widget.activeRescueRoute.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        // Outer Ambient Glowing Aura
                        Polyline(
                          points: widget.activeRescueRoute,
                          strokeWidth: 10.0,
                          color: AppColors.tacticalOrange.withValues(alpha: 0.40),
                        ),
                        // Vibrant Solid Rescue Corridor
                        Polyline(
                          points: widget.activeRescueRoute,
                          strokeWidth: 4.5,
                          color: AppColors.tacticalOrange,
                        ),
                        // Contrasting Center Guidance Stripe
                        Polyline(
                          points: widget.activeRescueRoute,
                          strokeWidth: 1.5,
                          color: const Color(0xFFFFF7ED),
                        ),
                      ],
                    ),

                  // Markers Layer
                  MarkerLayer(markers: markers),
                ],
              ),
            ),

            // 2. Top-Left Google Maps Export Button
            Positioned(
              top: 14,
              left: 14,
              child: GestureDetector(
                onTap: widget.onOpenGoogleMaps,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.clay,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.clayDark,
                      width: 1,
                    ),
                    boxShadow: AppColors.skeuRaisedSmall,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.map_rounded,
                        color: AppColors.tacticalOrangeDark,
                        size: 15,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Google Maps',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.darkCharcoal,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.arrow_outward_rounded,
                        color: AppColors.mutedText,
                        size: 13,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Top-Right Floating Controls (3D, Layer toggle, Recenter, Zoom)
            Positioned(
              top: 14,
              right: 14,
              child: Column(
                children: [
                  // 3D Terrain Toggle
                  _buildCircleButton(
                    onTap: _toggle3D,
                    isActive: _is3DMode,
                    child: const Text(
                      '3D',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Style Layers Toggle
                  _buildCircleButton(
                    onTap: _toggleMapLayer,
                    isActive: _currentLayer == 1,
                    child: Icon(
                      Icons.layers_rounded,
                      color:
                          _currentLayer == 1 ? Colors.white : const Color(0xFFE7E5E4),
                      size: 18,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // GPS Recenter Button
                  _buildCircleButton(
                    onTap: _recenterMap,
                    isActive: false,
                    child: const Icon(
                      Icons.my_location_rounded,
                      color: AppColors.tacticalOrange,
                      size: 18,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Zoom In
                  _buildCircleButton(
                    onTap: _zoomIn,
                    isActive: false,
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Zoom Out
                  _buildCircleButton(
                    onTap: _zoomOut,
                    isActive: false,
                    child: const Icon(
                      Icons.remove_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),

            // 5. Official OpenStreetMap Attribution Badge (Bottom Right)
            Positioned(
              bottom: 124,
              right: 14,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF181513).withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white12,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.public_rounded,
                      color: AppColors.tacticalOrange,
                      size: 11,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _currentLayer == 0
                          ? '© OpenStreetMap'
                          : (_currentLayer == 1
                              ? '© OpenTopoMap (OSM)'
                              : '© OSM Humanitarian'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required VoidCallback onTap,
    required bool isActive,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive
              ? AppColors.tacticalOrange
              : const Color(0xFF262320).withValues(alpha: 0.90),
          border: Border.all(
            color: isActive
                ? AppColors.tacticalOrangeLight
                : Colors.white.withValues(alpha: 0.15),
            width: 1.2,
          ),
          boxShadow: AppColors.skeuRaisedSmall,
        ),
        child: Center(child: child),
      ),
    );
  }
}
