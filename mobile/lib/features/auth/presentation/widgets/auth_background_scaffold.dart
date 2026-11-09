import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Full-screen dusk mountain highway background with gradient vignette
class AuthBackgroundScaffold extends StatelessWidget {
  const AuthBackgroundScaffold({
    required this.child,
    super.key,
    this.topBar,
    this.bottomBar,
  });

  final Widget child;
  final Widget? topBar;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF141210),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF181513),
        resizeToAvoidBottomInset: true,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── Layer 1: Background Image ────────────────────────────────────
            Image.asset(
              'assets/images/auth_bg.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                // Fallback rich moody twilight gradient if image fails to load
                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF161B22),
                        Color(0xFF2E2218),
                        Color(0xFF452B19),
                        Color(0xFF1F1612),
                        Color(0xFF0F0C0A),
                      ],
                      stops: [0.0, 0.35, 0.6, 0.85, 1.0],
                    ),
                  ),
                );
              },
            ),

            // ── Layer 2: Atmospheric Dark Vignette & Gradient Overlays ───────
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.25),
                    Colors.black.withValues(alpha: 0.45),
                    Colors.black.withValues(alpha: 0.85),
                  ],
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),

            // ── Layer 3: Content ─────────────────────────────────────────────
            SafeArea(
              child: Column(
                children: [
                  ?topBar,
                  Expanded(
                    child: child,
                  ),
                  ?bottomBar,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
