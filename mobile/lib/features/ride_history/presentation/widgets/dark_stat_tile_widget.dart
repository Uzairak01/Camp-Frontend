import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/stat_model.dart';
import 'stat_tile_widget.dart';

/// Translucent dark stat tile used in dark cockpit cards.
/// Replaces oversized/glowing light InsetTile with a subtle (~8-10% alpha)
/// translucent surface with rounded corners and no shadows or glow.
class DarkStatTile extends StatelessWidget {
  const DarkStatTile({
    required this.stat,
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  });

  final Stat stat;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppColors.radiusTile),
      ),
      child: StatTileWidget(stat: stat, dark: true),
    );
  }
}
