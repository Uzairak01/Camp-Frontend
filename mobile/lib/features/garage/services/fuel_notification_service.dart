import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service managing system notifications for low fuel warnings.
class FuelNotificationService {
  FuelNotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  bool _notificationPermissionGranted = true;

  bool get notificationPermissionGranted => _notificationPermissionGranted;

  static const String channelId = 'low_fuel_channel';
  static const String channelName = 'Low fuel';
  static const String channelDescription =
      'Alerts when estimated motorcycle fuel level is critically low.';

  Future<void> init() async {
    if (_initialized) return;
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    try {
      await _plugin.initialize(settings: settings);
      _initialized = true;
    } catch (_) {
      // Ignored in headless/test environments
    }
  }

  /// Request POST_NOTIFICATIONS permission on Android 13+ and iOS.
  Future<bool> requestPermission() async {
    await init();
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final androidImpl = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final granted = await androidImpl?.requestNotificationsPermission();
        _notificationPermissionGranted = granted ?? false;
        return _notificationPermissionGranted;
      } else if (!kIsWeb && Platform.isIOS) {
        final iosImpl = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final granted = await iosImpl?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        _notificationPermissionGranted = granted ?? false;
        return _notificationPermissionGranted;
      }
    } catch (_) {}
    return true;
  }

  /// Show low fuel system notification with estimated remaining range.
  Future<void> showLowFuelAlert({required int rangeKm}) async {
    await init();
    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const darwinDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    try {
      await _plugin.show(
        id: 1001,
        title: 'Low fuel',
        body: 'Low fuel: about $rangeKm km left. Please refill.',
        notificationDetails: details,
      );
    } catch (_) {
      // Ignored in environments without active native notification bridge
    }
  }
}
