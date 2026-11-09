import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../controllers/navigation_controller.dart';
import 'nav_active_bottom_bar.dart';

/// Compact bottom telemetry dock replacing the old ETA card in RIDING state:
/// - Left: Outlined round X button that opens the existing exit confirmation sheet.
/// - Centre: Minutes remaining (emerald green, 28 px) over "X km • Arrive HH:mm".
/// - Right: Round route overview button toggling whole-route camera bounds.
/// - Fully accessible with >= 44 px touch targets and semantic labels.
class NavRidingBottomBar extends StatelessWidget {
  const NavRidingBottomBar({
    required this.controller,
    required this.onConfirmExit,
    this.onToggleOverview,
    super.key,
  });

  final NavigationController controller;
  final VoidCallback onConfirmExit;
  final VoidCallback? onToggleOverview;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    // Remaining along-route metrics
    final remainingDurationText = controller.formattedRemainingDuration;
    final remainingDistanceText = controller.formattedRemainingDistance;
    final etaText = controller.formattedEta;
    final subtitleText = '$remainingDistanceText • Arrive $etaText';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF12161F),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(16, 10, 16, bottomInset + 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Centered Drag Handle ───────────────────────────────────────────
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF374151),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Main Telemetry Row ─────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Left: Outlined Round X Button (>= 44 px target)
              Semantics(
                label: 'End navigation',
                button: true,
                child: GestureDetector(
                  key: const ValueKey('nav_exit_button'),
                  onTap: () => NavActiveBottomBar.promptExitConfirmation(
                    context,
                    onConfirmExit: onConfirmExit,
                  ),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1F2C),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.close_rounded,
                        color: Color(0xFFEF4444),
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // 2. Centre: Minutes Remaining & Distance / ETA Subtitle
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      remainingDurationText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF10B981),
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitleText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // 3. Right: Round Route-Overview Button (>= 44 px target)
              Semantics(
                label: 'Route overview',
                button: true,
                child: GestureDetector(
                  key: const ValueKey('nav_overview_button'),
                  onTap: onToggleOverview,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF26262A),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 1.0,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.alt_route_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

