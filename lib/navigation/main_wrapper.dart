import 'package:flutter/material.dart';

import 'nav_shell.dart';

class MainWrapper extends StatelessWidget {
  const MainWrapper({super.key, required this.child});

  final Widget child;

  static const _items = [
    NavItem(
      location: '/home',
      label: 'Accueil',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    NavItem(
      location: '/deals',
      label: 'Offres',
      icon: Icons.local_offer_outlined,
      selectedIcon: Icons.local_offer_rounded,
    ),
    NavItem(
      location: '/cart',
      label: 'Panier',
      icon: Icons.shopping_bag_outlined,
      selectedIcon: Icons.shopping_bag_rounded,
    ),
    NavItem(
      location: '/orders',
      label: 'Commandes',
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2_rounded,
    ),
    NavItem(
      location: '/profile',
      label: 'Profil',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) => NavShell(items: _items, child: child);
}
