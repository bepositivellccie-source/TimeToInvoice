import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/client.dart';
import '../../core/providers/clients_provider.dart';
import '../../core/theme/cf_palette.dart';
import 'clients_screen.dart' show NewClientFormScreen;

/// Vérifie qu'au moins un client existe.
///
/// Si la liste est vide, ouvre un dialogue avec un CTA "Créer un client"
/// qui pousse directement l'écran de création. Renvoie `true` si le caller
/// peut poursuivre (un client existe après l'interaction), `false` si
/// l'utilisateur a annulé ou n'a pas fini la création.
///
/// Remplace l'ancienne SnackBar non actionnable.
Future<bool> ensureClientExists(
  BuildContext context,
  WidgetRef ref,
) async {
  final initial =
      ref.read(clientsProvider).valueOrNull ?? const <Client>[];
  if (initial.isNotEmpty) return true;

  final shouldCreate = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: CF.surface(ctx),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CFRadius.lg),
      ),
      title: Text(
        'Aucun client',
        style: GoogleFonts.inter(
          fontSize: CFType.title,
          fontWeight: FontWeight.w700,
          color: CF.text(ctx),
        ),
      ),
      content: Text(
        'Vous devez d\'abord créer un client pour ajouter un projet.',
        style: GoogleFonts.inter(
          fontSize: 14,
          color: CF.muted(ctx),
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(
            'Annuler',
            style: GoogleFonts.inter(color: CF.muted(ctx)),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: CF.primary),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Créer un client'),
        ),
      ],
    ),
  );

  if (shouldCreate != true || !context.mounted) return false;

  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const NewClientFormScreen()),
  );

  if (!context.mounted) return false;
  final fresh = await ref.read(clientsProvider.future);
  return fresh.isNotEmpty;
}
