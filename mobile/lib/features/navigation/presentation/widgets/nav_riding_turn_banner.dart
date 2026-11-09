import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../controllers/navigation_controller.dart';

/// Google-Maps-style top guidance banner shown during active RIDING state:
/// - Full-width dark obsidian header (#12161F) seated below the status bar.
/// - 60 px white maneuver icon on the left.
/// - Live distance countdown (36 px, weight 800) over bold road name (19 px, ellipsis, multi-script safe).
/// - Attached "Then" tab at bottom-left previewing the maneuver after next.
/// - Amber offline warning banner if rerouting fails due to lost internet.
class NavRidingTurnBanner extends StatelessWidget {
  const NavRidingTurnBanner({
    required this.controller,
    super.key,
  });

  final NavigationController controller;

  @override
  Widget build(BuildContext context) {
    final step = controller.currentStep;
    if (step == null) {
      return const SizedBox.shrink();
    }

    final nextStep = controller.nextStep;
    final topPadding = MediaQuery.of(context).padding.top;

    // Format distance: "m" under 1 km, "km" above with 1 decimal place
    final double distM = step.distanceMeters;
    final String distanceText = distM < 1000
        ? '${distM.round()} m'
        : '${(distM / 1000.0).toStringAsFixed(1)} km';

    // Road name / instruction according to existing wording rules:
    // If step begins with "Continue" (from normalization or reroute), show full instruction.
    // Otherwise show streetName if available, or fall back to instruction text.
    final String roadText;
    final cleanStreet = step.streetName.trim();
    if (step.instruction.startsWith('Continue')) {
      roadText = step.instruction;
    } else if (cleanStreet.isNotEmpty) {
      roadText = cleanStreet;
    } else {
      roadText = step.instruction;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Main Top Guidance Banner ─────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(16, topPadding + 10, 16, 16),
          decoration: const BoxDecoration(
            color: Color(0xFF12161F),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 60 px white turn icon
              SizedBox(
                width: 60,
                height: 60,
                child: Center(
                  child: Icon(
                    step.icon,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Live countdown distance over road name (safe on 360 px width and Urdu script)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      distanceText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      roadText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── "Then" Tab Attached Under Left Edge of Banner ────────────────────
        if (nextStep != null)
          Container(
            margin: const EdgeInsets.only(left: 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF12161F),
              borderRadius: BorderRadius.only(
                bottomRight: Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Then',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  nextStep.icon,
                  size: 18,
                  color: Colors.white,
                ),
              ],
            ),
          ),

        // ── Amber "No Internet" Alert Strip Under "Then" Tab ──────────────────
        if (controller.isRerouteFailed)
          Container(
            key: const ValueKey('nav_no_internet_banner'),
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFCD34D),
                width: 1.2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  size: 20,
                  color: Color(0xFF92400E),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.manrope(
                        fontSize: 12.5,
                        color: const Color(0xFF92400E),
                        height: 1.35,
                      ),
                      children: const [
                        TextSpan(
                          text: 'No internet. ',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        TextSpan(
                          text:
                              'Rerouting and new map tiles are unavailable. GPS tracking keeps running.',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
