import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/auth_colors.dart';

/// "Quick Sign In" express tap button
class AuthExpressButton extends StatefulWidget {
  const AuthExpressButton({
    required this.onTap,
    super.key,
    this.label = 'Quick Sign In',
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  State<AuthExpressButton> createState() => _AuthExpressButtonState();
}

class _AuthExpressButtonState extends State<AuthExpressButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.isLoading ? null : widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 50,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AuthColors.expressButtonBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AuthColors.expressButtonBorder,
              width: 1.0,
            ),
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.bolt_rounded,
                        color: Color(0xFFD4CDC6),
                        size: 20,
                      ),
                      const SizedBox(width: 9),
                      Text(
                        widget.label,
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
