import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../services/share_service.dart';
import '../theme/app_theme.dart';
import '../widgets/arch_icon.dart';
import 'apps_screen.dart';
import 'home_screen.dart';
import 'messages_screen.dart';
import 'vault_screen.dart';

/// La coquille de l'app : la barre de navigation en bas et la page choisie.
/// StatefulWidget car il doit se souvenir de l'onglet sélectionné.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // Index de l'onglet affiché (0 = Accueil).
  int _selectedIndex = 0;

  static const _messagesIndex = 2;
  static const _vaultIndex = 3;

  // Texte partagé depuis les autres apps.
  final _share = ShareService();

  // Les pages, dans le même ordre que les onglets. Recréées à chaque
  // affichage (léger) : le Coffre doit savoir s'il est visible.
  List<Widget> get _pages => [
        const HomeScreen(),
        const AppsScreen(),
        MessagesScreen(sharedText: _share.received),
        VaultScreen(visible: _selectedIndex == _vaultIndex),
      ];

  @override
  void initState() {
    super.initState();
    _share.received.addListener(_showMessages);
    _share.start();
  }

  @override
  void dispose() {
    _share.received.removeListener(_showMessages);
    _share.dispose();
    super.dispose();
  }

  // Un texte arrive : on affiche l'onglet Messages qui va l'analyser.
  void _showMessages() {
    setState(() => _selectedIndex = _messagesIndex);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      // IndexedStack garde toutes les pages en mémoire
      // et n'affiche que celle de l'index choisi.
      body: IndexedStack(index: _selectedIndex, children: _pages),
      // Fine ligne de séparation au-dessus de la barre.
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: AppTheme.navigationBarBorder),
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
              icon: const Icon(Icons.sms_outlined),
              selectedIcon: const Icon(Icons.sms),
              label: l.navMessages,
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
