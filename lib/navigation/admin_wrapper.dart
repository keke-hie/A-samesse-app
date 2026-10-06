import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/localization/app_locale.dart';

class AdminWrapper extends StatelessWidget {
  final Widget child;

  const AdminWrapper({super.key, required this.child});

  static const _locations = [
    '/admin/dashboard',
    '/admin/management?tab=orders',
    '/admin/management?tab=users',
    '/admin/management?tab=disputes',
    '/admin/profile',
  ];

  int _selectedIndex(Uri uri) {
    if (uri.path.startsWith('/admin/management')) {
      return switch (uri.queryParameters['tab']) {
        'users' => 2,
        'disputes' => 3,
        _ => 1,
      };
    }
    if (uri.path.startsWith('/admin/profile')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex(GoRouterState.of(context).uri),
        onDestinationSelected: (index) => context.go(_locations[index]),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard),
            label: AppLocale.text(context, 'Accueil', 'Home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long),
            label: AppLocale.text(context, 'Commandes', 'Orders'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.people_outline),
            selectedIcon: const Icon(Icons.people),
            label: AppLocale.text(context, 'Comptes', 'Accounts'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.report_problem_outlined),
            selectedIcon: const Icon(Icons.report_problem),
            label: AppLocale.text(context, 'Litiges', 'Disputes'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: AppLocale.text(context, 'Profil', 'Profile'),
          ),
        ],
      ),
    );
  }
}
