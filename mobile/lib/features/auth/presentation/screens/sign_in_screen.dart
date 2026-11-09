import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../controllers/auth_controller.dart';
import '../theme/auth_colors.dart';
import '../widgets/auth_background_scaffold.dart';
import '../widgets/auth_brand_header.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_google_button.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_text_field.dart';

/// CAMP Sign In / Welcome Back Screen.
///
/// Features translucent glassmorphism over the dusk background, empty form
/// fields with clear hints, and authentic error messaging for unknown email
/// and incorrect password conditions.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showNotification(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: isError ? Colors.redAccent : AuthColors.orangeLight,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.manrope(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF26201D),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isError
                ? Colors.redAccent.withValues(alpha: 0.5)
                : AuthColors.orangeBadgeBorder,
            width: 1,
          ),
        ),
        duration: const Duration(milliseconds: 2200),
      ),
    );
  }

  Future<void> _handleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await AuthController.instance.signIn(
      riderIdOrEmail: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      final firstName = AuthController.instance.riderFirstName.trim();
      final welcome = firstName.isNotEmpty
          ? 'Welcome back, $firstName'
          : 'Welcome back';
      _showNotification(welcome);
      Navigator.of(context).pushReplacementNamed(CampRoutes.home);
    } else {
      setState(() {
        _errorMessage = AuthController.instance.state.errorMessage ??
            'Sign in failed. Please check your credentials.';
      });
      _showNotification(_errorMessage!, isError: true);
    }
  }

  /// Handles "Continue with Google" tap.
  ///
  /// Note: Firebase Auth will back this integration in a future release.
  /// For now, an honest notification is displayed and no sign-in is faked.
  void _handleGoogleSignIn() {
    _showNotification('Google sign-in is coming soon');
  }

  @override
  Widget build(BuildContext context) {
    return AuthBackgroundScaffold(
      topBar: const AuthBrandHeader.signIn(),
      bottomBar: _buildFooter(context),
      child: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AuthCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Card Header: Title & Subtitle ────────────────────────
                    Text(
                      'Welcome Back',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        color: AuthColors.textWhite,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sign in to access your cockpit & routes',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        color: AuthColors.textSubtitle,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Field 1: Email ───────────────────────────────────────
                    AuthTextField(
                      label: 'Email',
                      controller: _emailController,
                      hintText: 'Email',
                      prefixIcon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      errorText: _errorMessage,
                    ),

                    const SizedBox(height: 16),

                    // ── Field 2: Password ────────────────────────────────────
                    AuthTextField(
                      label: 'Password',
                      controller: _passwordController,
                      hintText: 'Password',
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _handleSignIn(),
                      trailingWidget: GestureDetector(
                        onTap: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                        child: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AuthColors.inputIcon,
                          size: 20,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Forgot Password Link ─────────────────────────────────
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context)
                            .pushNamed(CampRoutes.forgotPassword),
                        child: Text(
                          'Forgot Password?',
                          style: GoogleFonts.manrope(
                            color: AuthColors.textLabel,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Solid Orange Sign In CTA Button ──────────────────────
                    AuthPrimaryButton(
                      label: 'Sign In',
                      isLoading: _isLoading,
                      onTap: _handleSignIn,
                    ),

                    const SizedBox(height: 14),

                    // ── Outlined Continue with Google Button ─────────────────
                    AuthGoogleButton(
                      onTap: _handleGoogleSignIn,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bottom Footer: "Don't have an account? Sign Up"
  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Don't have an account? ",
            style: GoogleFonts.manrope(
              color: AuthColors.textFooter,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pushNamed(CampRoutes.signUp),
            child: Text(
              'Sign Up',
              style: GoogleFonts.manrope(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                decoration: TextDecoration.underline,
                decorationColor: AuthColors.orangeLight,
                decorationThickness: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
