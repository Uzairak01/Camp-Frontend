import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/weather_service.dart';

/// Weather Detail Screen
///
/// Displays current conditions strictly from live API ingestion when WEATHER_API_KEY is defined.
/// If the key is missing or the request fails, displays a clear "Weather unavailable" state
/// with an action to retry.
///
/// Note: Calling a third-party weather API directly from the mobile client is temporary;
/// a backend proxy (via Firebase / Cloud Functions) is the proper long-term architecture
/// to safeguard API keys, rate limits, and caching (parked for the Firebase phase).
class WeatherDetailScreen extends StatefulWidget {
  const WeatherDetailScreen({super.key});

  @override
  State<WeatherDetailScreen> createState() => _WeatherDetailScreenState();
}

class _WeatherDetailScreenState extends State<WeatherDetailScreen> {
  WeatherData? _weatherData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    setState(() {
      _isLoading = true;
    });

    try {
      Position? position;
      if (WeatherProvider.isConfigured) {
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
      }

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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.clay,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ── App Bar ───────────────────────────────────────────────────
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: CampAppBar(
                  leading: CampAppBarLeading.back,
                  actionText: 'WEATHER',
                ),
              ),

              // ── Body ──────────────────────────────────────────────────────
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.tacticalOrange,
                        ),
                      )
                    : ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                        children: [
                          if (hasData) ...[
                            _buildLiveWeatherHero(context, _weatherData!),
                            const SizedBox(height: 16),
                            _buildMetricsCard(_weatherData!),
                          ] else ...[
                            _buildUnavailableCard(),
                          ],
                          const SizedBox(height: 16),
                          _buildApiNotice(hasKey: WeatherProvider.apiKey.isNotEmpty),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnavailableCard() {
    return CampCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.clayDark,
              shape: BoxShape.circle,
              boxShadow: AppColors.skeuRaisedSmall,
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              color: AppColors.mutedText,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Weather unavailable',
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.darkCharcoal,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            WeatherProvider.apiKey.isEmpty
                ? 'Weather data requires a WEATHER_API_KEY environment configuration or network connection.'
                : 'Unable to reach the weather provider. Check connection and retry.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.mutedText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Retry',
            icon: Icons.refresh_rounded,
            onTap: _fetchWeather,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveWeatherHero(BuildContext context, WeatherData data) {
    return CockpitHeroCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CURRENT AREA',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.tacticalOrange,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Semantics(
                        label: data.locationName ??
                            (WeatherProvider.currentLocationLabel.isNotEmpty
                                ? WeatherProvider.currentLocationLabel
                                : 'Local Area'),
                        child: Text(
                          data.locationName ??
                              (WeatherProvider.currentLocationLabel.isNotEmpty
                                  ? WeatherProvider.currentLocationLabel
                                  : 'Local Area'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.wb_sunny_rounded,
                      color: AppColors.statusYellow,
                      size: 26,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${data.tempInt}°',
                  style: GoogleFonts.manrope(
                    fontSize: 54,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.condition,
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFDE68A),
                      ),
                    ),
                    if (data.highC != null && data.lowC != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        'High: ${data.highC!.round()}°C • Low: ${data.lowC!.round()}°C',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsCard(WeatherData data) {
    return CampCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          if (data.windSpeedKmh != null)
            _metricItem(
              Icons.air_rounded,
              'WIND',
              '${data.windSpeedKmh!.round()} km/h',
            ),
          if (data.humidity != null)
            _metricItem(
              Icons.water_drop_outlined,
              'HUMIDITY',
              '${data.humidity}%',
            ),
          _metricItem(
            Icons.thermostat_rounded,
            'TEMP',
            '${data.temperatureC.toStringAsFixed(1)}°C',
          ),
        ],
      ),
    );
  }

  Widget _metricItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppColors.terracotta),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: AppColors.mutedText,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.darkCharcoal,
          ),
        ),
      ],
    );
  }

  Widget _buildApiNotice({required bool hasKey}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.clayDark,
        borderRadius: BorderRadius.circular(AppColors.radiusTile),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.tacticalOrange,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasKey
                  ? 'Weather service active via WEATHER_API_KEY environment configuration.'
                  : 'No weather API key configured. Provide --dart-define=WEATHER_API_KEY at build time for live weather data. A backend proxy will serve this in the Firebase phase.',
              style: GoogleFonts.manrope(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: AppColors.mutedText,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
