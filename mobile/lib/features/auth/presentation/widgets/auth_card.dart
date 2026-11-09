import 'dart:ui';
import 'package:flutter/material.dart';

/// Translucent glassmorphic card container providing a tactical frosted blur
/// over the dusk mountain background.
///
/// Implements a single [BackdropFilter] layer with sigma 14, a translucent dark
/// fill (at roughly 18-20% opacity), a 1px crisp white border (25% opacity),
/// and a soft drop shadow, maintaining optimal frame rates on low-end hardware.
class AuthCard extends StatelessWidget {
  /// Creates a frosted glass [AuthCard] wrapping [child].
  const AuthCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
  });

  /// Card body contents.
  final Widget child;

  /// Inner padding of the card.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1A17).withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                offset: Offset(0, 16),
                blurRadius: 36,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
