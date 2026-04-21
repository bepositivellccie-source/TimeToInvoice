import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/session.dart';
import 'supabase_provider.dart';

/// Sessions pour un projet donné — lecture seule (le Timer gère l'écriture).
final sessionsByProjectProvider =
    FutureProvider.family<List<WorkSession>, String>((ref, projectId) async {
  final supabase = ref.watch(supabaseClientProvider);
  try {
    final data = await supabase
        .from('sessions')
        .select()
        .eq('project_id', projectId)
        .not('ended_at', 'is', null) // sessions terminées uniquement
        .order('started_at', ascending: false);
    return (data as List).map((e) => WorkSession.fromJson(e)).toList();
  } on PostgrestException catch (e) {
    // PGRST116 = row not found (session supprimée entre deux requêtes) — retour liste vide
    if (e.code == 'PGRST116') return [];
    rethrow;
  }
});

/// Sessions NON facturées pour un projet — exclut celles déjà liées via invoice_sessions.
/// Utilisé par InvoiceScreen pour éviter la double facturation.
final unbilledSessionsByProjectProvider =
    FutureProvider.family<List<WorkSession>, String>((ref, projectId) async {
  final supabase = ref.watch(supabaseClientProvider);
  try {
    // 1) Toutes les sessions terminées du projet
    final sessionsData = await supabase
        .from('sessions')
        .select()
        .eq('project_id', projectId)
        .not('ended_at', 'is', null)
        .order('started_at', ascending: false);
    final sessions =
        (sessionsData as List).map((e) => WorkSession.fromJson(e)).toList();

    if (sessions.isEmpty) return sessions;

    // 2) IDs des sessions déjà facturées (via table de liaison)
    final billedData = await supabase
        .from('invoice_sessions')
        .select('session_id')
        .inFilter('session_id', sessions.map((s) => s.id).toList());
    final billedIds = <String>{
      for (final row in (billedData as List)) row['session_id'] as String,
    };

    // 3) Filtrage
    return sessions.where((s) => !billedIds.contains(s.id)).toList();
  } on PostgrestException catch (e) {
    if (e.code == 'PGRST116') return [];
    rethrow;
  }
});

/// Temps total travaillé par projet — une seule requête pour tous les projets.
/// Retourne Map(projectId → totalSeconds) ; absent = 0 s.
final projectsTotalSecondsProvider =
    FutureProvider<Map<String, int>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final data = await supabase
      .from('sessions')
      .select('project_id, duration_seconds')
      .not('ended_at', 'is', null);
  final result = <String, int>{};
  for (final row in (data as List)) {
    final id = row['project_id'] as String;
    final secs = (row['duration_seconds'] as int?) ?? 0;
    result[id] = (result[id] ?? 0) + secs;
  }
  return result;
});
