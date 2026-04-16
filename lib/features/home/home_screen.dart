import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/project.dart';
import '../../core/providers/invoices_provider.dart';
import '../../core/providers/projects_provider.dart';
import '../../core/providers/sessions_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../timer/timer_notifier.dart';

// ─── Screen ──────────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;
    final userName = user?.userMetadata?['full_name'] as String? ??
        user?.email?.split('@').first ??
        '';
    final firstName = userName.split(' ').first;

    final entriesAsync = ref.watch(timerProjectsProvider);
    final totalsAsync = ref.watch(projectsTotalSecondsProvider);

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header avec avatar, greeting, capsules stats ───
            _HomeHeader(firstName: firstName),

            // ── Dashboard KPI ──────────────────────────────────
            const _DashboardKpi(),

            // ── Carrousel projets en cours ──────────────────────
            _ProjectCarousel(entriesAsync: entriesAsync),

            // ── Activité récente ────────────────────────────────
            _RecentActivity(totalsAsync: totalsAsync),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

// ─── Header card avec forme asymétrique (style screenshot) ─────────────────

class _HomeHeader extends ConsumerWidget {
  final String firstName;

  const _HomeHeader({required this.firstName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;
    final screenWidth = MediaQuery.of(context).size.width;

    final entriesAsync = ref.watch(timerProjectsProvider);
    final totalsAsync = ref.watch(projectsTotalSecondsProvider);

    final entries = entriesAsync.valueOrNull ?? [];
    final totals = totalsAsync.valueOrNull ?? {};

    final totalProjects = entries.length;
    final activeProjects =
        entries.where((e) => e.project.status == 'en_cours').length;
    int totalSeconds = 0;
    for (final t in totals.values) {
      totalSeconds += t;
    }
    final totalHours = (totalSeconds / 3600).round();

    // Couleur vert foncé pour le texte des capsules
    const capsuleTextColor = Color(0xFF035E4E);

    return ClipPath(
      clipper: _HeaderClipper(),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(24, topPadding + 16, 24, 0),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF14E8C3),
              Color(0xFF0DCFB0),
              Color(0xFF05B89C),
              Color(0xFF049A83),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Top bar : grille points + cloche ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Logo ChronoFacture
                Image.asset(
                  'assets/ChronoFacture.png',
                  width: 32,
                  height: 32,
                ),
                // Cloche notification
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(35),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Greeting text centré ──
            Text(
              'Bonjour $firstName',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Ton activité ce mois-ci',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Colors.white.withAlpha(190),
              ),
            ),

            const SizedBox(height: 16),

            // ── Zone avatar + capsules ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar / illustration placeholder
                Container(
                  width: screenWidth * 0.33,
                  height: screenWidth * 0.33,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(22),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Center(
                    child: Text(
                      firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withAlpha(100),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // ── Capsules stats ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StatCapsule(
                        svgAsset: 'assets/projet.svg',
                        label: '$totalProjects projets',
                        textColor: capsuleTextColor,
                      ),
                      const SizedBox(height: 7),
                      _StatCapsule(
                        svgAsset: 'assets/client.svg',
                        label: '$activeProjects en cours',
                        textColor: capsuleTextColor,
                      ),
                      const SizedBox(height: 7),
                      _StatCapsule(
                        svgAsset: 'assets/clock.svg',
                        label: '${totalHours}h ce mois',
                        textColor: capsuleTextColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Espace pour la forme découpée
            const SizedBox(height: 44),
          ],
        ),
      ),
    );
  }

}

// ─── Capsule stat (pill blanc/frost, texte vert foncé, fine) ────────────────

class _StatCapsule extends StatelessWidget {
  final String svgAsset;
  final String label;
  final Color textColor;

