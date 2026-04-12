import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project.dart';
import 'client_display_mode_provider.dart';
import 'supabase_provider.dart';
import 'clients_provider.dart';

// ─── Notifier (CRUD) ──────────────────────────────────────────────────────────

class ProjectsNotifier extends AsyncNotifier<List<Project>> {
  Future<List<Project>> _fetch() async {
    final supabase = ref.read(supabaseClientProvider);
    final data = await supabase
        .from('projects')
        .select()
        .order('name');
    return (data as List).map((e) => Project.fromJson(e)).toList();
  }

  @override
  Future<List<Project>> build() => _fetch();

  Future<void> create({
    required String clientId,
    required String name,
    required double hourlyRate,
    String currency = 'EUR',
  }) async {
    state = const AsyncLoading();
    final supabase = ref.read(supabaseClientProvider);
    final userId = supabase.auth.currentUser!.id;
    state = await AsyncValue.guard(() async {
      await supabase.from('projects').insert({
        'user_id': userId,
        'client_id': clientId,
        'name': name,
        'hourly_rate': hourlyRate,
        'currency': currency,
      });
      // Invalide aussi la vue filtrée par client
      ref.invalidate(projectsByClientProvider(clientId));
      return _fetch();
    });
  }

  Future<void> edit({
    required String id,
    required String clientId,
    required String name,
    required double hourlyRate,
    String currency = 'EUR',
  }) async {
    state = const AsyncLoading();
    final supabase = ref.read(supabaseClientProvider);
    state = await AsyncValue.guard(() async {
      await supabase.from('projects').update({
        'name': name,
        'hourly_rate': hourlyRate,
        'currency': currency,
      }).eq('id', id);
      ref.invalidate(projectsByClientProvider(clientId));
      return _fetch();
    });
  }

  Future<void> delete({required String id, required String clientId}) async {
    state = const AsyncLoading();
    final supabase = ref.read(supabaseClientProvider);
    state = await AsyncValue.guard(() async {
      await supabase.from('projects').delete().eq('id', id);
      ref.invalidate(projectsByClientProvider(clientId));
      return _fetch();
    });
  }
}

/// Tous les projets de l'utilisateur (utilisé par le Timer).
final projectsProvider =
    AsyncNotifierProvider<ProjectsNotifier, List<Project>>(ProjectsNotifier.new);

// ─── Family — projets d'un client ────────────────────────────────────────────

final projectsByClientProvider =
    FutureProvider.family<List<Project>, String>((ref, clientId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final data = await supabase
      .from('projects')
      .select()
      .eq('client_id', clientId)
      .order('name');
  return (data as List).map((e) => Project.fromJson(e)).toList();
});

// ─── Combiné Timer : projet + nom du client ───────────────────────────────────

typedef TimerEntry = ({Project project, String clientName});

final timerProjectsProvider = FutureProvider<List<TimerEntry>>((ref) async {
  final projects = await ref.watch(projectsProvider.future);
  final clients = await ref.watch(clientsProvider.future);
  final mode = ref.watch(clientDisplayModeProvider);
  final clientMap = {for (final c in clients) c.id: c.labelWith(mode)};
  return projects
      .map((p) => (project: p, clientName: clientMap[p.clientId] ?? '—'))
      .toList();
});
