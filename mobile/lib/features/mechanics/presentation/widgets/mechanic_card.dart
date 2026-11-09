import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/mechanic_model.dart';
import '../../domain/mechanic_open_status.dart';

class MechanicCard extends StatelessWidget {
  const MechanicCard({
    required this.mechanic,
    super.key,
    this.userLatitude,
    this.userLongitude,
    this.onTap,
    this.onCallShop,
    this.onRouteGps,
    this.onEdit,
    this.onDelete,
  });

  final Mechanic mechanic;
  final double? userLatitude;
  final double? userLongitude;
  final VoidCallback? onTap;
  final VoidCallback? onCallShop;
  final VoidCallback? onRouteGps;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  static const LinearGradient _orangeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.tacticalOrangeLight, AppColors.tacticalOrange],
  );

  /// Computes straight-line distance if and only if shop has coordinates
  /// AND user phone location is available.
  String? get _displayDistance {
    if (mechanic.hasCoordinates && userLatitude != null && userLongitude != null) {
      final km = computeStraightLineDistanceKm(
        lat1: userLatitude!,
        lon1: userLongitude!,
        lat2: mechanic.latitude!,
        lon2: mechanic.longitude!,
      );
      return formatDistance(km);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final status = mechanicOpenStatus(mechanic, DateTime.now());
    final hasPhone = (mechanic.phoneNumber ?? mechanic.phone).trim().isNotEmpty;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: AppColors.clay,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.clayDark, width: 1.2),
          boxShadow: AppColors.skeuRaised,
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Fixed 56px Thumbnail + Name & Location & Badge Column + Overflow Menu
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fixed 56px photo thumbnail slot (or fallback icon)
                _buildPhotoThumbnail(mechanic.photoPath, size: 56),
                const SizedBox(width: 14),

                // Name Column: Full-width shop name (max 2 lines, ellipsis) + location + badge under name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mechanic.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.cardTitle.copyWith(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 5),

                      // Location & Distance line (distance only when shop has coordinates and phone GPS is available)
                      Builder(
                        builder: (context) {
                          final dist = _displayDistance;
                          final loc = (mechanic.address != null && mechanic.address!.isNotEmpty)
                              ? mechanic.address!
                              : (mechanic.durationOrLocation.isNotEmpty &&
                                      mechanic.durationOrLocation != 'Nearby' &&
                                      mechanic.durationOrLocation != 'Local Workshop' &&
                                      !mechanic.durationOrLocation.contains('min')
                                  ? mechanic.durationOrLocation
                                  : null);
                          final parts = [?dist, ?loc];
                          if (parts.isEmpty) return const SizedBox.shrink();

                          return Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: AppColors.tacticalOrange,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  parts.join('  •  '),
                                  style: AppTextStyles.bodySecondary.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 6),

                      // Badge: Honest rider-added tag
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildAddedByYouTag(),
                        ],
                      ),
                    ],
                  ),
                ),

                // Single overflow (three-dot) menu at top right
                if (onEdit != null || onDelete != null)
                  _buildOverflowMenu(context),
              ],
            ),

            const SizedBox(height: 14),

            // Category 1 (e.g. SPECIALTIES / CERTIFIED PLATFORMS)
            if (mechanic.tags1.isNotEmpty) ...[
              Text(
                mechanic.categoryTitle1,
                style: AppTextStyles.overline.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: mechanic.tags1
                    .map((tag) => _buildTag(tag))
                    .toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Category 2 (FIELD CAPABILITIES / LOCATION)
            if (mechanic.tags2.isNotEmpty &&
                !(mechanic.tags2.length == 1 &&
                    mechanic.tags2.first == mechanic.durationOrLocation)) ...[
              Text(
                mechanic.categoryTitle2,
                style: AppTextStyles.overline.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: mechanic.tags2
                    .map((tag) => _buildTag(tag))
                    .toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Open Status (Show only when real hours are set on shop)
            if (!status.isNotSet) ...[
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: status.isOpen
                          ? AppColors.statusGreen
                          : AppColors.mutedText,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      status.displayText,
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: status.isOpen
                            ? AppColors.statusGreen
                            : AppColors.mutedText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ] else ...[
              const SizedBox(height: 4),
            ],

            const SizedBox(height: 16),

            // Action Buttons: Call Now & Route GPS
            Row(
              children: [
                if (hasPhone) ...[
                  // Call Now Button
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: AppColors.skeuRaisedSmall,
                      ),
                      child: OutlinedButton.icon(
                        onPressed: onCallShop,
                        icon: const Icon(
                          Icons.call_outlined,
                          size: 16,
                          color: AppColors.darkCharcoal,
                        ),
                        label: Text(
                          'Call Now',
                          style: AppTextStyles.body.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkCharcoal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                          side: const BorderSide(
                            color: AppColors.clayDark,
                            width: 1.2,
                          ),
                          backgroundColor: AppColors.clay,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],

                // Route GPS Button
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: _orangeGradient,
                      boxShadow: AppColors.orangeGlow,
                    ),
                    child: ElevatedButton(
                      onPressed: onRouteGps,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.keyboard_double_arrow_right_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Route GPS',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoThumbnail(String? photoPath, {double size = 56}) {
    final file = photoPath != null && photoPath.isNotEmpty ? File(photoPath) : null;
    final exists = file != null && file.existsSync();

    if (exists) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.clayDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.clayDark, width: 1.2),
          boxShadow: AppColors.skeuRaisedSmall,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Image.file(
            file,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _buildFallbackThumbnail(size),
          ),
        ),
      );
    }

    return _buildFallbackThumbnail(size);
  }

  Widget _buildFallbackThumbnail(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.clayDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.clayDark, width: 1.2),
        boxShadow: AppColors.skeuRecessed,
      ),
      child: Center(
        child: Icon(
          Icons.storefront_rounded,
          size: size * 0.48,
          color: AppColors.tacticalOrange,
        ),
      ),
    );
  }


  Widget _buildAddedByYouTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.clayDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.clayDark, width: 1.0),
        boxShadow: AppColors.skeuRaisedSmall,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.person_pin_circle_outlined,
            size: 12,
            color: AppColors.charcoalLight,
          ),
          const SizedBox(width: 4),
          Text(
            'Added by you',
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.charcoalLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverflowMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.more_vert_rounded,
        size: 20,
        color: AppColors.mutedLight,
      ),
      padding: EdgeInsets.zero,
      color: AppColors.clay,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.clayDark, width: 1),
      ),
      onSelected: (value) {
        if (value == 'edit') {
          onEdit?.call();
        } else if (value == 'delete') {
          onDelete?.call();
        }
      },
      itemBuilder: (ctx) => [
        if (onEdit != null)
          PopupMenuItem<String>(
            value: 'edit',
            height: 38,
            child: Row(
              children: [
                const Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: AppColors.charcoalLight,
                ),
                const SizedBox(width: 8),
                Text(
                  'Edit',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoalLight,
                  ),
                ),
              ],
            ),
          ),
        if (onDelete != null)
          PopupMenuItem<String>(
            value: 'delete',
            height: 38,
            child: Row(
              children: [
                const Icon(
                  Icons.delete_outline_rounded,
                  size: 16,
                  color: AppColors.alertRed,
                ),
                const SizedBox(width: 8),
                Text(
                  'Delete',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.alertRed,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.clayDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.clayDark, width: 0.8),
        boxShadow: AppColors.skeuRaisedSmall,
      ),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.charcoalLight,
        ),
      ),
    );
  }
}

