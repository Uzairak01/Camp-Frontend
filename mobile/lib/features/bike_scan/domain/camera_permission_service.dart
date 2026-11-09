import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Camera authorization states for permission gating before camera initialization.
enum CameraPermissionStatus {
  /// Permission has been granted by the user.
  granted,

  /// Permission is denied, but the OS allows prompting the user again.
  denied,

  /// Permission was permanently denied ("Don't ask again"); user must be directed to app settings.
  permanentlyDenied,
}

/// Abstract contract for checking, requesting, and managing camera permissions.
abstract class CameraPermissionService {
  /// Checks the current authorization status without showing an OS prompt.
  Future<CameraPermissionStatus> checkPermission();

  /// Requests camera permission from the OS and awaits user response.
  Future<CameraPermissionStatus> requestPermission();

  /// Opens the device app settings screen so the rider can grant permissions manually.
  Future<void> openAppSettings();
}

/// Production implementation using the `camp/camera_permission` method channel.
class MethodChannelCameraPermissionService implements CameraPermissionService {
  /// Creates a [MethodChannelCameraPermissionService].
  const MethodChannelCameraPermissionService();

  static const MethodChannel _channel = MethodChannel('camp/camera_permission');

  @override
  Future<CameraPermissionStatus> checkPermission() async {
    try {
      final res = await _channel.invokeMethod<String>('checkPermission');
      return _parseStatus(res);
    } catch (_) {
      // Fallback: if channel is unavailable (e.g. tests or unsupported platform),
      // default to granted so the camera package handles its own lifecycle.
      return CameraPermissionStatus.granted;
    }
  }

  @override
  Future<CameraPermissionStatus> requestPermission() async {
    try {
      final res = await _channel.invokeMethod<String>('requestPermission');
      return _parseStatus(res);
    } catch (_) {
      return CameraPermissionStatus.granted;
    }
  }

  @override
  Future<void> openAppSettings() async {
    try {
      await _channel.invokeMethod<void>('openAppSettings');
    } catch (_) {
      // Fallback: attempt to open app-settings: URL scheme on iOS/supported platforms.
      try {
        final uri = Uri.parse('app-settings:');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      } catch (_) {}
    }
  }

  CameraPermissionStatus _parseStatus(String? status) {
    switch (status) {
      case 'granted':
        return CameraPermissionStatus.granted;
      case 'permanentlyDenied':
        return CameraPermissionStatus.permanentlyDenied;
      case 'denied':
      default:
        return CameraPermissionStatus.denied;
    }
  }
}

