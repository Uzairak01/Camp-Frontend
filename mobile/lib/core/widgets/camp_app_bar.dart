import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_colors.dart';

/// CAMP Mountain Mark Logo Painter
class CampMountainLogoPainter extends CustomPainter {
  const CampMountainLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final greenPaint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..style = PaintingStyle.fill;
    final orangePaint = Paint()
      ..color = AppColors.tacticalOrange
      ..style = PaintingStyle.fill;

    canvas.drawPath(
      Path()
        ..moveTo(0, size.height)
        ..lineTo(size.width * 0.45, size.height * 0.1)
        ..lineTo(size.width * 0.7, size.height)
        ..close(),
      greenPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.4, size.height)
        ..lineTo(size.width * 0.75, 0)
        ..lineTo(size.width, size.height)
        ..close(),
      orangePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Mode of leading button on [CampAppBar]
enum CampAppBarLeading {
  menu,
  back,
  none,
}

/// CAMP Top App Bar
/// Circular back/menu button left, optional screen title or Home CAMP logo center, optional action pill right.
/// Conforms to BATCH UI-1: Only Home screen header shows the CAMP brand mark (icon + text, no dot).
/// Every other screen has the brand mark removed (showLogo defaults to false).
class CampAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CampAppBar({
    super.key,
    this.leading = CampAppBarLeading.menu,
    this.onLeadingPressed,
    this.titleText,
    this.titleWidget,
    this.showLogo = false,
    this.showDot = false,
    this.actionText,
    this.actionIcon,
    this.actionWidget,
    this.onActionPressed,
    this.padding = const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
  });

  final CampAppBarLeading leading;
  final VoidCallback? onLeadingPressed;
  final String? titleText;
  final Widget? titleWidget;
  final bool showLogo;
  final bool showDot;
  final String? actionText;
  final IconData? actionIcon;
  final Widget? actionWidget;
  final VoidCallback? onActionPressed;
  final EdgeInsetsGeometry padding;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 60,
        child: Padding(
          padding: padding,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Left: Circular Back / Menu Button ─────────────────────────────
              _buildLeading(context),

              // ── Center: Custom Widget, Screen Title or Logo (Home Only) ───────
              if (titleWidget != null)
                Flexible(child: Center(child: titleWidget!))
              else if (titleText != null && titleText != 'CAMP')
                Flexible(
                  child: Text(
                    titleText!,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      color: AppColors.darkCharcoal,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                )
              else if (showLogo)
                CampLogo(showDot: showDot)
              else
                const SizedBox.shrink(),

              // ── Right: Optional Action Pill or Widget ─────────────────────────
              Flexible(
                child: _buildAction(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeading(BuildContext context) {
    if (leading == CampAppBarLeading.none) {
      return const SizedBox(width: 48, height: 48);
    }

    if (leading == CampAppBarLeading.back) {
      return CampBackButton(onTap: onLeadingPressed);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onLeadingPressed,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.clay,
          shape: BoxShape.circle,
          boxShadow: AppColors.skeuRaisedSmall,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _bar(),
              const SizedBox(height: 3.2),
              _bar(),
              const SizedBox(height: 3.2),
              _bar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bar() => Container(
        width: 17,
        height: 2.2,
        decoration: BoxDecoration(
          color: AppColors.darkCharcoal,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _buildAction() {
    if (actionWidget != null) {
      return actionWidget!;
    }

    if (actionText != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onActionPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.clay,
            borderRadius: BorderRadius.circular(AppColors.radiusPill),
            boxShadow: AppColors.skeuRaisedSmall,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (actionIcon != null) ...[
                Icon(actionIcon, size: 15, color: AppColors.tacticalOrange),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  actionText!,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    color: AppColors.terracotta,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox(width: 48, height: 48);
  }
}

/// Circular back button styled with CAMP 48px circle and skeuRaisedSmall shadow.
class CampBackButton extends StatelessWidget {
  const CampBackButton({
    super.key,
    this.onTap,
    this.icon = Icons.arrow_back_rounded,
  });

  final VoidCallback? onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap ?? () => Navigator.of(context).maybePop(),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.clay,
          shape: BoxShape.circle,
          boxShadow: AppColors.skeuRaisedSmall,
        ),
        child: Center(
          child: Icon(icon, color: AppColors.darkCharcoal, size: 20),
        ),
      ),
    );
  }
}

/// Standard CAMP Logo: app icon mark with bold "CAMP" text and optional tactical orange dot mark.
/// Conforms to BATCH UI-1: Home screen header renders with [showDot] = false (logo icon + "CAMP", no dot).
/// Navigation drawer renders with [showDot] = true to preserve its full brand mark.
class CampLogo extends StatelessWidget {
  const CampLogo({
    super.key,
    this.fontSize = 20,
    this.dotSize = 7,
    this.iconSize = 28,
    this.showIcon = true,
    this.showDot = false,
  });

  final double fontSize;
  final double dotSize;
  final double iconSize;
  final bool showIcon;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showIcon) ...[
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(iconSize * 0.25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 4,
                  offset: const Offset(0, 1.5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(iconSize * 0.25),
              child: Image.asset(
                'assets/icons/app_icon.png',
                width: iconSize,
                height: iconSize,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          'CAMP',
          style: GoogleFonts.manrope(
            color: AppColors.darkCharcoal,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
        if (showDot) ...[
          const SizedBox(width: 5),
          Container(
            key: const ValueKey('camp_logo_dot'),
            width: dotSize,
            height: dotSize,
            decoration: const BoxDecoration(
              color: AppColors.tacticalOrange,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    );
  }
}
