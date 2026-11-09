import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/route_pack_model.dart';

/// Card representing a route pack.
/// Conforms to CAMP honesty rules:
/// - Every pack shows "Coming soon"
/// - No sizes (MB/GB), download buttons, progress bars, or "downloaded" states
/// - Clean layout preserving card typography and design hierarchy
class RoutePackCardWidget extends StatelessWidget {
  const RoutePackCardWidget({
    required this.pack,
    super.key,
    this.onActionTap,
  });

  final RoutePack pack;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return CampCard(
      padding: const EdgeInsets.all(AppColors.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Title, Category & "Coming soon" Badge ──────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pack.title,
                      style: GoogleFonts.manrope(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkCharcoal,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      pack.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildComingSoonBadge(),
            ],
          ),

          const SizedBox(height: 10),

          // ── Description ───────────────────────────────────────────────────
          Text(
            pack.description,
            style: GoogleFonts.manrope(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.darkCharcoal.withValues(alpha: 0.8),
              height: 1.35,
            ),
          ),

          // ── Note row in InsetTile (only if non-empty and honest) ──────────
          if (pack.note != null && pack.note!.isNotEmpty) ...[
            const SizedBox(height: 10),
            InsetTile(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    pack.noteIcon ?? Icons.info_outline_rounded,
                    size: 15,
                    color: AppColors.mutedText,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pack.note!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkCharcoal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComingSoonBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.clayDark,
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
      ),
      child: Text(
        'Coming soon',
        style: GoogleFonts.manrope(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: AppColors.mutedText,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
