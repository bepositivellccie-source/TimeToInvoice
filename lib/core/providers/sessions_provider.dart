import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/session.dart';
import 'projects_provider.dart';
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

/// IDs des sessions déjà liées à une facture pour ce projet.
/// Utilisé par le wizard pour afficher un badge "Déjà facturée".
final billedSessionIdsByProjectProvider =
    FutureProvider.family<Set<String>, String>((ref, projectId) async {
  final supabase = ref.watch(supabaseClientProvider);
  try {
    // 1) Toutes les sessions terminées du projet (pour limiter la jointure)
    final sessionsData = await supabase
        .from('sessions')
        .select('id')
        .eq('project_id', projectId)
        .not('ended_at', 'is', null);
    final ids = (sessionsData as List)
        .map((e) => e['id'] as String)
        .toList();
    if (ids.isEmpty) return <String>{};

    // 2) IDs des sessions déjà facturées (via table de liaison)
    final billedData = await supabase
        .from('invoice_sessions')
        .select('session_id')
        .inFilter('session_id', ids);
    return <String>{
      for (final row in (billedData as List)) row['session_id'] as String,
    };
  } on PostgrestException catch (e) {
    if (e.code == 'PGRST116') return <String>{};
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

/// N dernières sessions terminées (toutes projets confondus) pour l'Accueil.
final recentSessionsProvider =
    FutureProvider<List<WorkSession>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final data = await supabase
      .from('sessions')
      .select()
      .not('ended_at', 'is', null)
      .order('started_at', ascending: false)
      .limit(5);
  return (data as List).map((e) => WorkSession.fromJson(e)).toList();
});

/// KPI "cette semaine" : temps total + montant facturable + numéro ISO de la semaine.
typedef WeeklyStats = ({Duration worked, double billable, int weekNumber});

final weeklyStatsProvider = FutureProvider<WeeklyStats>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final projects = await ref.watch(projectsProvider.future);
  final rateById = {for (final p in projects) p.id: p.hourlyRate};

  final now = DateTime.now();
  final mondayOffset = now.weekday - 1; // weekday: 1 = lundi
  final monday = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: mondayOffset));
  final mondayUtc = monday.toUtc();

  final data = await supabase
      .from('sessions')
      .select('project_id, duration_seconds, started_at')
      .not('ended_at', 'is', null)
      .gte('started_at', mondayUtc.toIso8601String());

  int totalSecs = 0;
  double billable = 0;
  for (final row in (data as List)) {
    final secs = (row['duration_seconds'] as int?) ?? 0;
    totalSecs += secs;
    final pid = row['project_id'] as String?;
    final rate = rateById[pid] ?? 0.0;
    billable += (secs / 3600.0) * rate;
  }

  return (
    worked: Duration(seconds: totalSecs),
    billable: billable,
    weekNumber: _isoWeekNumber(now),
  );
});

int _isoWeekNumber(DateTime date) {
  final thursday =
      date.add(Duration(days: 4 - (date.weekday == 7 ? 7 : date.weekday)));
  final firstThursday = DateTime(thursday.year, 1, 4);
  final firstThursdayWeekday =
      firstThursday.weekday == 7 ? 7 : firstThursday.weekday;
  final firstWeekStart =
      firstThursday.subtract(Duration(days: firstThursdayWeekday - 1));
  final diff = thursday.difference(firstWeekStart).inDays;
  return (diff / 7).floor() + 1;
}
