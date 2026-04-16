import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/providers/session_bar_provider.dart';

class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  static const _brand = Color(0xFF305DA8);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionBar = ref.watch(sessionBarProvider);
    final currentIdx = navigationShell.currentIndex;

    // Branches : 0=Projets, 1=Clients, 2=Chrono, 3=Factures, 4=PDFs

    return Scaffold(
      body: Column(
        children: [
          Expanded(child: navigationShell),
          // ── Session bar persistante (mini-player) ─────────────────
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

      // ── Bottom bar ────────────────────────────────────────────────
      bottomNavigationBar: BottomAppBar(
        padding: EdgeInsets.zero,
        height: 64,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // ── Projets (branch 0) ──
            _NavItem(
              svgInactive: 'assets/icons/folder-inactif.svg',
              svgActive: 'assets/icons/folder-actif.svg',
              label: 'Projets',
              isSelected: currentIdx == 0,
              onTap: () => navigationShell.goBranch(0,
                  initialLocation: currentIdx == 0),
            ),

            // ── Clients (branch 1) ──
            _NavItem(
              svgInactive: 'assets/icons/clients-inactif.svg',
              svgActive: 'assets/icons/clients-actif.svg',
              label: 'Clients',
              isSelected: currentIdx == 1,
              onTap: () => navigationShell.goBranch(1,
                  initialLocation: currentIdx == 1),
            ),

            // ── Chrono (branch 2) — onglet normal ──
            _NavItem(
              svgInactive: 'assets/icons/chrono-inactif.svg',
              svgActive: 'assets/icons/chrono-actif.svg',
              label: 'Chrono',
              isSelected: currentIdx == 2,
              onTap: () => navigationShell.goBranch(2,
                  initialLocation: currentIdx == 2),
            ),

            // ── Factures (branch 3) ──
            _NavItem(
              svgInactive: 'assets/icons/Facture-inactif.svg',
              svgActive: 'assets/icons/Facture-actif.svg',
              label: 'Factures',
              isSelected: currentIdx == 3,
              onTap: () => navigationShell.goBranch(3,
                  initialLocation: currentIdx == 3),
            ),

            // ── PDFs (branch 4) ──
            _NavItem(
              svgInactive: 'assets/icons/pdf-inactifs.svg',
              svgActive: 'assets/icons/pdf.actif.svg',
              label: 'PDFs',
              isSelected: currentIdx == 4,
              onTap: () => navigationShell.goBranch(4,
                  initialLocation: currentIdx == 4),
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
            color: const Color(0xFF305DA8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // ── Contenu 2 lignes ───────────────────────────────────
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Ligne 1 — date + capsule durée
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
                      // Ligne 2 — heures + montant
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
                // ── Chevron ────────────────────────────────────────────
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

// ─── Navigation item (SVG custom) ─────────────────────────────────────────

class _NavItem extends StatefulWidget {
  final String svgInactive;
  final String svgActive;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.svgInactive,
    required this.svgActive,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;

  static const _active = Color(0xFF305DA8);
  static const _inactive = Color(0xFF9CA3AF);

  @override
  Widget build(BuildContext context) {
    final color = widget.isSelected ? _active : _inactive;
    final svgPath = widget.isSelected ? widget.svgActive : widget.svgInactive;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 60,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        decoration: BoxDecoration(
          color: _pressed
              ? (Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withAlpha(15)
                  : Colors.black.withAlpha(10))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              svgPath,
              width: 22,
              height: 22,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
            const SizedBox(height: 3),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                    widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
