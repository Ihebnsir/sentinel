import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
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

  // Les pages, dans le même ordre que les onglets.
  static const _pages = [
    HomeScreen(),
    AppsScreen(),
    MessagesScreen(),
    VaultScreen(),
  ];

  @override
  Widget build(BuildContext context) {
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
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.shield_outlined),
              selectedIcon: Icon(Icons.shield),
              label: 'Accueil',
            ),
            NavigationDestination(
              icon: Icon(Icons.apps_outlined),
              selectedIcon: Icon(Icons.apps),
              label: 'Applications',
            ),
            NavigationDestination(
              icon: Icon(Icons.sms_outlined),
              selectedIcon: Icon(Icons.sms),
              label: 'Messages',
            ),
            NavigationDestination(
              icon: Icon(Icons.lock_outline),
              selectedIcon: Icon(Icons.lock),
              label: 'Coffre',
            ),
          ],
        ),
      ),
    );
  }
}
