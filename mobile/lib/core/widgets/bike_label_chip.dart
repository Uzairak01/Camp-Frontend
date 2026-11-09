import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_colors.dart';
import '../../features/garage/controllers/active_bike_controller.dart';

/// Small tactical label chip displaying the motorcycle associated with a
/// maintenance item or service visit.
///
/// Reactively displays the bike's current display name from [ActiveBikeController]
/// so renames automatically follow. Shows "Deleted bike" if the bike ID no longer
/// exists in the garage, or "No bike" if unassigned (e.g. legacy records).
class BikeLabelChip extends StatelessWidget {
  const BikeLabelChip({
    super.key,
    this.bikeId,
    this.padding = const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
    this.controller,
  });

  final String? bikeId;
  final EdgeInsetsGeometry padding;
  final ActiveBikeController? controller;

  @override
  Widget build(BuildContext context) {
    final effectiveController = controller ?? ActiveBikeController.instance;

    return ListenableBuilder(
      listenable: effectiveController,
      builder: (context, _) {
        final String label;
        final bool isDeleted;
        final bool isNoBike;

        final rawId = bikeId?.trim();
        if (rawId == null || rawId.isEmpty) {
          label = 'No bike';
          isDeleted = false;
          isNoBike = true;
        } else {
          final bike = effectiveController.getBikeById(rawId);
          if (bike != null) {
            label = bike.name;
            isDeleted = false;
            isNoBike = false;
          } else {
            label = 'Deleted bike';
            isDeleted = true;
            isNoBike = false;
          }
        }

        final Color textColor = isDeleted
            ? AppColors.alertRed
            : (isNoBike ? AppColors.mutedText : AppColors.darkCharcoal);

        final Color backgroundColor = isDeleted
            ? AppColors.alertRedBg
            : (isNoBike
                ? AppColors.clayDark.withValues(alpha: 0.6)
                : AppColors.clayDark);

        final Color borderColor = isDeleted
            ? AppColors.alertRed.withValues(alpha: 0.3)
            : (isNoBike
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.45));

        return Container(
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(AppColors.radiusPill),
            border: Border.all(color: borderColor, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.two_wheeler_rounded,
                size: 11,
                color: textColor,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
