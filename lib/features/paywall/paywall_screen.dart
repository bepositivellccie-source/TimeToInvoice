import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../core/providers/subscription_provider.dart';
import '../../core/theme/app_colors.dart';

/// Paywall modale — déclenchée à la 4ème facture du mois (freemium).
/// Deux options : mensuel 6,99 €/mois ou annuel 49,99 €/an (-40 %).
class PaywallScreen extends ConsumerStatefulWidget {
  final String? message;

  const PaywallScreen({super.key, this.message});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _purchasing = false;
  bool _annual = true; // Pré-sélectionné annuel

  @override
  Widget build(BuildContext context) {
    final sub = ref.watch(subscriptionProvider);
    final primary = Theme.of(context).colorScheme.primary;

    final offering = sub.offerings?.current;
    final monthly = offering?.monthly;
    final annual = offering?.annual;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            children: [
              // ── Close button ──
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(height: 8),

              // ── Badge Pro ──
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'PRO',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: primary,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Title ──
              const Text(
                'Passez à ChronoFacture Pro',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.message ??
                    'Factures illimitées, Factur-X conforme,\net toutes les fonctionnalités Pro.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary(context)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // ── Features list ──
              ..._features.map((f) => _FeatureRow(
                    icon: f.$1,
                    text: f.$2,
                  )),

              const SizedBox(height: 32),

              // ── Plan selection ──
              if (annual != null)
                _PlanCard(
                  label: 'Annuel',
                  price: annual.storeProduct.priceString,
                  subtitle: 'soit ~4,17 €/mois — économisez 40 %',
                  isSelected: _annual,
                  isBest: true,
                  onTap: () => setState(() => _annual = true),
                ),
              const SizedBox(height: 12),
              if (monthly != null)
                _PlanCard(
                  label: 'Mensuel',
                  price: monthly.storeProduct.priceString,
                  subtitle: 'Sans engagement',
                  isSelected: !_annual,
                  isBest: false,
                  onTap: () => setState(() => _annual = false),
                ),

              const SizedBox(height: 28),

              // ── CTA ──
              FilledButton(
                onPressed: _purchasing
                    ? null
                    : () => _purchase(_annual ? annual : monthly),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700),
                ),
                child: _purchasing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Débloquer Pro'),
              ),
              const SizedBox(height: 12),

              // ── Restore ──
              TextButton(
                onPressed: _purchasing ? null : _restore,
                child: Text(
                  'Restaurer mes achats',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary(context)),
                ),
              ),

              const SizedBox(height: 8),
              Text(
                'Abonnement renouvelable automatiquement.\n'
                'Annulable à tout moment depuis les paramètres du store.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary(context),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _purchase(Package? package) async {
    if (package == null) return;
    setState(() => _purchasing = true);
    final success =
        await ref.read(subscriptionProvider.notifier).purchase(package);
    if (mounted) {
      setState(() => _purchasing = false);
      if (success) Navigator.pop(context, true);
    }
  }

  Future<void> _restore() async {
    setState(() => _purchasing = true);
    await ref.read(subscriptionProvider.notifier).restore();
    if (mounted) {
      setState(() => _purchasing = false);
      if (ref.read(subscriptionProvider).isPro) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucun abonnement trouvé'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// ─── Features ──────────────────────────────────────────────────────────────

const _features = [
  (Icons.all_inclusive, 'Factures illimitées'),
  (Icons.verified_outlined, 'Format Factur-X conforme'),
  (Icons.email_outlined, 'Envoi & relances email'),
  (Icons.bar_chart_outlined, 'Dashboard avancé'),
  (Icons.support_agent_outlined, 'Support prioritaire'),
];

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: primary),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

// ─── Plan card ─────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final String label;
  final String price;
  final String subtitle;
  final bool isSelected;
  final bool isBest;
  final VoidCallback onTap;

  const _PlanCard({
    required this.label,
    required this.price,
    required this.subtitle,
    required this.isSelected,
    required this.isBest,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final borderColor = isSelected ? primary : AppColors.border(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
          color: isSelected ? primary.withAlpha(10) : Colors.transparent,
        ),
        child: Row(
          children: [
            // Radio indicator
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? primary : AppColors.borderStrong(context),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      if (isBest) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'MEILLEURE OFFRE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style:
                        TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
                  ),
                ],
              ),
            ),
            // Price
            Text(
              price,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isSelected ? primary : AppColors.textBody(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
