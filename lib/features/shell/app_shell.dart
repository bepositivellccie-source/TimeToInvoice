import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/providers/session_bar_provider.dart';
import '../../core/theme/cf_palette.dart';

/// Shell ChronoFacture v2 — 4 onglets : Accueil / Chrono / Factures / Menu.
///
/// Branches GoRouter (cf. [appRouterProvider]) :
///   0 = /home, 1 = /timer, 2 = /invoices, 3 = /menu.
class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionBar = ref.watch(sessionBarProvider);
    final currentIdx = navigationShell.currentIndex;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: CF.bg(context),
      body: Column(
        children: [
          Expanded(child: navigationShell),
          if (sessionBar != null)
            _SessionBar(
              data: sessionBar,
              onDismiss: () =>
                  ref.read(sessionBarProvider.notifier).state = null,
              onTap: () {
                ref.read(sessionBarProvider.notifier).state = null;
                final d = sessionBar;
                if (d.clientId != null && d.projectId != null) {
                  context.push(
                    '/clients/${d.clientId}/projects/${d.projectId}/sessions',
                    extra: d.sessionId,
                  );
                }
              },
            ),
        ],
      ),

      // ── Bottom navbar : 4 onglets ──────────────────────────────
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? CF.d1 : CF.white,
          border: Border(
            top: BorderSide(color: CF.border(context), width: 0.5),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: LucideIcons.home,
                  selectedIcon: Icons.home,
                  label: 'Accueil',
                  isSelected: currentIdx == 0,
                  onTap: () => navigationShell.goBranch(0,
                      initialLocation: currentIdx == 0),
                ),
                _NavItem(
                  icon: LucideIcons.timer,
                  selectedIcon: Icons.timer,
                  label: 'Chrono',
                  isSelected: currentIdx == 1,
                  onTap: () => navigationShell.goBranch(1,
                      initialLocation: currentIdx == 1),
                ),
                _NavItem(
                  icon: LucideIcons.fileText,
                  selectedIcon: Icons.description,
                  label: 'Factures',
                  isSelected: currentIdx == 2,
                  onTap: () => navigationShell.goBranch(2,
                      initialLocation: currentIdx == 2),
                ),
                _NavItem(
                  icon: LucideIcons.menu,
                  label: 'Menu',
                  isSelected: currentIdx == 3,
                  onTap: () => navigationShell.goBranch(3,
                      initialLocation: currentIdx == 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Nav item ───────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? CF.primary : CF.faint(context);
    final displayIcon =
        isSelected && selectedIcon != null ? selectedIcon! : icon;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(displayIcon, size: 24, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: color,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Session bar (mini-player persistant) ──────────────────────────────────

class _SessionBar extends StatefulWidget {
  final SessionBarData data;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const _SessionBar({
    required this.data,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  State<_SessionBar> createState() => _SessionBarState();
}

class _SessionBarState extends State<_SessionBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnim,
      child: Dismissible(
        key: const ValueKey('session-bar'),
        direction: DismissDirection.horizontal,
        onDismissed: (_) => widget.onDismiss(),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: double.infinity,
            color: CF.chrono,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.data.dayStr,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(30),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              widget.data.durationStr,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            widget.data.timeRangeStr,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withAlpha(200),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            widget.data.amountStr,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withAlpha(220),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (widget.data.clientId != null)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(
                      LucideIcons.chevronRight,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
