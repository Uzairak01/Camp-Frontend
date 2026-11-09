import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/icon_tile.dart';

/// Reusable list row widget for the CAMP Settings screen.
class SettingsRowWidget extends StatelessWidget {
  const SettingsRowWidget({
    required this.title,
    super.key,
    this.subtitle,
    this.icon,
    this.customLeading,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? customLeading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final leadingWidget = customLeading ??
        IconTile(
          icon: icon ?? Icons.settings_outlined,
          size: 38,
          iconSize: 18,
          isInset: true,
          borderRadius: 12,
        );

    final rowContent = Padding(
      padding: const EdgeInsets.symmetric(vertical: 9.0, horizontal: 2.0),
      child: Row(
        children: [
          leadingWidget,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkCharcoal,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      color: AppColors.mutedText,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing ??
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.mutedLight,
                size: 20,
              ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: rowContent,
      );
    }
    return rowContent;
  }
}

/// Category header row inside each Settings Card (e.g. "ACCOUNT", "PREFERENCES")
class SettingsCardHeader extends StatelessWidget {
  const SettingsCardHeader({
    required this.icon,
    required this.title,
    super.key,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 2.0),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: AppColors.tacticalOrange,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.tacticalOrange,
            ),
          ),
        ],
      ),
    );
  }
}
