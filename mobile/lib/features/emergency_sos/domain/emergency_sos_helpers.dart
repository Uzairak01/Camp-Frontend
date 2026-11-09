import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../dashboard/domain/emergency_phone_helper.dart';
import '../../navigation/domain/location_service.dart';

/// Pre-configured emergency response service options (Pakistan standard).
class EmergencyServiceOption {
  const EmergencyServiceOption({
    required this.number,
    required this.label,
    required this.description,
  });

  final String number;
  final String label;
  final String description;
}

const List<EmergencyServiceOption> kEmergencyServiceOptions = [
  EmergencyServiceOption(
    number: '1122',
    label: '1122 Rescue',
    description: 'Pakistan Rescue 1122 (Disaster & Medical)',
  ),
  EmergencyServiceOption(
    number: '15',
    label: '15 Police',
    description: 'Police Assistance Helpline',
  ),
  EmergencyServiceOption(
    number: '115',
    label: '115 Ambulance',
    description: 'Ambulance Emergency Dispatch',
  ),
];

/// Helper to build honest emergency SMS / WhatsApp message body with Google Maps
/// coordinate link if GPS fix is available.
String buildEmergencySmsBody(PositionData? position) {
  if (position != null) {
    return 'I need help. My location: https://www.google.com/maps?q=${position.latitude},${position.longitude}';
  } else {
    return 'I need help. My location: location not available yet';
  }
}

/// Function signature for launching external URLs.
typedef EmergencyUrlLauncher = Future<bool> Function(
  Uri uri, {
  LaunchMode mode,
});

/// Default production launcher delegating directly to `url_launcher.launchUrl`.
Future<bool> _defaultUrlLauncher(
  Uri uri, {
  LaunchMode mode = LaunchMode.externalApplication,
}) async {
  return launchUrl(uri, mode: mode);
}

/// Active URL launcher invoked across emergency calling and messaging.
EmergencyUrlLauncher _activeLauncher = _defaultUrlLauncher;

/// Overrides the URL launcher implementation for automated testing.
@visibleForTesting
void setEmergencyUrlLauncherForTesting(EmergencyUrlLauncher? launcher) {
  _activeLauncher = launcher ?? _defaultUrlLauncher;
}

/// Opens the device dialer with `tel:<number>`.
Future<bool> launchTel(String number) async {
  final cleanNumber = number.trim();
  final uri = Uri(scheme: 'tel', path: cleanNumber);
  try {
    return await _activeLauncher(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Constructs a single-recipient `sms:` URI.
///
/// Multi-recipient URIs are deliberately avoided because third-party handlers
/// (such as WhatsApp on some devices) misinterpret semicolon-delimited numbers
/// as a single malformed phone number.
Uri buildSingleEmergencySmsUri(String number, String body) {
  final cleanNumber = number.replaceAll(RegExp(r'[\s\-]'), '');
  return Uri(
    scheme: 'sms',
    path: cleanNumber,
    queryParameters: {'body': body},
  );
}

/// Constructs a WhatsApp native scheme `whatsapp://send?phone=<digits>&text=<encoded>` URI.
///
/// Direct application scheme avoids web redirects and handles nested maps URLs cleanly.
Uri buildWhatsAppNativeUri(String number, String message) {
  final digitsOnly = EmergencyPhoneHelper.extractE164Digits(number);
  final encodedText = Uri.encodeQueryComponent(message);
  if (encodedText.isEmpty) {
    return Uri.parse('whatsapp://send?phone=$digitsOnly');
  }
  return Uri.parse('whatsapp://send?phone=$digitsOnly&text=$encodedText');
}

/// Constructs a WhatsApp web `https://wa.me/<digits>?text=<encoded>` URI.
///
/// Encodes query parameters with percent-encoding so nested URLs do not corrupt the URI.
Uri buildWhatsAppWebUri(String number, String message) {
  final digitsOnly = EmergencyPhoneHelper.extractE164Digits(number);
  final encodedText = Uri.encodeQueryComponent(message);
  if (encodedText.isEmpty) {
    return Uri.parse('https://wa.me/$digitsOnly');
  }
  return Uri.parse('https://wa.me/$digitsOnly?text=$encodedText');
}

/// Constructs a WhatsApp URI, defaulting to the official wa.me universal web link.
Uri buildWhatsAppUri(String number, String message) => buildWhatsAppWebUri(number, message);

/// Platform channel to MainActivity that sends explicit SMS / share intents.
///
/// Used instead of url_launcher for `sms:` because an implicit ACTION_VIEW is claimed by
/// both Messages and WhatsApp, and WhatsApp answers with a "not registered" dialog.
const MethodChannel _shareChannel = MethodChannel('camp/share');

/// Opens the default SMS app's composer for exactly one [number] with [body] pre-filled.
///
/// Tries the native `openSms` channel call first (explicit SENDTO intent pinned to the
/// default SMS package, so no chooser can appear). Only if the channel reports failure or
/// is unavailable does it fall back to the url_launcher `sms:` link. One number per call;
/// numbers are never glued together. Nothing is sent; the rider taps Send.
Future<bool> launchSms(String number, String body) async {
  final cleanNumber = number.replaceAll(RegExp(r'[\s\-]'), '');
  try {
    final opened = await _shareChannel.invokeMethod<bool>(
      'openSms',
      {'number': cleanNumber, 'body': body},
    );
    if (opened == true) return true;
  } catch (_) {
    // Channel missing (non-Android) or failed: use the url_launcher fallback below.
  }

  final uri = buildSingleEmergencySmsUri(number, body);
  try {
    return await _activeLauncher(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Opens the system share sheet ("Send alert with") carrying [body] as plain text.
///
/// The rider picks the app and then the person inside that app. Returns `false` if the
/// sheet could not be shown. Nothing is sent automatically.
Future<bool> shareAlert(String body) async {
  try {
    final shown = await _shareChannel.invokeMethod<bool>('shareText', {'body': body});
    return shown == true;
  } catch (_) {
    return false;
  }
}

/// Opens WhatsApp with the distress message in external application mode.
///
/// Uses the primary native scheme `whatsapp://send?phone=...&text=...` first,
/// falling back to the web `https://wa.me/...` link if the native scheme cannot launch.
/// Returns `false` if neither can launch (e.g. WhatsApp is not installed).
/// Nothing is sent automatically; the rider taps Send in WhatsApp.
Future<bool> launchWhatsApp(String number, String message) async {
  final nativeUri = buildWhatsAppNativeUri(number, message);
  final webUri = buildWhatsAppWebUri(number, message);

  try {
    // Primary: try native scheme first
    final launchedNative = await _activeLauncher(
      nativeUri,
      mode: LaunchMode.externalApplication,
    );
    if (launchedNative) return true;
  } catch (_) {
    // Fall back to web URI
  }

  try {
    // Fallback: try wa.me web link
    return await _activeLauncher(
      webUri,
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}
