import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session.dart';
import 'supabase_provider.dart';

/// Sessions pour un projet donné — lecture seule (le Timer gère l'écriture).
final sessionsByProjectProvider =
    FutureProvider.family<List<WorkSession>, String>((ref, projectId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final data = await supabase
      .from('sessions')
      .select()
      .eq('project_id', projectId)
      .not('ended_at', 'is', null) // sessions terminées uniquement
      .order('started_at', ascending: false);
  return (data as List).map((e) => WorkSession.fromJson(e)).toList();
});
