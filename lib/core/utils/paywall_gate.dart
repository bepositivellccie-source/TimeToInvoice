import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/subscription_provider.dart';
import '../../features/paywall/paywall_screen.dart';

/// Vérifie le quota freemium avant de générer une facture.
///
/// Modèle :
///   - Mois 1 après création du compte : illimité
///   - Mois 2+ : [kFreeInvoicesPerMonth] factures/mois gratuites
///   - Au-delà : paywall RevenueCat
///
/// Retourne `true` si l'utilisateur peut continuer, `false` sinon.
Future<bool> checkInvoiceQuota(BuildContext context, WidgetRef ref) async {
  final sub = ref.read(subscriptionProvider);

  // Pro → toujours OK
  if (sub.isPro) return true;

  // Récupérer la date de création du compte
  final accountCreatedAt =
      await ref.read(accountCreatedAtProvider.future);

  // Mois 1 (< 30 jours depuis création) → illimité
  final bool isFirstMonth = accountCreatedAt != null &&
      DateTime.now().difference(accountCreatedAt).inDays < 30;

  if (isFirstMonth) return true;

  // Mois 2+ → vérifier le quota mensuel
  final invoicesThisMonth =
      await ref.read(monthlyInvoiceCountProvider.future);

  if (invoicesThisMonth < kFreeInvoicesPerMonth) return true;

  // Quota dépassé → afficher la paywall
  if (!context.mounted) return false;

  final result = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const PaywallScreen(
        message:
            'Vous avez utilisé vos $kFreeInvoicesPerMonth factures '
            'gratuites ce mois-ci.\n'
            'Passez à Pro pour des factures illimitées.',
      ),
    ),
  );

  return result == true;
}
