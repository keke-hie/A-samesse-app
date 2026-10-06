import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NavItem {
  const NavItem({
    required this.location,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.matcher,
  });

  final String location;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Règle de sélection de l'onglet ; par défaut, le chemin commence par [location].
  final bool Function(Uri uri)? matcher;

  bool matches(Uri uri) =>
      matcher?.call(uri) ?? uri.path.startsWith(Uri.parse(location).path);
}

/// Barre de navigation inférieure commune aux quatre espaces
/// (client, vendeur, livreur, admin).
class NavShell extends StatelessWidget {
  const NavShell({super.key, required this.items, required this.child});

  final List<NavItem> items;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final uri = GoRouterState.of(context).uri;
    final index = items.indexWhere((item) => item.matches(uri));
    return Scaffold(
      body: child,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: NavigationBar(
          selectedIndex: index < 0 ? 0 : index,
          onDestinationSelected: (i) => context.go(items[i].location),
          destinations: [
            for (final item in items)
              NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: item.label,
              ),
          ],
        ),
      ),
    );
  }
}
