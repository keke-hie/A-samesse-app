import 'package:flutter/material.dart';

import 'nav_shell.dart';

class VendorWrapper extends StatelessWidget {
  const VendorWrapper({super.key, required this.child});

  final Widget child;

  static final _items = [
    const NavItem(
      location: '/vendor/dashboard',
      label: 'Accueil',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
    ),
    NavItem(
      location: '/vendor/shop-management',
      label: 'Boutique',
      icon: Icons.storefront_outlined,
      selectedIcon: Icons.storefront_rounded,
      matcher: (uri) =>
          uri.path.startsWith('/vendor/shop-management') ||
          uri.path.startsWith('/vendor/products') ||
          uri.path.startsWith('/vendor/deals'),
    ),
    NavItem(
      location: '/vendor/sales',
      label: 'Commandes',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
      matcher: (uri) =>
          uri.path.startsWith('/vendor/sales') ||
          uri.path.startsWith('/vendor/orders'),
    ),
    NavItem(
      location: '/vendor/marketing-ia',
      label: 'Marketing',
      icon: Icons.auto_awesome_outlined,
      selectedIcon: Icons.auto_awesome,
      matcher: (uri) =>
          uri.path.startsWith('/vendor/marketing-ia') ||
          uri.path.startsWith('/vendor/campaign-refine'),
    ),
    const NavItem(
      location: '/vendor/profile',
      label: 'Profil',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) => NavShell(items: _items, child: child);
}
