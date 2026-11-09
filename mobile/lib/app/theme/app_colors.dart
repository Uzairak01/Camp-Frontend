import 'package:flutter/material.dart';

/// CAMP Skeuomorphic Design System — Color Palette & Shadows
class AppColors {
  AppColors._();

  // ── Core Tactile Clay Background ──────────────────────────────────────────
  static const Color background = Color(0xFF1E1E1E);
  static const Color clay = Color(0xFFEDF1F7);
  static const Color clayDark = Color(0xFFE3E8F0);    // recessed/inset surfaces
  static const Color clayDeep = Color(0xFFD5DCE7);    // deep pressed surfaces

  // ── Layout & Shape Tokens ─────────────────────────────────────────────────
  static const double radiusCard = 26;
  static const double radiusTile = 18;
  static const double radiusPill = 999;
  static const double screenPadding = 16;
  static const double cardGap = 16;
  static const double cardPadding = 18;

  // ── Skeuomorphic Dual-Shadow System ──────────────────────────────────────
  /// Raised extrusion (convex / floating element)
  static List<BoxShadow> get skeuRaised => const [
        BoxShadow(
          color: Color(0xFFFFFFFF),
          offset: Offset(-5, -5),
          blurRadius: 10,
          spreadRadius: 1,
        ),
        BoxShadow(
          color: Color(0x33A3B1C6),
          offset: Offset(6, 6),
          blurRadius: 12,
          spreadRadius: 1,
        ),
      ];

  /// Subtle raised (smaller buttons / badges)
  static List<BoxShadow> get skeuRaisedSmall => const [
        BoxShadow(
          color: Color(0xFFFFFFFF),
          offset: Offset(-3, -3),
          blurRadius: 7,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Color(0x28A3B1C6),
          offset: Offset(3, 3),
          blurRadius: 8,
          spreadRadius: 0,
        ),
      ];

  /// Recessed / inset element (voice bar, input fields)
  static List<BoxShadow> get skeuRecessed => const [
        BoxShadow(
          color: Color(0xFFFFFFFF),
          offset: Offset(3, 3),
          blurRadius: 6,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Color(0x3CA3B1C6),
          offset: Offset(-3, -3),
          blurRadius: 6,
          spreadRadius: 0,
        ),
      ];

  /// Alias for recessed / inset element
  static List<BoxShadow> get skeuInset => skeuRecessed;

  /// Floating dark dock
  static List<BoxShadow> get dockShadow => [
        const BoxShadow(
          color: Color(0xFF000000),
          offset: Offset(0, 8),
          blurRadius: 24,
          spreadRadius: 2,
        ),
        BoxShadow(
          color: const Color(0xFF000000).withValues(alpha: 0.15),
          offset: const Offset(0, 2),
          blurRadius: 6,
        ),
      ];

  // ── Primary Accent: Tactical Orange ──────────────────────────────────────
  static const Color tacticalOrange = Color(0xFFFA7014);
  static const Color tacticalOrangeDark = Color(0xFFD95200);
  static const Color tacticalOrangeLight = Color(0xFFFF8C3A);

  /// Glowing orange button drop-shadow
  static List<BoxShadow> get orangeGlow => const [
        BoxShadow(
          color: Color(0x66F56500),
          offset: Offset(0, 4),
          blurRadius: 12,
          spreadRadius: 0,
        ),
      ];

  // ── Cockpit Card (Dark Espresso) ──────────────────────────────────────────
  static const Color cockpitGradientStart = Color(0xFF3E2619);
  static const Color cockpitGradientMid   = Color(0xFF29180F);
  static const Color cockpitGradientEnd   = Color(0xFF1A0E08);
  static const Color cockpitBannerBg      = Color(0xFF1D1009);

  /// Bezel ring around the dark cockpit card
  static List<BoxShadow> get cockpitBezel => const [
        BoxShadow(
          color: Color(0xFFFFFFFF),
          offset: Offset(-4, -4),
          blurRadius: 8,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Color(0x44A3B1C6),
          offset: Offset(6, 6),
          blurRadius: 16,
          spreadRadius: 2,
        ),
      ];

  // ── Typography ────────────────────────────────────────────────────────────
  static const Color darkCharcoal  = Color(0xFF14171A);
  static const Color charcoalLight = Color(0xFF3D3A35);
  static const Color mutedText     = Color(0xFF6B7280);
  static const Color mutedLight    = Color(0xFF9CA3AF);

  // ── Status Colors ─────────────────────────────────────────────────────────
  static const Color statusGreen  = Color(0xFF22C55E);
  static const Color statusYellow = Color(0xFFFBBF24);
  static const Color alertRed     = Color(0xFFDC2626);
  static const Color alertRedBg   = Color(0xFFFEE2E2);
  static const Color terracotta   = Color(0xFF8A4C24);

  // ── Floating Dock ─────────────────────────────────────────────────────────
  static const Color dockBackground = Color(0xFF14171A);
}
