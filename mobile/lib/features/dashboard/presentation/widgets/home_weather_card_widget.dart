import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/weather_service.dart';

/// Weather advisory card displayed on Home outside the Recent activity feed.
/// Shows live temperature and condition when WEATHER_API_KEY is configured.
/// Otherwise renders a clean "Weather unavailable" state without fabricated numbers.
/// Tapping navigates to [WeatherDetailScreen].
class HomeWeatherCardWidget extends StatefulWidget {
  const HomeWeatherCardWidget({
    super.key,
    this.onTap,
  });

  final VoidCallback? onTap;

  @override
  State<HomeWeatherCardWidget> createState() => _HomeWeatherCardWidgetState();
}

class _HomeWeatherCardWidgetState extends State<HomeWeatherCardWidget> {
  WeatherData? _weatherData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (WeatherProvider.isConfigured) {
      _fetchWeather();
    }
  }

  Future<void> _fetchWeather() async {
    setState(() => _isLoading = true);

    try {
      Position? position;
      try {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled()
            .timeout(const Duration(milliseconds: 400), onTimeout: () => false);
        if (serviceEnabled) {
          final permission = await Geolocator.checkPermission()
              .timeout(const Duration(milliseconds: 400), onTimeout: () => LocationPermission.denied);
          if (permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse) {
            position = await Geolocator.getLastKnownPosition()
                .timeout(const Duration(milliseconds: 400), onTimeout: () => null);
          }
        }
      } catch (_) {}

      final data = await WeatherProvider.service.getWeather(
        latitude: position?.latitude ?? 33.6844,
        longitude: position?.longitude ?? 73.0479,
      );

      if (mounted) {
        setState(() {
          _weatherData = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _weatherData = null;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasData = _weatherData != null;
    final title = hasData
        ? '${_weatherData!.tempInt}°C • ${_weatherData!.condition}'
        : 'Weather';
    final description = hasData
        ? (_weatherData!.locationName != null
            ? '${_weatherData!.locationName} • Tap for forecast'
            : 'Tap for full weather forecast')
        : 'Weather unavailable';

    return CampCard(
      borderRadius: AppColors.radiusTile + 2,
      child: InkWell(
        onTap: widget.onTap ??
            () => Navigator.of(context).pushNamed(CampRoutes.weatherDetail),
        borderRadius: BorderRadius.circular(AppColors.radiusTile + 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconTile(
              icon: hasData ? Icons.wb_sunny_rounded : Icons.cloud_outlined,
              iconColor: const Color(0xFFD97706),
              size: 42,
              borderRadius: 14,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: AppTextStyles.itemTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_isLoading)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.tacticalOrange,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: AppTextStyles.bodySecondary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.mutedLight,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
