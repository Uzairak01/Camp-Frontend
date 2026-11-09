import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

// Group Beacon needs a backend; parked for the Firebase phase.

/// Placeholder card for Group Beacon displayed on Home outside the Recent activity feed.
/// Features honest "coming soon" messaging without simulated mesh or Bluetooth telemetry claims.
/// Tapping opens a straightforward "Coming soon" informational bottom sheet.
class GroupBeaconCardWidget extends StatelessWidget {
  const GroupBeaconCardWidget({
    super.key,
    this.onTap,
  });

  final VoidCallback? onTap;

  void _showComingSoonSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.mutedLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                ),
                child: const Icon(
                  Icons.track_changes_rounded,
                  size: 30,
                  color: Color(0xFF0D9488),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Group Beacon',
                style: AppTextStyles.title.copyWith(
                  fontSize: 22,
                  color: AppColors.darkCharcoal,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Group Beacon: coming soon',
                style: AppTextStyles.itemTitle.copyWith(
                  color: const Color(0xFF0D9488),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Live group coordination and rider beacons require a backend service to synchronize positions. This feature is parked for the upcoming cloud backend phase.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary.copyWith(
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.tacticalOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppColors.radiusTile),
                    ),
                  ),
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: Text(
                    'Got it',
                    style: AppTextStyles.itemTitle.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CampCard(
      borderRadius: AppColors.radiusTile + 2,
      child: InkWell(
        onTap: onTap ?? () => _showComingSoonSheet(context),
        borderRadius: BorderRadius.circular(AppColors.radiusTile + 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const IconTile(
              icon: Icons.track_changes_rounded,
              iconColor: Color(0xFF0D9488),
              size: 42,
              borderRadius: 14,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Group Beacon',
                          style: AppTextStyles.itemTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Group Beacon: coming soon',
                    style: AppTextStyles.bodySecondary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.mutedLight,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
