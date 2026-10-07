import 'package:flutter/material.dart';

import 'nav_shell.dart';

class AdminWrapper extends StatelessWidget {
  const AdminWrapper({super.key, required this.child});

  final Widget child;

  static bool _isTab(Uri uri, String? tab) =>
      uri.path.startsWith('/admin/management') &&
      (uri.queryParameters['tab'] ?? 'orders') == tab;

  static final _items = [
    const NavItem(
      location: '/admin/dashboard',
      label: 'Accueil',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
    ),
    NavItem(
      location: '/admin/management?tab=orders',
      label: 'Commandes',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
      matcher: (uri) => _isTab(uri, 'orders'),
    ),
    NavItem(
      location: '/admin/management?tab=users',
      label: 'Comptes',
      icon: Icons.people_outline_rounded,
      selectedIcon: Icons.people_rounded,
      matcher: (uri) => _isTab(uri, 'users'),
    ),
    NavItem(
      location: '/admin/management?tab=disputes',
      label: 'Litiges',
      icon: Icons.report_problem_outlined,
      selectedIcon: Icons.report_problem_rounded,
      matcher: (uri) => _isTab(uri, 'disputes'),
    ),
    const NavItem(
      location: '/admin/profile',
      label: 'Profil',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) => NavShell(items: _items, child: child);
}
