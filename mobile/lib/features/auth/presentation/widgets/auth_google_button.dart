import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/auth_colors.dart';

/// Outlined "Continue with Google" button for authentication screens.
///
/// Note: Firebase Auth will back this integration in a future release.
/// For now, tapping displays an honest notification indicating that Google
/// sign-in is coming soon, and does not simulate or fake authentication.
class AuthGoogleButton extends StatefulWidget {
  /// Creates a "Continue with Google" button invoking [onTap].
  const AuthGoogleButton({
    required this.onTap,
    super.key,
  });

  /// Action invoked when tapped.
  final VoidCallback onTap;

  @override
  State<AuthGoogleButton> createState() => _AuthGoogleButtonState();
}

class _AuthGoogleButtonState extends State<AuthGoogleButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 50,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1.0,
            ),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.85),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'G',
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Continue with Google',
                  style: GoogleFonts.manrope(
                    color: AuthColors.textWhite,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

