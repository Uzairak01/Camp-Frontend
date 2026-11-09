import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/auth_colors.dart';

/// Top branding header for CAMP Auth screens.
///
/// Displays the official CAMP logo and wordmark (without the orange dot).
/// All unbacked status pills (EXPEDITION • ADVENTURE, SYNC) and the compass
/// button have been removed in accordance with the Phase H-1 honesty pass.
class AuthBrandHeader extends StatelessWidget {
  /// Header for the Sign In screen featuring the centered CAMP logo and wordmark.
  const AuthBrandHeader.signIn({
    super.key,
    this.onCompassTap,
  })  : isSignUp = false,
        onBack = null,
        onSyncTap = null;

  /// Header for the Sign Up and Forgot Password screens featuring the Back button
  /// and centered CAMP logo and wordmark without the SYNC pill.
  const AuthBrandHeader.signUp({
    super.key,
    this.onBack,
    this.onSyncTap,
  })  : isSignUp = true,
        onCompassTap = null;

  /// Whether this header is rendering in the sign-up / back-navigation layout.
  final bool isSignUp;

  /// Optional legacy callback retained for backwards-compatibility.
  final VoidCallback? onCompassTap;

  /// Callback when the back navigation button is tapped.
  final VoidCallback? onBack;

  /// Optional legacy callback retained for backwards-compatibility.
  final VoidCallback? onSyncTap;

  Widget _buildBrandMark() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Rounded square badge with CAMP app icon
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/icons/app_icon.png',
              width: 44,
              height: 44,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'CAMP',
          style: GoogleFonts.manrope(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  /// Sign In Header: Centered Logo and CAMP text without compass or EXPEDITION pill.
  Widget _buildSignInHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Center(
        child: _buildBrandMark(),
      ),
    );
  }

  /// Sign Up Header: Back Button (left) and centered CAMP mark without SYNC pill.
  Widget _buildSignUpHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: onBack ?? () => Navigator.of(context).maybePop(),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AuthColors.pillDarkBg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AuthColors.pillBorder,
                  width: 1,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
          _buildBrandMark(),
          // Balances the back button width so the brand mark stays centered
          const SizedBox(width: 42),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isSignUp) {
      return _buildSignUpHeader(context);
    }
    return _buildSignInHeader(context);
  }
}
