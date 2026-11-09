import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';

/// A single elevation data point: progress ∈ [0,1], elevationMeters.
class ElevationPoint {
  const ElevationPoint(this.progress, this.elevationMeters);
  final double progress;
  final double elevationMeters;
}

/// Widget #6 — Elevation profile chart with gradient fill, peak marker,
/// floor labels, and a max-grade label.
class ElevationChartWidget extends StatelessWidget {
  const ElevationChartWidget({
    required this.points,
    super.key,
    this.maxGrade = '14.2%',
    this.peakLabel = '4,173m',
    this.baseLabel = '2,100m Base',
    this.midLabel = 'Hairpins Section (18 Turns)',
    this.descentLabel = '1,265m Descent',
  });

  final List<ElevationPoint> points;
  final String maxGrade;
  final String peakLabel;
  final String baseLabel;
  final String midLabel;
  final String descentLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Max grade label — top-right
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'MAX GRADE $maxGrade',
            style: GoogleFonts.manrope(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: AppColors.tacticalOrange,
              letterSpacing: 0.6,
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 80,
          child: CustomPaint(
            painter: _ElevationPainter(
              points: points,
              peakLabel: peakLabel,
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Bottom labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              baseLabel,
              style: GoogleFonts.manrope(
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
            Flexible(
              child: Text(
                midLabel,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            Text(
              descentLabel,
              style: GoogleFonts.manrope(
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ElevationPainter extends CustomPainter {
  _ElevationPainter({required this.points, required this.peakLabel});

  final List<ElevationPoint> points;
  final String peakLabel;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final minElev = points.map((p) => p.elevationMeters).reduce(math.min);
    final maxElev = points.map((p) => p.elevationMeters).reduce(math.max);
    final range = maxElev - minElev;

    double toX(double progress) => progress * size.width;
    double toY(double elev) =>
        size.height - ((elev - minElev) / range) * (size.height - 8);

    final path = Path();
    final first = points.first;
    path.moveTo(toX(first.progress), toY(first.elevationMeters));
    for (final p in points.skip(1)) {
      path.lineTo(toX(p.progress), toY(p.elevationMeters));
    }

    // Gradient fill under the line
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final gradient = ui.Gradient.linear(
      const Offset(0, 0),
      Offset(0, size.height),
      [
        AppColors.tacticalOrange.withValues(alpha: 0.55),
        AppColors.tacticalOrange.withValues(alpha: 0.05),
      ],
    );

    canvas.drawPath(
      fillPath,
      Paint()..shader = gradient,
    );

    // Line
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.tacticalOrange
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );

    // Peak marker dot
    final peakPoint = points.reduce(
      (a, b) => a.elevationMeters >= b.elevationMeters ? a : b,
    );
    final px = toX(peakPoint.progress);
    final py = toY(peakPoint.elevationMeters);

    canvas.drawCircle(
      Offset(px, py),
      4,
      Paint()..color = AppColors.tacticalOrange,
    );
    canvas.drawCircle(
      Offset(px, py),
      2.5,
      Paint()..color = Colors.white,
    );

    // Peak label above the dot
    final tp = TextPainter(
      text: TextSpan(
        text: peakLabel,
        style: GoogleFonts.manrope(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    final labelX = (px - tp.width / 2).clamp(0.0, size.width - tp.width);
    tp.paint(canvas, Offset(labelX, py - 16));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
