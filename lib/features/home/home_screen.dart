import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/models/invoice.dart';
import '../../core/models/project_billing_status.dart';
import '../../core/models/session.dart';
import '../../core/providers/invoices_provider.dart';
import '../../core/providers/project_billing_status_provider.dart';
import '../../core/providers/projects_provider.dart';
import '../../core/providers/sessions_provider.dart';
import '../../core/theme/cf_palette.dart';

/// Accueil ChronoFacture v2 — minimaliste, centré sur l'action.
///
/// Sections :
///   1. Greeting (date + Bonjour {prénom})
///   2. KPI semaine — gradient vert, mega-timer + montant facturable
///   3. À faire — relances (overdue) + à facturer (unbilled sessions)
///   4. Récent — 3 dernières sessions terminées
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;
    final fullName = user?.userMetadata?['full_name'] as String? ??
        user?.email?.split('@').first ??
        '';
    final firstName = fullName.split(' ').first;

    return Scaffold(
      backgroundColor: CF.bg(context),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(weeklyStatsProvider);
            ref.invalidate(recentSessionsProvider);
            ref.invalidate(invoicesProvider);
            ref.invalidate(projectBillingStatusProvider);
            await Future.wait([
              ref.read(weeklyStatsProvider.future),
              ref.read(recentSessionsProvider.future),
              ref.read(invoicesProvider.future),
              ref.read(projectBillingStatusProvider.future),
            ]);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 28),
            children: [
              _Greeting(firstName: firstName),
              const SizedBox(height: 16),
              const _WeeklyKpiCard(),
              const SizedBox(height: 22),
              const _ToDoSection(),
              const SizedBox(height: 22),
              const _RecentSection(),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Greeting ────────────────────────────────────────────────────────────────

class _Greeting extends StatelessWidget {
  final String firstName;
  const _Greeting({required this.firstName});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final raw = DateFormat('EEEE d MMMM', 'fr_FR').format(now);
    final dateStr =
        raw.isEmpty ? raw : '${raw[0].toUpperCase()}${raw.substring(1)}';
    final salutation = firstName.isEmpty ? 'Bonjour' : 'Bonjour $firstName';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateStr,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: CF.muted(context),
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            salutation,
            style: GoogleFonts.inter(
              fontSize: CFType.h1,
              fontWeight: FontWeight.w700,
              color: CF.text(context),
              letterSpacing: -0.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── KPI semaine ────────────────────────────────────────────────────────────

class _WeeklyKpiCard extends ConsumerWidget {
  const _WeeklyKpiCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(weeklyStatsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [CF.accentA, CF.accentB],
          ),
          borderRadius: BorderRadius.circular(CFRadius.xxl),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -40,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
              child: statsAsync.when(
                loading: () => const SizedBox(
                  height: 130,
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
                error: (e, _) => SizedBox(
                  height: 130,
                  child: Center(
                    child: Text(
                      'Erreur stats',
                      style: GoogleFonts.inter(color: Colors.white),
                    ),
                  ),
                ),
                data: (stats) => _WeeklyContent(stats: stats),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyContent extends StatelessWidget {
  final WeeklyStats stats;
  const _WeeklyContent({required this.stats});

  @override
  Widget build(BuildContext context) {
    final h = stats.worked.inHours.toString().padLeft(2, '0');
    final m = (stats.worked.inMinutes % 60).toString().padLeft(2, '0');
    final s = (stats.worked.inSeconds % 60).toString().padLeft(2, '0');
    final amount = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: '€',
      decimalDigits: 2,
    ).format(stats.billable);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SEMAINE ${stats.weekNumber} · EN COURS',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 14),
        DefaultTextStyle.merge(
          style: GoogleFonts.inter(
            fontSize: 44,
            fontWeight: FontWeight.w300,
            color: Colors.white,
            height: 1,
            letterSpacing: 0,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(h),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  ':',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w200,
                  ),
                ),
              ),
              Text(m),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  ':',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w200,
                  ),
                ),
              ),
              Text(s),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'travaillés cette semaine',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.only(top: 14),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Facturable',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              Text(
                amount,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── À faire ────────────────────────────────────────────────────────────────

class _ToDoSection extends ConsumerWidget {
  const _ToDoSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(invoicesProvider);
    final billingAsync = ref.watch(projectBillingStatusProvider);

    final invoices = invoicesAsync.valueOrNull ?? const <Invoice>[];
    final billing = billingAsync.valueOrNull ?? const <ProjectBillingStatus>[];

    final overdues = invoices.where((i) => i.isOverdue).toList()
      ..sort((a, b) => (a.dueAt ?? a.createdAt)
          .compareTo(b.dueAt ?? b.createdAt));
    final billable = billing.where((b) => b.unbilledSeconds > 0).toList()
      ..sort((a, b) => b.unbilledSeconds.compareTo(a.unbilledSeconds));

    final items = <_ToDoData>[
      for (final inv in overdues.take(3)) _ToDoData.fromOverdue(inv),
      for (final s in billable.take(3)) _ToDoData.fromBillable(s),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'À faire',
                style: GoogleFonts.inter(
                  fontSize: CFType.body,
                  fontWeight: FontWeight.w600,
                  color: CF.text(context),
                  letterSpacing: -0.1,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: CF.surfaceAlt(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${items.length}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: CF.faint(context),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (items.isEmpty)
          const _EmptyToDo()
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _ToDoCard(data: items[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _EmptyToDo extends StatelessWidget {
  const _EmptyToDo();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: CF.surface(context),
          borderRadius: BorderRadius.circular(CFRadius.xl),
          border: Border.all(color: CF.border(context), width: 0.5),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.checkCircle2, size: 18, color: CF.accentB),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tout est à jour. Profite-en !',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: CF.muted(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToDoData {
  final _ToDoKind kind;
  final String title;
  final String subtitle;
  final String actionLabel;
  final String navTo;

  const _ToDoData({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.navTo,
  });

  factory _ToDoData.fromOverdue(Invoice inv) {
    final clientName = inv.clientName ?? 'client';
    final due = inv.dueAt ?? inv.createdAt;
    final days = DateTime.now().difference(due).inDays;
    final daysLabel = days <= 0
        ? 'échéance dépassée'
        : 'échéance dépassée de $days jours';
    return _ToDoData(
      kind: _ToDoKind.relance,
      title: 'Relancer $clientName',
      subtitle: '${inv.invoiceNumber} · $daysLabel',
      actionLabel: 'Relancer',
      navTo: '/invoices',
    );
  }

  factory _ToDoData.fromBillable(ProjectBillingStatus s) {
    final clientName = s.clientName ?? 'client';
    final h = s.unbilledSeconds ~/ 3600;
    final m = (s.unbilledSeconds % 3600) ~/ 60;
    final hStr = h.toString().padLeft(2, '0');
    final mStr = m.toString().padLeft(2, '0');
    final sessLabel = s.unbilledSessions == 1 ? 'session' : 'sessions';
    return _ToDoData(
      kind: _ToDoKind.facturer,
      title: 'Facturer $clientName',
      subtitle: '${s.unbilledSessions} $sessLabel · $hStr h $mStr min à facturer',
      actionLabel: 'Facturer',
      navTo: '/invoices/new/${s.projectId}',
    );
  }
}

enum _ToDoKind { relance, facturer }

class _ToDoCard extends StatelessWidget {
  final _ToDoData data;
  const _ToDoCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final accent =
        data.kind == _ToDoKind.relance ? CF.orange : CF.primary;
    final iconData = data.kind == _ToDoKind.relance
        ? LucideIcons.alertCircle
        : LucideIcons.hourglass;

    return Material(
      color: CF.surface(context),
      borderRadius: BorderRadius.circular(CFRadius.xl),
      child: InkWell(
        borderRadius: BorderRadius.circular(CFRadius.xl),
        onTap: () => context.push(data.navTo),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CFRadius.xl),
            border: Border.all(color: CF.border(context), width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(iconData, size: 20, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: CFType.subtitle,
                        fontWeight: FontWeight.w600,
                        color: CF.text(context),
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: CF.muted(context),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    data.actionLabel,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                  Icon(LucideIcons.chevronRight, size: 16, color: accent),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Récent ─────────────────────────────────────────────────────────────────

class _RecentSection extends ConsumerWidget {
  const _RecentSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(recentSessionsProvider);
    final entriesAsync = ref.watch(timerProjectsProvider);

    final sessions = sessionsAsync.valueOrNull ?? const <WorkSession>[];
    final entries = entriesAsync.valueOrNull ?? const [];
    final projectMap = {for (final e in entries) e.project.id: e};

    final shown = sessions.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
          child: Text(
            'Récent',
            style: GoogleFonts.inter(
              fontSize: CFType.body,
              fontWeight: FontWeight.w600,
              color: CF.text(context),
              letterSpacing: -0.1,
            ),
          ),
        ),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: CF.surface(context),
                borderRadius: BorderRadius.circular(CFRadius.xl),
                border: Border.all(color: CF.border(context), width: 0.5),
              ),
              child: Text(
                'Aucune session enregistrée pour le moment.',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: CF.muted(context),
                ),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: CF.surface(context),
                borderRadius: BorderRadius.circular(CFRadius.xl),
                border: Border.all(color: CF.border(context), width: 0.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (int i = 0; i < shown.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 0.5,
                        thickness: 0.5,
                        color: CF.border(context),
                      ),
                    _RecentRow(
                      session: shown[i],
                      projectName:
                          projectMap[shown[i].projectId]?.project.name ??
                              'Session',
                      clientName:
                          projectMap[shown[i].projectId]?.clientName ?? '',
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _RecentRow extends StatelessWidget {
  final WorkSession session;
  final String projectName;
  final String clientName;

  const _RecentRow({
    required this.session,
    required this.projectName,
    required this.clientName,
  });

  @override
  Widget build(BuildContext context) {
    final secs = session.workedSeconds;
    final h = (secs ~/ 3600).toString().padLeft(2, '0');
    final m = ((secs % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    final timeStr = '$h:$m:$s';
    final whenStr = _formatWhen(session.startedAt.toLocal());
    final label = clientName.isEmpty
        ? projectName
        : '$projectName — $clientName';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: CFType.body,
                    fontWeight: FontWeight.w500,
                    color: CF.text(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  whenStr,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: CF.faint(context),
                  ),
                ),
              ],
            ),
          ),
          Text(
            timeStr,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: CF.text(context),
              letterSpacing: 0.3,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatWhen(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(day).inDays;

    final hm = DateFormat('HH:mm').format(dt);
    if (diff == 0) return "aujourd'hui · $hm";
    if (diff == 1) return 'hier · $hm';
    if (diff < 7) {
      final raw = DateFormat('EEE', 'fr_FR').format(dt);
      final cap = raw.isEmpty ? raw : '${raw[0].toUpperCase()}${raw.substring(1)}';
      return '$cap · $hm';
    }
    return '${DateFormat('d MMM', 'fr_FR').format(dt)} · $hm';
  }
}
