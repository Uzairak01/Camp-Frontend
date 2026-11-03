import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../garage/controllers/active_bike_controller.dart';
import '../../../maintenance/controllers/maintenance_controller.dart';
import '../../../navigation/controllers/current_place_controller.dart';
import '../../controllers/profile_controller.dart';
import '../../domain/weather_service.dart';

/// Dark Rider Banner wrapped in a soft tactile bezel ring — Cockpit Hero Card.
/// Single source of truth: reads from [ProfileController], [ActiveBikeController],
/// and [CurrentPlaceController].
/// Displays live clock (minute timer), shared location label from [CurrentPlaceController],
/// and weather data from [WeatherProvider].
class CockpitStatusCardWidget extends StatefulWidget {
  /// Creates a [CockpitStatusCardWidget] hero card.
  const CockpitStatusCardWidget({
    super.key,
    this.avatarUrl,
    this.onCtaPressed,
    this.onProfilePressed,
  });

  /// Remote image URL for the rider's avatar.
  final String? avatarUrl;

  /// Callback when the primary Cockpit CTA is pressed.
  final VoidCallback? onCtaPressed;

  /// Callback when the rider avatar is tapped to open profile.
  final VoidCallback? onProfilePressed;

  @override
  State<CockpitStatusCardWidget> createState() => _CockpitStatusCardWidgetState();
}

class _CockpitStatusCardWidgetState extends State<CockpitStatusCardWidget> {
  Timer? _minuteTimer;
  String _timeString = '';
  WeatherData? _weatherData;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _minuteTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updateTime();
    });
    _fetchWeather();
  }

  @override
  void dispose() {
    _minuteTimer?.cancel();
    super.dispose();
  }

  void _updateTime() {
    final now = DateTime.now();
    final hour = now.hour == 0 ? 12 : (now.hour > 12 ? now.hour - 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final ampm = now.hour >= 12 ? 'PM' : 'AM';
    final formatted = '$hour:$minute $ampm';
    if (!mounted) {
      _timeString = formatted;
      return;
    }
    if (_timeString != formatted) {
      setState(() {
        _timeString = formatted;
      });
    }
  }

  /// Fetches weather for the rider's current or last known position.
  /// Does not perform its own geocoding; location naming is owned by [CurrentPlaceController].
  Future<void> _fetchWeather() async {
    try {
      final pos = CurrentPlaceController.instance.lastKnownPosition;
      final lat = pos?.latitude ?? 33.6844;
      final lon = pos?.longitude ?? 73.0479;

      // Sync the shared location label to WeatherProvider
      WeatherProvider.currentLocationLabel =
          CurrentPlaceController.instance.displayLabel;

      final weather = await WeatherProvider.service.getWeather(
        latitude: lat,
        longitude: lon,
      );
      if (mounted) {
        setState(() {
          _weatherData = weather;
        });
      }
    } catch (_) {
      // Gracefully retain weather unavailable state
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ProfileController.instance,
        ActiveBikeController.instance,
        MaintenanceController.instance,
        CurrentPlaceController.instance,
      ]),
      builder: (context, _) {
        final profile = ProfileController.instance;
        final riderName = profile.fullName;
        final riderFirstName = profile.firstName;
        final activeBike = ActiveBikeController.instance.activeBike;
        final currentPlace = CurrentPlaceController.instance;
        final locationLabel = currentPlace.displayLabel;

        // Keep WeatherProvider synchronized with the shared place label
        WeatherProvider.currentLocationLabel = locationLabel;

        Widget avatarWidget;
        if (profile.avatarPath != null && profile.avatarPath!.isNotEmpty) {
          final file = File(profile.avatarPath!);
          if (file.existsSync()) {
            avatarWidget = ClipOval(
              child: Image.file(file, width: 52, height: 52, fit: BoxFit.cover),
            );
          } else {
            avatarWidget = Center(
              child: Text(
                riderFirstName.isNotEmpty ? riderFirstName[0] : 'R',
                style: GoogleFonts.manrope(
                  color: const Color(0xFFFDE68A),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            );
          }
        } else if (widget.avatarUrl != null) {
          avatarWidget = CircleAvatar(
            radius: 26,
            backgroundImage: NetworkImage(widget.avatarUrl!),
          );
        } else {
          avatarWidget = Center(
            child: Text(
              riderFirstName.isNotEmpty ? riderFirstName : 'Rider',
              style: GoogleFonts.manrope(
                color: const Color(0xFFFDE68A),
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          );
        }

        final weatherText = _weatherData != null
            ? '${_weatherData!.tempInt}° • ${_weatherData!.condition}'
            : 'Weather unavailable';

        return CockpitHeroCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Section: Avatar + Rider Info ─────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    GestureDetector(
                      onTap: widget.onProfilePressed,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.statusYellow,
                                width: 2.5,
                              ),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4A3223), Color(0xFF2B1A10)],
                              ),
                            ),
                            child: avatarWidget,
                          ),
                          Positioned(
                            bottom: -1,
                            right: -1,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF0F172A),
                              ),
                              child: const Icon(
                                Icons.check_circle_rounded,
                                size: 13,
                                color: AppColors.statusYellow,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Rider info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            riderName,
                            style: GoogleFonts.manrope(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Builder(
                            builder: (context) {
                              if (activeBike == null) {
                                return Text(
                                  'No Active Motorcycle',
                                  style: GoogleFonts.manrope(
                                    color: const Color(0xFF94A3B8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                );
                              }
                              final hasData = MaintenanceController.instance.hasMaintenanceData(activeBike);
                              String bikeLine = 'Active Rig • ${activeBike.name}';
                              if (hasData) {
                                final dueCount = MaintenanceController.instance.countDueItems(activeBike.id);
                                final status = dueCount > 0
                                    ? '$dueCount ${dueCount == 1 ? 'item' : 'items'} due'
                                    : 'All up to date';
                                bikeLine = 'Active Rig • ${activeBike.name} • $status';
                              }
                              return Text(
                                bikeLine,
                                style: GoogleFonts.manrope(
                                  color: const Color(0xFF94A3B8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Status Tag Pills: Time, Location, Weather, Distance ───────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _darkPill(Icons.access_time_rounded, _timeString),
                    _darkPill(
                      Icons.location_on_rounded,
                      locationLabel,
                      onTap: currentPlace.isLocationOff
                          ? () => currentPlace.showLocationOffHint(context)
                          : () => Navigator.of(context)
                              .pushNamed(CampRoutes.navigationMap),
                    ),
                    _darkPill(
                      Icons.wb_sunny_rounded,
                      weatherText,
                      onTap: () => Navigator.of(context)
                          .pushNamed(CampRoutes.weatherDetail),
                    ),
                    if (activeBike != null)
                      _darkPill(
                        Icons.two_wheeler_rounded,
                        '${activeBike.odometerKm} km logged',
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── CTA Banner ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: GestureDetector(
                  onTap: widget.onCtaPressed,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE89A3C), Color(0xFFD48226)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD48226).withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.navigation_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'CAMP NAVIGATION',
                                style: GoogleFonts.manrope(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              Text(
                                'Explore offline routes & topo maps',
                                style: GoogleFonts.manrope(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _darkPill(IconData icon, String label, {VoidCallback? onTap}) {
    final pillContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.statusYellow),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              color: const Color(0xFFE5E7EB),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: pillContent,
      );
    }
    return pillContent;
  }
}