/// Modal detail sheet showing complete mechanic info with photo thumbnail and actions.
void showMechanicDetailSheet(
  BuildContext context,
  Mechanic mechanic, {
  double? userLatitude,
  double? userLongitude,
  VoidCallback? onCallShop,
  VoidCallback? onRouteGps,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final photo = mechanic.photoPath;
      final file = photo != null && photo.isNotEmpty ? File(photo) : null;
      final hasPhoto = file != null && file.existsSync();

      String? distStr;
      if (mechanic.hasCoordinates && userLatitude != null && userLongitude != null) {
        final km = computeStraightLineDistanceKm(
          lat1: userLatitude,
          lon1: userLongitude,
          lat2: mechanic.latitude!,
          lon2: mechanic.longitude!,
        );
        distStr = formatDistance(km);
      }

      final locStr = (mechanic.address != null && mechanic.address!.isNotEmpty)
          ? mechanic.address!
          : (mechanic.durationOrLocation.isNotEmpty &&
                  mechanic.durationOrLocation != 'Nearby' &&
                  mechanic.durationOrLocation != 'Local Workshop' &&
                  !mechanic.durationOrLocation.contains('min')
              ? mechanic.durationOrLocation
              : null);
      final locationParts = [?distStr, ?locStr];

      return Container(
        decoration: BoxDecoration(
          color: AppColors.clay,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: AppColors.dockShadow,
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.mutedLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header: Photo Thumbnail + Name + Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photo slot (with fallback icon, never an empty gap)
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.clayDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.clayDark, width: 1.2),
                      boxShadow: AppColors.skeuRaisedSmall,
                    ),
                    child: hasPhoto
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.file(
                              file,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Center(
                                child: Icon(
                                  Icons.storefront_rounded,
                                  size: 32,
                                  color: AppColors.tacticalOrange,
                                ),
                              ),
                            ),
                          )
                        : const Center(
                            child: Icon(
                              Icons.storefront_rounded,
                              size: 32,
                              color: AppColors.tacticalOrange,
                            ),
                          ),
                  ),
                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mechanic.name,
                          style: AppTextStyles.cardTitle.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (locationParts.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 15,
                                color: AppColors.tacticalOrange,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  locationParts.join('  •  '),
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.mutedText,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.mutedText,
                    ),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Details & Attributes
              if (mechanic.phone.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(
                      Icons.phone_rounded,
                      size: 16,
                      color: AppColors.tacticalOrange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      mechanic.phone,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkCharcoal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],

              // Opening Hours
              Builder(
                builder: (context) {
                  final scheduleText = formatMechanicSchedule(mechanic);
                  final detailOpenStatus =
                      mechanicOpenStatus(mechanic, DateTime.now());
                  if (scheduleText == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 16,
                          color: AppColors.tacticalOrange,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                scheduleText,
                                style: AppTextStyles.body.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.darkCharcoal,
                                ),
                              ),
                              if (!detailOpenStatus.isNotSet) ...[
                                const SizedBox(height: 3),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: detailOpenStatus.isOpen
                                            ? AppColors.statusGreen
                                            : AppColors.mutedText,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      detailOpenStatus.displayText,
                                      style: AppTextStyles.caption.copyWith(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: detailOpenStatus.isOpen
                                            ? AppColors.statusGreen
                                            : AppColors.mutedText,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              if (mechanic.notes != null && mechanic.notes!.isNotEmpty) ...[
                Text(
                  'RIDER NOTES',
                  style: AppTextStyles.overline.copyWith(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  mechanic.notes!,
                  style: AppTextStyles.bodySecondary.copyWith(
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Actions Row: Call + Route
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onCallShop?.call();
                      },
                      icon: const Icon(Icons.call_rounded, size: 18),
                      label: const Text('Call Workshop'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.tacticalOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onRouteGps?.call();
                      },
                      icon: const Icon(
                        Icons.directions_bike_rounded,
                        size: 18,
                        color: AppColors.darkCharcoal,
                      ),
                      label: Text(
                        'Route GPS',
                        style: AppTextStyles.body.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(
                          color: AppColors.clayDark,
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        backgroundColor: AppColors.clay,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Edit & Delete row
              Row(
                children: [
                  if (onEdit != null)
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          onEdit();
                        },
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: AppColors.charcoalLight,
                        ),
                        label: Text(
                          'Edit Mechanic',
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.charcoalLight,
                          ),
                        ),
                      ),
                    ),
                  if (onDelete != null)
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          onDelete();
                        },
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                          color: AppColors.alertRed,
                        ),
                        label: Text(
                          'Delete',
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.alertRed,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
