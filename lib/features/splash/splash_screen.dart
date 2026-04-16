import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Splash screen affiché brièvement au lancement pendant
/// que GoRouter résout l'état auth + onboarding.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Logo ──
            Image.asset(
              'assets/ChronoFacture.png',
              width: 96,
              height: 96,
            ),
            const SizedBox(height: 20),
            // ── App name ──
            Text(
              'ChronoFacture',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'CHAQUE SECONDE COMPTE',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF6B7280),
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