  const _StatCapsule({
    required this.svgAsset,
    required this.label,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(140),
        borderRadius: BorderRadius.circular(FigmaRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            svgAsset,
            width: 14,
            height: 14,
            colorFilter: ColorFilter.mode(
              textColor,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Clipper vague asymétrique ──────────────────────────────────────────────
// Bas-gauche : convexe (bosse qui remonte vers le centre)
// Bas-droite : concave (creux qui descend)
// → forme une vague S harmonieuse

class _HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;

    // Haut plat + bord droit
    path.moveTo(0, 0);
    path.lineTo(w, 0);

    // Bord droit descend jusqu'au point de départ de la vague
    // Le côté droit descend plus bas (concave = creux)
    path.lineTo(w, h - 10);

    // ── Vague S de droite à gauche ──
    // Moitié droite : concave (creux vers le bas)
    path.quadraticBezierTo(
      w * 0.75, h + 8,   // contrôle : pousse vers le bas (creux)
      w * 0.5, h - 14,    // milieu : point d'inflexion
    );

    // Moitié gauche : convexe (bosse vers le haut)
    path.quadraticBezierTo(
      w * 0.25, h - 36,  // contrôle : pousse vers le haut (bosse)
      0, h - 28,          // fin : bord gauche, remonté
    );

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ─── Carrousel de projets en cours ──────────────────────────────────────────

class _ProjectCarousel extends ConsumerStatefulWidget {
  final AsyncValue<List<TimerEntry>> entriesAsync;

  const _ProjectCarousel({required this.entriesAsync});

  @override
  ConsumerState<_ProjectCarousel> createState() => _ProjectCarouselState();
}

class _ProjectCarouselState extends ConsumerState<_ProjectCarousel> {
  late final PageController _pageCtrl;
  double _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: 0.82);
    _pageCtrl.addListener(() {
      setState(() => _currentPage = _pageCtrl.page ?? 0);
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  // Couleur par statut
  static Color _cardColor(Project project, String? activeTimerProjectId) {
    // Timer actif sur CE projet → vert
    if (activeTimerProjectId == project.id) {
      return const Color(0xFF00C896);
    }
    // Projet terminé → orange
    if (project.status == 'termine') {
      return const Color(0xFFF5A623);
    }
    // En cours (pas de timer actif) → rouge bordeaux
    return const Color(0xFF8B1A1A);
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.entriesAsync.valueOrNull ?? [];
    if (entries.isEmpty) return const SizedBox.shrink();

    final totals = ref.watch(projectsTotalSecondsProvider).valueOrNull ?? {};
    final timerState = ref.watch(timerProvider);
    final activeTimerProjectId =
        timerState.isActive ? timerState.selectedProjectId : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Text(
            'Projets en cours',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: -0.3,
            ),
          ),
        ),
        SizedBox(
          height: 175,
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final entry = entries[i];
              final project = entry.project;
              final clientName = entry.clientName;
              final totalSecs = totals[project.id] ?? 0;
              final hh = totalSecs ~/ 3600;
              final mm = (totalSecs % 3600) ~/ 60;
              final ss = totalSecs % 60;
              final timeStr = '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
              final cardColor = _cardColor(project, activeTimerProjectId);

              // Scale : 1.0 pour la page centrale, 0.88 pour les latérales
              final diff = (i - _currentPage).abs().clamp(0.0, 1.0);
              final scale = 1.0 - (diff * 0.12); // 1.0 → 0.88

              return Transform.scale(
                scale: scale,
                child: GestureDetector(
                  onTap: () => context.push(
                      '/clients/${project.clientId}/projects/${project.id}/sessions'),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          cardColor,
                          cardColor.withAlpha(200),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: cardColor.withAlpha(60),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // ── Nom projet + client ──
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project.name,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              clientName,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withAlpha(180),
                              ),
                            ),
                          ],
                        ),
                        // ── Stats en bas ──
                        Row(
                          children: [
                            // Heures
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(40),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SvgPicture.asset(
                                    'assets/clock.svg',
                                    width: 13,
                                    height: 13,
                                    colorFilter: const ColorFilter.mode(
                                      Colors.white,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    timeStr,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Taux horaire
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(40),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${project.hourlyRate.toStringAsFixed(0)}€/h',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.arrow_forward_ios,
                                size: 14, color: Colors.white70),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Activité récente (calendrier simplifié) ────────────────────────────────

class _RecentActivity extends StatelessWidget {
  final AsyncValue<Map<String, int>> totalsAsync;

  const _RecentActivity({required this.totalsAsync});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekDays = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cette semaine',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          // ── Jours de la semaine ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(FigmaRadius.lg),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 30 : 8),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                // Calcul du jour (lundi = 0)
                final mondayOffset = now.weekday - 1;
                final day = now.subtract(Duration(days: mondayOffset - i));
                final isToday = day.day == now.day &&
                    day.month == now.month &&
                    day.year == now.year;
                final isPast = day.isBefore(now) && !isToday;

                return _DayCell(
                  label: weekDays[i],
                  date: '${day.day}',
                  isToday: isToday,
                  isPast: isPast,
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final String label;
  final String date;
  final bool isToday;
  final bool isPast;

  const _DayCell({
    required this.label,
    required this.date,
    required this.isToday,
    required this.isPast,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isToday ? FigmaPrimary.c500 : FigmaSecondary.c300,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isToday ? const Color(0xFF05B89C) : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              date,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                color: isToday
                    ? Colors.white
                    : isPast
                        ? FigmaSecondary.c400
                        : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Dashboard KPI (MRR, temps travaillé, factures en attente) ─────────────

class _DashboardKpi extends ConsumerWidget {
  const _DashboardKpi();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(invoicesProvider);
    final totalsAsync = ref.watch(projectsTotalSecondsProvider);
    final euroFmt = NumberFormat.currency(
        locale: 'fr_FR', symbol: '€', decimalDigits: 0);

    final invoices = invoicesAsync.valueOrNull ?? [];
    final totals = totalsAsync.valueOrNull ?? {};

    // MRR = factures payées ce mois
    final now = DateTime.now();
    final mrr = invoices
        .where((inv) =>
            inv.status == 'paid' &&
            inv.createdAt.toLocal().year == now.year &&
            inv.createdAt.toLocal().month == now.month)
        .fold(0.0, (sum, inv) => sum + inv.totalAmount);

    // Temps travaillé total (toutes sessions)
    int totalSecs = 0;
    for (final t in totals.values) {
      totalSecs += t;
    }
    final totalHours = (totalSecs / 3600).toStringAsFixed(1);

    // Factures en attente
    final pending =
        invoices.where((inv) => inv.isPending || inv.isOverdue).length;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        children: [
          _KpiCard(
            icon: Icons.trending_up,
            label: 'MRR',
            value: euroFmt.format(mrr),
            color: const Color(0xFF16A34A),
            isDark: isDark,
          ),
          const SizedBox(width: 10),
          _KpiCard(
            icon: Icons.schedule_outlined,
            label: 'Travaillé',
            value: '${totalHours}h',
            color: const Color(0xFF2563EB),
            isDark: isDark,
          ),
          const SizedBox(width: 10),
          _KpiCard(
            icon: LucideIcons.fileText,
            label: 'En attente',
            value: '$pending',
            color: pending > 0
                ? const Color(0xFFEA580C)
                : AppColors.textSecondary(context),
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 30 : 8),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textTertiary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
