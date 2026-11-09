import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../settings/controllers/settings_controller.dart';

/// Normalized snapshot of GPS position, heading, speed and accuracy.
class PositionData {
  const PositionData({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.heading,
    this.speed,
    this.accuracy,
    this.altitude,
  });

  final double latitude;
  final double longitude;

  /// Heading/bearing in degrees (0..360, where 0 is true north).
  final double? heading;

  /// Speed over ground in meters per second (m/s).
  final double? speed;

  /// Estimated horizontal accuracy in meters.
  final double? accuracy;

  /// Altitude in meters above mean sea level.
  final double? altitude;

  final DateTime timestamp;

  LatLng toLatLng() => LatLng(latitude, longitude);

  @override
  String toString() =>
      'PositionData(lat: $latitude, lon: $longitude, heading: $heading, speed: $speed m/s, accuracy: $accuracy m)';
}

/// Abstract interface for device location access and GPS telemetry streaming.
abstract class LocationService {
  Future<bool> isLocationServiceEnabled();
  Future<bool> checkPermission();
  Future<bool> requestPermission();
  Future<PositionData?> getCurrentPosition();
  Future<PositionData?> getLastKnownPosition();
  Stream<PositionData> getPositionStream({
    bool highAccuracy = false,
    bool enableForegroundNotification = false,
    bool? forceLocationManager,
  });
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
}

/// Production implementation backed by the [Geolocator] plugin.
class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  static bool get _isTesting =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  /// Builds the platform [LocationSettings] for a position stream subscription.
  ///
  /// When `forceLocationManager` (or [SettingsController.gpsOnlyLocationProvider])
  /// is enabled, builds [AndroidSettings] with `forceLocationManager: true` for
  /// every subscription (navigation, ride tracker, and place label).
  static LocationSettings buildLocationSettings({
    bool highAccuracy = false,
    bool enableForegroundNotification = false,
    bool? forceLocationManager,
  }) {
    final bool useGpsOnly = forceLocationManager ??
        SettingsController.instance.gpsOnlyLocationProvider;
    final bool useAndroidSettings = useGpsOnly ||
        (enableForegroundNotification &&
            !kIsWeb &&
            defaultTargetPlatform == TargetPlatform.android) ||
        (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

    if (useAndroidSettings) {
      return AndroidSettings(
        accuracy:
            highAccuracy ? LocationAccuracy.high : LocationAccuracy.medium,
        distanceFilter: highAccuracy ? 2 : 10,
        forceLocationManager: useGpsOnly,
        foregroundNotificationConfig: enableForegroundNotification
            ? const ForegroundNotificationConfig(
                notificationTitle: 'CAMP Ride Tracking',
                notificationText: 'CAMP is tracking this ride',
                enableWakeLock: true,
              )
            : null,
      );
    }

    return LocationSettings(
      accuracy:
          highAccuracy ? LocationAccuracy.high : LocationAccuracy.medium,
      distanceFilter: highAccuracy ? 2 : 10,
    );
  }

  @override
  Future<bool> isLocationServiceEnabled() async {
    if (_isTesting) return false;
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> checkPermission() async {
    if (_isTesting) return false;
    try {
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (_isTesting) return false;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<PositionData?> getCurrentPosition() async {
    if (_isTesting) return null;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return _mapPosition(pos);
    } catch (_) {
      // Fallback to last known position if immediate fix fails or times out
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) return _mapPosition(last);
      } catch (_) {}
      return null;
    }
  }

  @override
  Future<PositionData?> getLastKnownPosition() async {
    if (_isTesting) return null;
    try {
      final pos = await Geolocator.getLastKnownPosition();
      return pos != null ? _mapPosition(pos) : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<PositionData> getPositionStream({
    bool highAccuracy = false,
    bool enableForegroundNotification = false,
    bool? forceLocationManager,
  }) {
    final settings = buildLocationSettings(
      highAccuracy: highAccuracy,
      enableForegroundNotification: enableForegroundNotification,
      forceLocationManager: forceLocationManager,
    );
    return Geolocator.getPositionStream(locationSettings: settings)
        .map(_mapPosition);
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  static PositionData _mapPosition(Position p) {
    return PositionData(
      latitude: p.latitude,
      longitude: p.longitude,
      heading: p.heading >= 0 ? p.heading : null,
      speed: p.speed >= 0 ? p.speed : null,
      accuracy: p.accuracy >= 0 ? p.accuracy : null,
      altitude: p.altitude,
      timestamp: p.timestamp,
    );
  }
}
