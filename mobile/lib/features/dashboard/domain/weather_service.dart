import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Weather snapshot data model ready for real API ingestion.
class WeatherData {
  const WeatherData({
    required this.temperatureC,
    required this.condition,
    this.highC,
    this.lowC,
    this.windSpeedKmh,
    this.windDirection,
    this.humidity,
    this.locationName,
  });

  final double temperatureC;
  final String condition;
  final double? highC;
  final double? lowC;
  final double? windSpeedKmh;
  final String? windDirection;
  final int? humidity;
  final String? locationName;

  int get tempInt => temperatureC.round();
}

/// Abstract weather service contract.
abstract class WeatherService {
  Future<WeatherData?> getWeather({double? latitude, double? longitude});
}

/// Default placeholder returning null when no API key is provided or request fails.
class PlaceholderWeatherService implements WeatherService {
  const PlaceholderWeatherService();

  @override
  Future<WeatherData?> getWeather({double? latitude, double? longitude}) async {
    return null;
  }
}

/// Real weather service client for OpenWeatherMap when WEATHER_API_KEY is defined.
///
/// Note: Calling a third-party weather API directly from the mobile client is a
/// temporary setup for development. A backend proxy (e.g. Cloud Functions / Firebase)
/// is the proper long-term architecture to safeguard secrets and rate limits,
/// which is parked for the upcoming Firebase phase.
class LiveWeatherService implements WeatherService {
  LiveWeatherService({required this.apiKey, http.Client? client})
      : _client = client ?? http.Client();

  final String apiKey;
  final http.Client _client;

  @override
  Future<WeatherData?> getWeather({double? latitude, double? longitude}) async {
    if (apiKey.isEmpty || latitude == null || longitude == null) {
      return null;
    }

    try {
      final uri = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?lat=$latitude&lon=$longitude&units=metric&appid=$apiKey',
      );
      final response = await _client.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final main = data['main'] as Map<String, dynamic>? ?? {};
      final weatherList = data['weather'] as List<dynamic>? ?? [];
      final firstWeather = weatherList.isNotEmpty
          ? weatherList.first as Map<String, dynamic>
          : <String, dynamic>{};
      final wind = data['wind'] as Map<String, dynamic>? ?? {};

      final temp = (main['temp'] as num?)?.toDouble() ?? 0.0;
      final condition = firstWeather['main'] as String? ?? 'Clear';
      final tempMin = (main['temp_min'] as num?)?.toDouble();
      final tempMax = (main['temp_max'] as num?)?.toDouble();
      final humidity = (main['humidity'] as num?)?.toInt();
      final windSpeedMs = (wind['speed'] as num?)?.toDouble();
      final windSpeedKmh = windSpeedMs != null ? windSpeedMs * 3.6 : null;

      return WeatherData(
        temperatureC: temp,
        condition: condition,
        highC: tempMax,
        lowC: tempMin,
        humidity: humidity,
        windSpeedKmh: windSpeedKmh,
        locationName: data['name'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Provider factory that checks `--dart-define=WEATHER_API_KEY`.
/// When unset or empty, yields [PlaceholderWeatherService].
/// When set, yields [LiveWeatherService].
class WeatherProvider {
  WeatherProvider._();

  /// Ingested at compile-time via `--dart-define=WEATHER_API_KEY=<key>`.
  /// No default key is hard-coded; when unset or empty, [apiKey] defaults to
  /// empty string and the UI gracefully renders the "Weather unavailable" state.
  static const String apiKey = String.fromEnvironment('WEATHER_API_KEY');

  /// Returns true if a live weather API key is defined or a test mock is injected.
  static bool get isConfigured => apiKey.isNotEmpty || mockService != null;

  /// Shared location label matching the Home cockpit (fallback "Location off").
  static String currentLocationLabel = 'Location off';

  @visibleForTesting
  static WeatherService? mockService;

  static WeatherService get service {
    if (mockService != null) return mockService!;
    if (apiKey.isEmpty) {
      return const PlaceholderWeatherService();
    }
    return LiveWeatherService(apiKey: apiKey);
  }
}
