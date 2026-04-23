import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../providers/test_mode_provider.dart';
import '../theme/cf_palette.dart';

/// Bandeau vert affiché en haut des écrans Chrono et Factures lorsque
/// le mode test est actif. Tap → ouvre le Menu pour le désactiver.
///
/// Renvoie un [SizedBox.shrink] si le mode est désactivé pour ne pas
/// peser dans le layout.
class TestModeBanner extends ConsumerWidget {
  const TestModeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTest = ref.watch(testModeProvider);
    if (!isTest) return const SizedBox.shrink();

    return Material(
      color: CF.testBg,
      child: InkWell(
        onTap: () => context.push('/menu'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              const Icon(LucideIcons.flaskConical, size: 16, color: CF.testFg),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Mode test actif — factures filigranées et hors quota',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: CF.testFg,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              const Icon(LucideIcons.chevronRight, size: 16, color: CF.testFg),
            ],
          ),
        ),
      ),
    );
  }
}
