import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../garage/controllers/active_bike_controller.dart';
import '../../../maintenance/controllers/post_ride_report_controller.dart';
import '../../domain/stat_model.dart';
import 'stat_tile_widget.dart';

/// Your rides summary card.
/// Displays real totals derived from saved [PostRideReport]s and active bike stats:
/// total distance, number of rides, saddle time (hidden if none entered),
/// and the active bike's saved fuel average.
class SeasonSummaryCardWidget extends StatelessWidget {
  const SeasonSummaryCardWidget({super.key});

  static String _formatNumber(int number) {
    final s = number.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buffer.write(s[i]);
      count++;
      if (count % 3 == 0 && i > 0) {
        buffer.write(',');
      }
    }
    return buffer.toString().split('').reversed.join('');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        PostRideReportController.instance,
        ActiveBikeController.instance,
      ]),
      builder: (context, _) {
        final reports = PostRideReportController.instance.reports;

        if (reports.isEmpty) {
          return CampCard(
            padding: const EdgeInsets.all(AppColors.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your rides',
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkCharcoal,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.route_rounded,
                        size: 32,
                        color: AppColors.mutedLight,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No rides logged yet',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Completed rides will appear here with your distance and saddle time totals.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // 1. Total distance
        final totalDistance =
            reports.fold<double>(0.0, (sum, r) => sum + r.distanceKm);
        final distVal = totalDistance == totalDistance.roundToDouble()
            ? _formatNumber(totalDistance.round())
            : totalDistance.toStringAsFixed(1);

        // 2. Rides count
        final ridesCount = reports.length;

        // 3. Saddle time (sum of entered durations, hidden if none entered)
        final saddleTimeHours =
            reports.fold<double>(0.0, (sum, r) => sum + (r.durationHours ?? 0.0));
        final bool showSaddle = saddleTimeHours > 0;
        final saddleVal = saddleTimeHours == saddleTimeHours.roundToDouble()
            ? '${saddleTimeHours.round()}'
            : saddleTimeHours.toStringAsFixed(1);

        // 4. Active bike's saved fuel average
        final activeBike = ActiveBikeController.instance.activeBike;
        final avg = activeBike?.fuelAverageKmPerLiter;

        final stats = <Stat>[
          Stat(label: 'Total distance', value: distVal, unit: 'KM'),
          Stat(label: 'Rides', value: ridesCount.toString()),
          if (showSaddle)
            Stat(label: 'Saddle time', value: saddleVal, unit: 'HRS'),
          Stat(
            label: 'Bike average',
            value: avg != null ? avg.toStringAsFixed(1) : '—',
            unit: avg != null ? 'KM/L' : null,
          ),
        ];

        return CampCard(
          padding: const EdgeInsets.all(AppColors.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your rides',
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkCharcoal,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (int i = 0; i < stats.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: InsetTile(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        child: StatTileWidget(stat: stats[i]),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
