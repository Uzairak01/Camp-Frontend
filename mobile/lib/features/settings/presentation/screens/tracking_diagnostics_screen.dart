import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/camp_app_bar.dart';
import '../../../../core/widgets/camp_card.dart';
import '../../../garage/services/fuel_tracker_service.dart';
import '../../../garage/services/tracking_diagnostics.dart';
import '../../controllers/settings_controller.dart';

/// Read-only live diagnostics panel for tracking telemetry, filter decisions,
/// device permissions, and system power management.
///
/// Guarded strictly for debug builds ([kDebugMode]).
class TrackingDiagnosticsScreen extends StatefulWidget {
  const TrackingDiagnosticsScreen({
    super.key,
    this.isDebugMode = kDebugMode,
  });

  /// Allows unit and widget tests to verify debug-mode visibility without modifying lib/ code.
  final bool isDebugMode;

  @override
  State<TrackingDiagnosticsScreen> createState() =>
      _TrackingDiagnosticsScreenState();
}

class _TrackingDiagnosticsScreenState extends State<TrackingDiagnosticsScreen> {
  Timer? _secondsTicker;
  bool? _isLocationServiceEnabled;
  LocationPermission? _locationPermission;
  LocationAccuracyStatus? _locationAccuracyStatus;
  bool? _notificationsEnabled;
  bool _isLoadingStatus = true;

