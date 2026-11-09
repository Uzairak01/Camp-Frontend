import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../../app/theme/app_colors.dart';

/// 52 px circular compass button shown during active RIDING state:
/// - Visual needle displaying the active map orientation relative to North.
/// - Sets map rotation back to North-up (0°) when tapped.
/// - Accessible with semantic label "Compass" and >= 44 px touch target.
class NavCompassButton extends StatelessWidget {
  const NavCompassButton({
    required this.mapController,
    super.key,
  });

  final MapController mapController;

  double _getMapRotationDegrees() {
    try {
      return mapController.camera.rotation;
    } catch (_) {
      return 0.0;
    }
  }

  void _resetNorth() {
    mapController.rotate(0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Compass',
      button: true,
      child: GestureDetector(
        key: const ValueKey('nav_compass_button'),
        onTap: _resetNorth,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF1E222D),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: StreamBuilder<MapEvent>(
            stream: mapController.mapEventStream,
            builder: (context, _) {
              final rotationDeg = _getMapRotationDegrees();
              final rotationRad = -rotationDeg * (math.pi / 180.0);

              return Center(
                child: Transform.rotate(
                  angle: rotationRad,
                  child: CustomPaint(
                    size: const Size(16, 26),
                    painter: _CompassNeedlePainter(),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Draws a two-tone tactical compass needle (orange North, white/light South).
class _CompassNeedlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double midX = size.width / 2;
    final double midY = size.height / 2;

    // North half (Orange)
    final northPath = Path()
      ..moveTo(midX, 0)
      ..lineTo(size.width, midY)
      ..lineTo(midX, midY - 2)
      ..close();

    final northPaint = Paint()
      ..color = AppColors.tacticalOrange
      ..style = PaintingStyle.fill;
    canvas.drawPath(northPath, northPaint);

    final northLeftPath = Path()
      ..moveTo(midX, 0)
      ..lineTo(0, midY)
      ..lineTo(midX, midY - 2)
      ..close();

    final northLeftPaint = Paint()
      ..color = AppColors.tacticalOrangeLight
      ..style = PaintingStyle.fill;
    canvas.drawPath(northLeftPath, northLeftPaint);

    // South half (White/Grey)
    final southPath = Path()
      ..moveTo(midX, size.height)
      ..lineTo(size.width, midY)
      ..lineTo(midX, midY + 2)
      ..close();

    final southPaint = Paint()
      ..color = const Color(0xFFD1D5DB)
      ..style = PaintingStyle.fill;
    canvas.drawPath(southPath, southPaint);

    final southLeftPath = Path()
      ..moveTo(midX, size.height)
      ..lineTo(0, midY)
      ..lineTo(midX, midY + 2)
      ..close();

    final southLeftPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawPath(southLeftPath, southLeftPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

