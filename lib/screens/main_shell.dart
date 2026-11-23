import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../services/share_service.dart';
import '../theme/app_colors.dart';
import '../widgets/arch_icon.dart';
import '../widgets/ui.dart';
import 'apps_screen.dart';
import 'firewall_screen.dart';
import 'home_screen.dart';
import 'links_screen.dart';
import 'vault_screen.dart';

/// La coquille de l'app : la barre de navigation en bas et la page choisie.
/// StatefulWidget car il doit se souvenir de l'onglet sélectionné.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0, this.vaultBuilder});

  /// Onglet affiché au départ (captures d'écran et tests).
  final int initialIndex;

  /// Remplace l'onglet Coffre dans les tests (coffre d'exemple).
  final Widget Function(bool visible)? vaultBuilder;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // Index de l'onglet affiché (0 = Accueil).
  late int _selectedIndex = widget.initialIndex;

  static const _linksIndex = 2;
  static const _vaultIndex = 3;

  // Lien (ou texte qui en contient un) partagé depuis les autres apps.
  final _share = ShareService();

  // Les pages, dans le même ordre que les onglets. Recréées à chaque
  // affichage (léger) : le Coffre doit savoir s'il est visible.
  List<Widget> get _pages => [
        const HomeScreen(),
        const AppsScreen(),
        LinksScreen(
          sharedText: _share.received,
          sharedImage: _share.receivedImage,
        ),
        widget.vaultBuilder?.call(_selectedIndex == _vaultIndex) ??
            VaultScreen(visible: _selectedIndex == _vaultIndex),
      ];

  @override
  void initState() {
    super.initState();
    _share.received.addListener(_showLinks);
    _share.receivedImage.addListener(_showLinks);
    _share.firewallRequests.addListener(_showFirewall);
    _share.start();
  }

  @override
  void dispose() {
    _share.received.removeListener(_showLinks);
    _share.receivedImage.removeListener(_showLinks);
    _share.firewallRequests.removeListener(_showFirewall);
    _share.dispose();
    super.dispose();
  }

  // Un texte ou une image arrive : on affiche l'onglet Liens qui va le vérifier.
  void _showLinks() {
    setState(() => _selectedIndex = _linksIndex);
  }

  // Tuile du pare-feu : écran du pare-feu par-dessus l'accueil, une seule
  // fois (les écrans ouverts avant sont refermés).
  void _showFirewall() {
    setState(() => _selectedIndex = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context)
        ..popUntil((route) => route.isFirst)
        ..push(MaterialPageRoute<void>(builder: (_) => const FirewallScreen()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      // IndexedStack garde toutes les pages en mémoire
      // et n'affiche que celle de l'index choisi.
      // Fondu court à chaque changement d'onglet (aucun si les animations
      // sont supprimées dans Android).
      body: _TabFade(
        index: _selectedIndex,
        child: IndexedStack(index: _selectedIndex, children: _pages),
      ),
      // Fine ligne de séparation au-dessus de la barre.
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.colors.ligne)),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          // setState : on change l'index et Flutter redessine l'écran.
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
          },
          destinations: [
            NavigationDestination(
              icon: const ArchIcon(),
              selectedIcon: const ArchIcon(filled: true),
              label: l.navHome,
            ),
            NavigationDestination(
              icon: const Icon(Icons.apps_outlined),
              selectedIcon: const Icon(Icons.apps),
              label: l.navApps,
            ),
            NavigationDestination(
              icon: const Icon(Icons.link),
              selectedIcon: const Icon(Icons.link),
              label: l.navLinks,
            ),
            NavigationDestination(
              icon: const Icon(Icons.lock_outline),
              selectedIcon: const Icon(Icons.lock),
              label: l.navVault,
            ),
          ],
        ),
      ),
    );
  }
}

/// Fait apparaître la page en fondu quand [index] change. Les pages
/// restent en mémoire (IndexedStack) : seul l'affichage est animé.
class _TabFade extends StatefulWidget {
  const _TabFade({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_TabFade> createState() => _TabFadeState();
}

class _TabFadeState extends State<_TabFade>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, value: 1);
  late final _opacity = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.entree,
  );

  @override
  void didUpdateWidget(_TabFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    final duration = AppMotion.of(context, AppMotion.moyen);
    if (duration == Duration.zero) return;
    _controller
      ..duration = duration
      ..forward(from: 0.4);
  }

  @override
  void dispose() {
    _opacity.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _opacity, child: widget.child);
}
