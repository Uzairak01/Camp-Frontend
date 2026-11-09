import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_colors.dart';
import '../../features/navigation/domain/location_service.dart';

/// Status pill displaying "GPS LIVE" with a green status indicator.
///
/// Fully adheres to CAMP honesty rules (#134):
/// Shown ONLY when device location service is enabled, permission is granted,
/// AND a position fix has been received recently (within 120 seconds).
/// When location is disabled, permission denied, or no fix is available,
/// this widget completely hides itself (renders [SizedBox.shrink]).
class GpsLivePill extends StatefulWidget {
  const GpsLivePill({
    super.key,
    this.locationService = const GeolocatorLocationService(),
  });

  final LocationService locationService;

  @override
  State<GpsLivePill> createState() => _GpsLivePillState();
}

class _GpsLivePillState extends State<GpsLivePill> {
  bool _isLive = false;
  StreamSubscription<PositionData>? _sub;

  @override
  void initState() {
    super.initState();
    _checkGpsStatus();
    _subscribeToStream();
  }

  @override
  void didUpdateWidget(covariant GpsLivePill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.locationService != oldWidget.locationService) {
      _sub?.cancel();
      _checkGpsStatus();
      _subscribeToStream();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _subscribeToStream() {
    try {
      _sub = widget.locationService
          .getPositionStream(highAccuracy: false)
          .listen((pos) {
        final isRecent = DateTime.now().difference(pos.timestamp).inSeconds < 120;
        if (mounted && isRecent != _isLive) {
          setState(() {
            _isLive = isRecent;
          });
        }
      }, onError: (_) {
        if (mounted && _isLive) {
          setState(() {
            _isLive = false;
          });
        }
      });
    } catch (_) {}
  }

  Future<void> _checkGpsStatus() async {
    try {
      final enabled = await widget.locationService.isLocationServiceEnabled();
      if (!enabled) {
        if (mounted && _isLive) setState(() => _isLive = false);
        return;
      }

      final hasPermission = await widget.locationService.checkPermission();
      if (!hasPermission) {
        if (mounted && _isLive) setState(() => _isLive = false);
        return;
      }

      final pos = await widget.locationService.getCurrentPosition();
      final isRecent = pos != null &&
          DateTime.now().difference(pos.timestamp).inSeconds < 120;

      if (mounted) {
        setState(() {
          _isLive = isRecent;
        });
      }
    } catch (_) {
      if (mounted && _isLive) {
        setState(() => _isLive = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLive) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.clay,
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
        boxShadow: AppColors.skeuRaisedSmall,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.statusGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'GPS LIVE',
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.darkCharcoal,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

