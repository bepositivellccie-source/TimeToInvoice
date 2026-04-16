import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/clients_provider.dart';
import '../../core/providers/onboarding_provider.dart';
import '../clients/clients_screen.dart';
import '../clients/client_detail_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;

  Future<void> _skip() async {
    await ref.read(onboardingProvider.notifier).markDone();
    if (mounted) context.go('/timer');
  }

  Future<void> _finish() async {
    await ref.read(onboardingProvider.notifier).markDone();
    if (mounted) context.go('/timer');
  }

  void _next() => setState(() => _step++);

  Future<void> _createClient() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ClientFormSheet(existing: null),
    );
    // Avance si un client vient d'être créé
    final clients = ref.read(clientsProvider).valueOrNull ?? [];
    if (clients.isNotEmpty && mounted) _next();
  }

  Future<void> _createProject() async {
    final clients = ref.read(clientsProvider).valueOrNull ?? [];
    final clientId = clients.isNotEmpty ? clients.first.id : null;
    if (clientId == null) { _next(); return; }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProjectFormSheet(clientId: clientId, existing: null),
    );
    if (mounted) _next();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: switch (_step) {
            0 => _StepView(
                key: const ValueKey(0),
                stepIndex: 0,
                totalSteps: 4,
                icon: Icons.people_outline,
                title: 'Crée ton premier client',
                subtitle:
                    'Chaque facture est liée à un client.\nCommence par en créer un.',
                ctaLabel: 'Créer mon client',
                onCta: _createClient,
                onSkip: _skip,
              ),
            1 => _StepView(
                key: const ValueKey(1),
                stepIndex: 1,
                totalSteps: 4,
                icon: Icons.folder_outlined,
                title: 'Crée ton premier projet',
                subtitle:
                    'Un projet regroupe tes sessions de travail.\nDéfinis son taux horaire.',
                ctaLabel: 'Créer mon projet',
                onCta: _createProject,
                onSkip: _skip,
              ),
            2 => _StepView(
                key: const ValueKey(2),
                stepIndex: 2,
                totalSteps: 4,
                icon: Icons.verified_outlined,
                title: 'E-facturation obligatoire',
                subtitle:
                    'Dès septembre 2026, la facturation électronique '
                    'devient obligatoire en France.\n\n'
                    'ChronoFacture génère des factures au format '
                    'Factur-X (EN 16931), le standard européen.\n\n'
                    'Vous êtes déjà conforme.',
                ctaLabel: 'Compris',
                onCta: _next,
                onSkip: _skip,
              ),
            _ => _StepView(
                key: const ValueKey(3),
                stepIndex: 3,
                totalSteps: 4,
                icon: Icons.timer_outlined,
                title: 'Lance le timer',
                subtitle:
                    'Sélectionne ton projet et démarre.\nUne facture en 1 tap à l\'arrêt.',
                ctaLabel: "C'est parti !",
                onCta: _finish,
                onSkip: null,
              ),
          },
        ),
      ),
    );
  }
}

// ─── Étape générique ──────────────────────────────────────────────────────────

class _StepView extends StatelessWidget {
  final int stepIndex;
  final int totalSteps;
  final IconData icon;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback onCta;
  final VoidCallback? onSkip;

  const _StepView({
    super.key,
    required this.stepIndex,
    this.totalSteps = 4,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.onCta,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bouton "Passer"
          Align(
            alignment: Alignment.topRight,
            child: onSkip != null
                ? TextButton(
                    onPressed: onSkip,
                    child: const Text('Passer',
                        style: TextStyle(color: Color(0xFF9CA3AF))),
                  )
                : const SizedBox(height: 40),
          ),
          const Spacer(flex: 2),

          // Icône
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, size: 44, color: primary),
          ),
          const SizedBox(height: 28),

          // Indicateurs d'étapes (pills)
          Row(
            children: List.generate(totalSteps, (i) {
              final active = i == stepIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: active ? 24 : 8,
                height: 8,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: active ? primary : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),

          // Titre
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),

          // Sous-titre
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF6B7280),
              height: 1.6,
            ),
          ),

          const Spacer(flex: 3),

          // CTA principal
          FilledButton(
            onPressed: onCta,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              textStyle: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700),
            ),
            child: Text(ctaLabel),
          ),
        ],
      ),
    );
  }
}
