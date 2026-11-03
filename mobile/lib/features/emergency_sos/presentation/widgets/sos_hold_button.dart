import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../dashboard/controllers/profile_controller.dart';
import '../../../navigation/domain/location_service.dart';
import '../../domain/emergency_sos_helpers.dart';
import 'alert_contacts_bottom_sheet.dart';

/// Top card containing the 3D Tactile SOS Button & real GPS status indicator.
///
/// Renamed from HardwareTelematicsCard to SosHoldButton (#73).
/// Detects a continuous 3-second press, shows an animated countdown ring,
/// vibrates the phone, and opens the Alert Contacts sheet pre-filled with the current
/// phone GPS link so the rider picks SMS, WhatsApp or another app per contact.
class SosHoldButton extends StatefulWidget {
  const SosHoldButton({
    super.key,
    this.locationService = const GeolocatorLocationService(),
  });

  final LocationService locationService;

  @override
  State<SosHoldButton> createState() => _SosHoldButtonState();
}

class _SosHoldButtonState extends State<SosHoldButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  Timer? _countdownTimer;
  int _secondsLeft = 3;
  bool _isHolding = false;

  bool _isGpsReady = false;
  bool _isCheckingGps = true;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _triggerSosAlert();
      }
    });

    _checkGpsStatus();
  }

  Future<void> _checkGpsStatus() async {
    try {
      final enabled = await widget.locationService.isLocationServiceEnabled();
      if (!enabled) {
        if (mounted) setState(() { _isGpsReady = false; _isCheckingGps = false; });
        return;
      }
      final pos = await widget.locationService.getCurrentPosition();
      if (mounted) {
        setState(() {
          _isGpsReady = pos != null;
          _isCheckingGps = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isGpsReady = false;
          _isCheckingGps = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  void _startHolding() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isHolding = true;
      _secondsLeft = 3;
    });
    _progressController.forward(from: 0.0);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 1) {
        setState(() => _secondsLeft--);
        HapticFeedback.mediumImpact();
      } else {
        timer.cancel();
      }
    });
  }

  void _cancelHolding() {
    if (_progressController.isCompleted) return;
    _countdownTimer?.cancel();
    _progressController.reset();
    setState(() {
      _isHolding = false;
      _secondsLeft = 3;
    });
  }

  Future<void> _triggerSosAlert() async {
    _countdownTimer?.cancel();
    HapticFeedback.vibrate();
    setState(() => _isHolding = false);

    final contacts = ProfileController.instance.emergencyContacts;
    final numbers = contacts.map((c) => c.phone.trim()).where((p) => p.isNotEmpty).toList();
    if (numbers.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No emergency contact saved. Please add one in your profile.',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
            ),
            backgroundColor: AppColors.tacticalOrange,
            action: SnackBarAction(
              label: 'Add',
              textColor: Colors.white,
              onPressed: () => Navigator.of(context).pushNamed(CampRoutes.editProfile),
            ),
          ),
        );
      }
      return;
    }

    PositionData? position;
    try {
      position = await widget.locationService.getCurrentPosition();
    } catch (_) {
      position = null;
    }

    final body = buildEmergencySmsBody(position);
    // Always show the Alert Contacts sheet (also for a single contact) so the rider
    // chooses SMS, WhatsApp or another app explicitly.
    if (mounted) {
      await AlertContactsBottomSheet.show(
        context,
        contacts: contacts,
        messageBody: body,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      child: Column(
        children: [
          // Concentric 3D Red SOS Button with Hold Detection
          GestureDetector(
            onTapDown: (_) => _startHolding(),
            onTapUp: (_) => _cancelHolding(),
            onTapCancel: () => _cancelHolding(),
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Animated holding progress indicator ring
                  SizedBox(
                    width: 188,
                    height: 188,
                    child: AnimatedBuilder(
                      animation: _progressController,
                      builder: (context, child) {
                        return CircularProgressIndicator(
                          value: _progressController.value,
                          strokeWidth: 4,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFE53935),
                          ),
                          backgroundColor: Colors.transparent,
                        );
                      },
                    ),
                  ),

                  // Outermost Concentric Halo / Bezel
                  Container(
                    width: 174,
                    height: 174,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFF1F4F8), Color(0xFFE2E7EE)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                          blurRadius: 28,
                          spreadRadius: 4,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                        const BoxShadow(
                          color: Colors.white,
                          blurRadius: 8,
                          offset: Offset(-3, -3),
                        ),
                      ],
                    ),
                    child: Center(
                      // Red 3D SOS Dome
                      child: AnimatedScale(
                        scale: _isHolding ? 0.94 : 1.0,
                        duration: const Duration(milliseconds: 120),
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              center: Alignment(-0.1, -0.35),
                              radius: 0.85,
                              colors: [
                                Color(0xFFFF3B50),
                                Color(0xFFE51D33),
                                Color(0xFFC71024),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE51D33).withValues(alpha: 0.45),
                                blurRadius: 22,
                                spreadRadius: 2,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                '*',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  height: 0.8,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'SOS',
                                style: GoogleFonts.manrope(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isHolding ? 'HOLD ($_secondsLeft s)' : 'EMERGENCY',
                                style: GoogleFonts.manrope(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Subtitle Instruction
          Text(
            'Hold 3 seconds to alert your emergency contact',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: const Color(0xFF1E293B),
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),

          const SizedBox(height: 12),

          // GPS location line: ready / waiting
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(AppColors.radiusPill),
              border: Border.all(
                color: _isGpsReady ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isGpsReady
                        ? const Color(0xFF10B981)
                        : (_isCheckingGps ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8)),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _isCheckingGps
                        ? 'GPS location: checking...'
                        : (_isGpsReady ? 'GPS location: ready' : 'GPS location: waiting'),
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      color: _isGpsReady ? const Color(0xFF047857) : const Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Recessed GPS & Cellular signal pill
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.sensors_rounded,
                color: Color(0xFF94A3B8),
                size: 13,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  "Uses your phone's GPS and cellular signal",
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    color: const Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
