import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// CAMP Raised Card
/// Skeuomorphic tactile card utilizing [AppColors.clay], [AppColors.radiusCard],
/// and [AppColors.skeuRaised] dual-shadow elevation.
class CampCard extends StatelessWidget {
  const CampCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(AppColors.cardPadding),
    this.borderRadius = AppColors.radiusCard,
    this.color,
    this.gradient,
    this.shadows,
    this.border,
    this.onTap,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? color;
  final Gradient? gradient;
  final List<BoxShadow>? shadows;
  final BoxBorder? border;
  final VoidCallback? onTap;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? AppColors.clay) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border,
        boxShadow: shadows ?? AppColors.skeuRaised,
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: card,
      );
    }

    return card;
  }
}
