import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project.dart';
import 'supabase_provider.dart';

final projectsProvider = FutureProvider<List<Project>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final data = await supabase
      .from('projects')
      .select()
      .order('created_at', ascending: false);
  return (data as List).map((e) => Project.fromJson(e)).toList();
});