  @override
  void initState() {
    super.initState();
    if (widget.isDebugMode) {
      _fetchSystemStatus();
      // Tick every second to keep 'seconds since last fix' indicator live.
      _secondsTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _secondsTicker?.cancel();
    super.dispose();
  }

  Future<void> _fetchSystemStatus() async {
    try {
      final locService = await Geolocator.isLocationServiceEnabled();
      final perm = await Geolocator.checkPermission();
      LocationAccuracyStatus? acc;
      try {
        acc = await Geolocator.getLocationAccuracy();
      } catch (_) {
        acc = LocationAccuracyStatus.unknown;
      }
      final notif = FuelTrackerService.instance.notificationPermissionGranted;

      if (mounted) {
        setState(() {
          _isLocationServiceEnabled = locService;
          _locationPermission = perm;
          _locationAccuracyStatus = acc;
          _notificationsEnabled = notif;
          _isLoadingStatus = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingStatus = false);
      }
    }
  }

  void _copyLogToClipboard(BuildContext context) {
    final text = TrackingDiagnostics.instance.formatLogAsPlainText(
      maxAccuracyMeters: FuelTrackerService.maxAccuracyMeters,
      minDistanceMeters: FuelTrackerService.minDistanceMeters,
      minSpeedMps: FuelTrackerService.minSpeedMps,
      maxSpeedMps: FuelTrackerService.maxSpeedMps,
    );
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Tracking log copied to clipboard (${TrackingDiagnostics.instance.events.length} events)',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.darkCharcoal,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Exports the complete tracking diagnostics log formatted oldest-first
  /// to a temporary file named `camp_log_<UTC timestamp>.txt` and presents
  /// the system share sheet. Shows a SnackBar if saving or sharing fails.
  Future<void> _shareLogAsFile(BuildContext context) async {
    // Determine anchor rect before any async gap to satisfy use_build_context_synchronously
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? (box.localToGlobal(Offset.zero) & box.size)
        : null;

    try {
      final text = TrackingDiagnostics.instance.formatLogAsPlainText(
        maxAccuracyMeters: FuelTrackerService.maxAccuracyMeters,
        minDistanceMeters: FuelTrackerService.minDistanceMeters,
        minSpeedMps: FuelTrackerService.minSpeedMps,
        maxSpeedMps: FuelTrackerService.maxSpeedMps,
        oldestFirst: true,
      );

      final tempDir = await getTemporaryDirectory();
      // Format timestamp as UTC ISO-8601 with filesystem-safe delimiters (colons replaced)
      final safeUtcTimestamp = DateTime.now()
          .toUtc()
          .toIso8601String()
          .replaceAll(':', '-');
      final fileName = 'camp_log_$safeUtcTimestamp.txt';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(text, flush: true);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/plain')],
          subject: 'CAMP Tracking Diagnostics Log',
          sharePositionOrigin: origin,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to share log file: $e',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
          ),
          backgroundColor: AppColors.alertRed,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _clearLog() {
    TrackingDiagnostics.instance.clear();
  }

  @override
  Widget build(BuildContext context) {
    // Hidden in non-debug mode builds
    if (!widget.isDebugMode) {
      return const Scaffold(
        body: Center(
          child: Text('Tracking diagnostics is only available in debug builds.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.clay,
      appBar: CampAppBar(
        titleText: 'TRACKING DIAGNOSTICS',
        leading: CampAppBarLeading.back,
        onLeadingPressed: () => Navigator.of(context).pop(),
        actionIcon: Icons.refresh_rounded,
        onActionPressed: _fetchSystemStatus,
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          TrackingDiagnostics.instance,
          SettingsController.instance,
        ]),
        builder: (context, _) {
          final diag = TrackingDiagnostics.instance;
          final events = diag.events;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            children: [
              _buildSystemStatusCard(),
              const SizedBox(height: 12),
              _buildLiveMetricsCard(diag),
              const SizedBox(height: 12),
              _buildFilterThresholdsCard(),
              const SizedBox(height: 16),
              _buildActionsRow(context, diag),
              const SizedBox(height: 16),
              _buildEventLogHeader(events.length),
              const SizedBox(height: 8),
              if (events.isEmpty)
                _buildEmptyState()
              else
                ...events.map(_buildEventTile),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSystemStatusCard() {
    final permStr = switch (_locationPermission) {
      LocationPermission.always => 'Always',
      LocationPermission.whileInUse => 'While in use',
      LocationPermission.denied => 'Denied',
      LocationPermission.deniedForever => 'Denied forever',
      _ => _isLoadingStatus ? 'Checking...' : 'Unknown',
    };

    final accStr = switch (_locationAccuracyStatus) {
      LocationAccuracyStatus.precise => 'Precise',
      LocationAccuracyStatus.reduced => 'Approximate',
      _ => _isLoadingStatus ? 'Checking...' : 'Unknown',
    };

    return CampCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.phonelink_setup_rounded,
                  size: 16, color: AppColors.tacticalOrange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'DEVICE & SERVICE STATUS',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: AppColors.darkCharcoal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatusRow(
            'Location Service (GPS)',
            _isLocationServiceEnabled == true ? 'ON' : 'OFF',
            isGood: _isLocationServiceEnabled == true,
          ),
          _buildStatusRow(
            'Location Permission',
            permStr,
            isGood: _locationPermission == LocationPermission.always ||
                _locationPermission == LocationPermission.whileInUse,
          ),
          _buildStatusRow(
            'Location Accuracy Mode',
            accStr,
            isGood: _locationAccuracyStatus == LocationAccuracyStatus.precise,
          ),
          _buildStatusRow(
            'Notification Permission',
            _notificationsEnabled == true ? 'Granted' : 'Denied / Restricted',
            isGood: _notificationsEnabled == true,
          ),
          _buildStatusRow(
            'Battery Optimisation',
            'Unknown (no battery optimization plugin installed in pubspec.yaml; requires permission_handler or platform channel)',
            isNeutral: true,
          ),
          _buildStatusRow(
            'Foreground Service Running',
            'No (expected: none running yet)',
            isNeutral: true,
          ),
          _buildStatusRow(
            'Location Provider Mode',
            SettingsController.instance.gpsOnlyLocationProvider
                ? 'GPS-only (forceLocationManager: true)'
                : 'Fused Location Provider (default)',
            isNeutral: true,
          ),
          if (widget.isDebugMode) ...[
            const Divider(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GPS-only provider (experimental)',
                        style: GoogleFonts.manrope(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                      Text(
                        'Force Android LocationManager hardware GPS across all streams',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  key: const ValueKey('tracking_diag_gps_only_switch'),
                  value: SettingsController.instance.gpsOnlyLocationProvider,
                  activeThumbColor: AppColors.tacticalOrange,
                  onChanged: (val) {
                    SettingsController.instance.setGpsOnlyLocationProvider(val);
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLiveMetricsCard(TrackingDiagnostics diag) {
    final isRiding = diag.trackerState == 'started';
    final secondsAgo = diag.secondsSinceLastFix;
    final lastFixDisplay = diag.lastFixTime != null
        ? '${diag.lastFixTime!.toLocal().hour.toString().padLeft(2, '0')}:${diag.lastFixTime!.toLocal().minute.toString().padLeft(2, '0')}:${diag.lastFixTime!.toLocal().second.toString().padLeft(2, '0')} (${secondsAgo ?? 0}s ago)'
        : 'None received yet';

    return CampCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.speed_rounded,
                        size: 16, color: AppColors.tacticalOrange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'LIVE TRACKER TELEMETRY',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isRiding
                      ? AppColors.statusGreen.withValues(alpha: 0.15)
                      : AppColors.clayDark,
                  borderRadius: BorderRadius.circular(AppColors.radiusPill),
                  border: Border.all(
                    color: isRiding ? AppColors.statusGreen : AppColors.mutedText,
                    width: 1,
                  ),
                ),
                child: Text(
                  isRiding ? 'TRACKING ACTIVE' : 'STOPPED',
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isRiding ? AppColors.statusGreen : AppColors.mutedText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatusRow(
            'Accumulated Distance',
            '${diag.accumulatedDistanceMeters.toStringAsFixed(1)} m (${(diag.accumulatedDistanceMeters / 1000.0).toStringAsFixed(2)} km)',
            isGood: diag.accumulatedDistanceMeters > 0,
          ),
          _buildStatusRow(
            'Accepted Fixes',
            '${diag.acceptedCount}',
            isGood: diag.acceptedCount > 0,
          ),
          _buildStatusRow(
            'Rejected Fixes',
            '${diag.rejectedCount}',
            isGood: diag.rejectedCount == 0,
          ),
          _buildStatusRow(
            'Last Fix Received',
            lastFixDisplay,
            isGood: secondsAgo != null && secondsAgo <= 10,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterThresholdsCard() {
    return CampCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_alt_outlined,
                  size: 16, color: AppColors.tacticalOrange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ACTIVE TRACKER THRESHOLDS',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: AppColors.darkCharcoal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildStatusRow(
            'Max Accuracy Allowed',
            '${FuelTrackerService.maxAccuracyMeters.toStringAsFixed(0)} m (drops >= 30m)',
            isNeutral: true,
          ),
          _buildStatusRow(
            'Min Distance Between Fixes',
            '${FuelTrackerService.minDistanceMeters.toStringAsFixed(0)} m (drops jitter < 5m)',
            isNeutral: true,
          ),
          _buildStatusRow(
            'Min Speed Threshold',
            '${FuelTrackerService.minSpeedMps.toStringAsFixed(1)} m/s (3.6 km/h)',
            isNeutral: true,
          ),
          _buildStatusRow(
            'Max Speed Jump Threshold',
            '${FuelTrackerService.maxSpeedMps.toStringAsFixed(2)} m/s (200.0 km/h)',
            isNeutral: true,
          ),
        ],
      ),
    );
  }

  Widget _buildActionsRow(BuildContext context, TrackingDiagnostics diag) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            key: const ValueKey('tracking_diag_copy_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.darkCharcoal,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusCard),
              ),
            ),
            onPressed: () => _copyLogToClipboard(context),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.copy_rounded, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Copy log',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton(
            key: const ValueKey('tracking_diag_share_file_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.darkCharcoal,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusCard),
              ),
            ),
            onPressed: () => _shareLogAsFile(context),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.share_rounded, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Share log as file',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          key: const ValueKey('tracking_diag_clear_button'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.clayDark,
            foregroundColor: AppColors.darkCharcoal,
            minimumSize: const Size(0, 44),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusCard),
            ),
          ),
          onPressed: _clearLog,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.delete_outline_rounded, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Clear',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEventLogHeader(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            'EVENT LOG ($count of ${TrackingDiagnostics.maxEvents}, newest first)',
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.darkCharcoal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return CampCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.gps_off_rounded,
                  size: 36, color: AppColors.mutedText),
              const SizedBox(height: 8),
              Text(
                'No tracking events recorded yet.',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkCharcoal,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Start a ride on the Active Motorcycle card to observe live fixes.',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: AppColors.mutedText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventTile(TrackingEvent event) {
    final localTime = event.timestamp.toLocal();
    final localTimeStr =
        '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}:${localTime.second.toString().padLeft(2, '0')}';
    final timeStr = '${event.formattedTimestampUtc} ($localTimeStr)';

    // 1. Gap Event (Highlighted in RED)
    if (event.isGap) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.alertRed.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.alertRed, width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 20, color: AppColors.alertRed),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ GAP: ${event.gapDuration?.inSeconds}s WITHOUT FIXES',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.alertRed,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Android suspended location updates (e.g. screen locked or battery saver active).',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkCharcoal,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              timeStr,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                color: AppColors.alertRed,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    // 2. Lifecycle Event
    if (event.type == TrackingEventType.lifecycle) {
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.clayDark,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'LIFECYCLE: ${event.message}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.darkCharcoal,
              ),
            ),
            Text(
              timeStr,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                color: AppColors.mutedText,
              ),
            ),
          ],
        ),
      );
    }

    // 3. State Change / Off-Route / Reroute Event
    if (event.type == TrackingEventType.trackerState ||
        event.type == TrackingEventType.offRoute ||
        event.type == TrackingEventType.reroute) {
      final prefix = switch (event.type) {
        TrackingEventType.offRoute => 'OFF-ROUTE',
        TrackingEventType.reroute => 'REROUTE',
        _ => 'TRACKER STATE',
      };
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.clayDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.tacticalOrange, width: 0.8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '$prefix: ${event.message}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkCharcoal,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              timeStr,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                color: AppColors.mutedText,
              ),
            ),
          ],
        ),
      );
    }

    // 4. Fix Event (Accepted in green / Rejected in orange)
    final isRejected = event.isRejected;
    final borderColor =
        isRejected ? AppColors.tacticalOrange : AppColors.statusGreen;
    final bgColor = isRejected
        ? AppColors.tacticalOrange.withValues(alpha: 0.08)
        : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: isRejected ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isRejected
                      ? AppColors.tacticalOrange.withValues(alpha: 0.15)
                      : AppColors.statusGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isRejected ? 'REJECTED' : 'ACCEPTED',
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isRejected
                        ? AppColors.tacticalOrangeDark
                        : AppColors.statusGreen,
                  ),
                ),
              ),
              Text(
                timeStr,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: AppColors.mutedText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            event.reason ?? '',
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isRejected
                  ? AppColors.tacticalOrangeDark
                  : AppColors.darkCharcoal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Lat: ${event.formattedLatitude}, Lng: ${event.formattedLongitude} • Acc: ${event.formattedAccuracy} (PrevAcc: ${event.formattedPreviousAccuracy}) • dt: ${event.formattedElapsedSeconds} • Dist: ${event.formattedDistanceFromPreviousAccepted} • Spd: ${event.formattedSpeed} [${event.formattedReportedSpeedValidity}] • CalcSpd: ${event.formattedCalculatedSpeed} • Passed: ${event.segmentPassed ? 'yes' : 'no'} • PrevTime: ${event.formattedPreviousAcceptedTimestampUtc}',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10.5,
              color: AppColors.darkCharcoal.withValues(alpha: 0.8),
            ),
          ),
          if (event.isAccepted && (event.segmentMeters ?? 0) > 0) ...[
            const SizedBox(height: 2),
            Text(
              '+${event.segmentMeters!.toStringAsFixed(1)} m | Total accumulated: ${event.accumulatedMeters?.toStringAsFixed(1)} m',
              style: GoogleFonts.manrope(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppColors.statusGreen,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value,
      {bool? isGood, bool isNeutral = false}) {
    Color textColor = AppColors.darkCharcoal;
    if (!isNeutral && isGood != null) {
      textColor = isGood ? AppColors.statusGreen : AppColors.alertRed;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: AppColors.mutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
