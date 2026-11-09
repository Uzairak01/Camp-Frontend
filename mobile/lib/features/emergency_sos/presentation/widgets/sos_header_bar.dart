import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/camp_app_bar.dart';

/// Top bar with back button, CAMP • logo, and pulsating SOS READY badge
class SosHeaderBar extends StatelessWidget {
  const SosHeaderBar({
    super.key,
    this.onBackPressed,
  });

  final VoidCallback? onBackPressed;

  @override
  Widget build(BuildContext context) {
    return CampAppBar(
      leading: CampAppBarLeading.back,
      onLeadingPressed: onBackPressed,
      actionWidget: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
        decoration: BoxDecoration(
          color: const Color(0xFFEAEFF5),
          borderRadius: BorderRadius.circular(AppColors.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFF7F8EA3),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'SOS READY',
              style: GoogleFonts.manrope(
                color: const Color(0xFF5A6B82),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
