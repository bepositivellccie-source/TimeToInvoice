import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/project_billing_status.dart';
import 'supabase_provider.dart';

/// Statut de facturation pour tous les projets — lit la vue Postgres
/// `project_billing_status` (source de vérité côté serveur).
final projectBillingStatusProvider =
    FutureProvider<List<ProjectBillingStatus>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final data = await supabase.from('project_billing_status').select();
  return (data as List)
      .map((e) => ProjectBillingStatus.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Statut de facturation indexé par projectId — dérivé du provider global.
final projectBillingStatusByIdProvider =
    Provider.family<AsyncValue<ProjectBillingStatus?>, String>((ref, projectId) {
  return ref.watch(projectBillingStatusProvider).whenData(
        (list) => list
            .where((s) => s.projectId == projectId)
            .cast<ProjectBillingStatus?>()
            .firstOrNull,
      );
});
