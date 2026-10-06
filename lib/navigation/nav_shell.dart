import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_color.dart';

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

/// Navigation commune aux quatre espaces (client, vendeur, livreur, admin) :
/// barre du bas sur téléphone, menu latéral sur grand écran (console web).
class NavShell extends StatelessWidget {
  const NavShell({super.key, required this.items, required this.child});

  final List<NavItem> items;
  final Widget child;

  static const _railBreakpoint = 840.0;
  static const _extendedRailBreakpoint = 1200.0;
  static const _maxContentWidth = 1100.0;

  @override
  Widget build(BuildContext context) {
    final uri = GoRouterState.of(context).uri;
    final found = items.indexWhere((item) => item.matches(uri));
    final index = found < 0 ? 0 : found;
    final width = MediaQuery.sizeOf(context).width;
    void select(int i) => context.go(items[i].location);

    if (width >= _railBreakpoint) {
      final extended = width >= _extendedRailBreakpoint;
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: extended,
              selectedIndex: index,
              onDestinationSelected: select,
              backgroundColor: AppColor.surface,
              indicatorColor: AppColor.primarySoft,
              labelType: extended ? null : NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  extended ? "A'samesse" : "A'",
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 24,
                    color: AppColor.primary,
                  ),
                ),
              ),
              destinations: [
                for (final item in items)
                  NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: Text(item.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: select,
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
