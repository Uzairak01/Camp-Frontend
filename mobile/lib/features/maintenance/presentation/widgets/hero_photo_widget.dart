import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/widgets.dart';

/// Hero photo widget showing the active motorcycle expedition photo with
/// bottom overlay displaying bike model and masked VIN.
class HeroPhotoWidget extends StatelessWidget {
  const HeroPhotoWidget({
    super.key,
    this.bikeName = '🏍 KTM 890 Adventure R',
    this.vinSnippet = 'VIN ••9482',
    this.imagePath = 'assets/images/bmw_r1250_scan_placeholder.jpg',
    this.height = 180,
  });

  final String bikeName;
  final String vinSnippet;
  final String imagePath;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.clayDark,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        boxShadow: AppColors.skeuRaised,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image
            CampBikeImage(
              imagePath: imagePath,
              fit: BoxFit.cover,
            ),

            // Top subtle vignette and Bottom dark gradient for high legibility
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.15),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                      Colors.black.withValues(alpha: 0.92),
                    ],
                    stops: const [0.0, 0.4, 0.8, 1.0],
                  ),
                ),
              ),
            ),

            // Bottom-left Bike Name and Bottom-right VIN
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      bikeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        shadows: const [
                          Shadow(
                            color: Colors.black54,
                            offset: Offset(0, 1),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      vinSnippet,
                      style: GoogleFonts.jetBrainsMono(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
