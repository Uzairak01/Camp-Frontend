import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../controllers/auth_controller.dart';
import '../theme/auth_colors.dart';
import '../widgets/auth_background_scaffold.dart';
import '../widgets/auth_brand_header.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/motorcycle_badge.dart';
import '../widgets/password_strength_indicator.dart';

/// CAMP Create Account / Register Rider Screen.
///
/// Features translucent glassmorphism over the dusk background, empty input fields,
/// robust client validation, dynamic password strength metering, and persistent
/// local account creation.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  int _passwordStrength = 0;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    final strength =
        AuthController.instance.calculateStrength(_passwordController.text);
    if (strength != _passwordStrength) {
      setState(() => _passwordStrength = strength);
    }
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isError
                ? Colors.redAccent.withValues(alpha: 0.5)
                : AuthColors.orangeBadgeBorder,
            width: 1,
          ),
        ),
        duration: const Duration(milliseconds: 2400),
      ),
    );
  }

  Future<void> _handleRegister() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await AuthController.instance.signUp(
      fullName: _fullNameController.text,
      email: _emailController.text,
      phone: _phoneController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      _showNotification('Rider profile registered successfully!');
      Navigator.of(context).pushReplacementNamed(CampRoutes.home);
    } else {
      setState(() {
        _errorMessage = AuthController.instance.state.errorMessage ??
            'Registration failed. Please check your details.';
      });
      _showNotification(_errorMessage!, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthBackgroundScaffold(
      topBar: AuthBrandHeader.signUp(
        onBack: () => Navigator.of(context).maybePop(),
      ),
      bottomBar: _buildFooter(context),
      child: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AuthCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Motorcycle Avatar Badge ──────────────────────────────
                    const Center(
                      child: MotorcycleBadge(
                        size: 60,
                        iconSize: 28,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Title & Subtitle ─────────────────────────────────────
                    Text(
                      'Create Account',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        color: AuthColors.textWhite,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Start your adventure riding journey',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        color: AuthColors.textSubtitle,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Field 1: Full Name ───────────────────────────────────
                    AuthTextField(
                      label: 'Full Name',
                      controller: _fullNameController,
                      hintText: 'Full name',
                      prefixIcon: Icons.person_outline_rounded,
                      textInputAction: TextInputAction.next,
                    ),

                    const SizedBox(height: 14),

                    // ── Field 2: Email Address ───────────────────────────────
                    AuthTextField(
                      label: 'Email Address',
                      controller: _emailController,
                      hintText: 'Email',
                      prefixIcon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      errorText: _errorMessage,
                    ),

                    const SizedBox(height: 14),

                    // ── Field 3: Phone Number ────────────────────────────────
                    AuthTextField(
                      label: 'Phone Number',
                      controller: _phoneController,
                      hintText: 'Phone number',
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                    ),

                    const SizedBox(height: 14),

                    // ── Field 4: Create Password + Strength ──────────────────
                    AuthTextField(
                      label: 'Create Password',
                      labelTrailing: PasswordStrengthIndicator(
                        strength: _passwordStrength,
                      ),
                      controller: _passwordController,
                      hintText: 'Password (min. 8 characters)',
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _handleRegister(),
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

                    const SizedBox(height: 22),

                    // ── Solid Orange CTA Button ──────────────────────────────
                    AuthPrimaryButton(
                      label: 'Register Rider Profile',
                      isLoading: _isLoading,
                      onTap: _handleRegister,
                    ),

                    const SizedBox(height: 14),

                    // ── Terms of Service & Privacy Policy ────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text.rich(
                        TextSpan(
                          text: 'By signing up, you agree to CAMP ',
                          style: GoogleFonts.manrope(
                            color: AuthColors.textMuted,
                            fontSize: 11,
                            height: 1.45,
                          ),
                          children: const [
                            TextSpan(
                              text: 'Terms of Service',
                              style: TextStyle(
                                color: AuthColors.textLabel,
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(text: ' & '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(
                                color: AuthColors.textLabel,
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(text: '.'),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
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

  /// Bottom Footer: "Already have an account? Sign In"
  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Already have an account? ',
            style: GoogleFonts.manrope(
              color: AuthColors.textFooter,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          GestureDetector(
            onTap: () =>
                Navigator.of(context).pushReplacementNamed(CampRoutes.signIn),
            child: Text(
              'Sign In',
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
