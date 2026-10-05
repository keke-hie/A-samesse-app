import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_color.dart';
import '../core/localization/app_locale.dart';

class AdminWrapper extends StatelessWidget {
  final Widget child;

  const AdminWrapper({super.key, required this.child});

  int _selectedIndex(String location) {
    if (location.startsWith('/admin/management')) {
      return Uri.parse(location).queryParameters['tab'] == 'disputes' ? 2 : 1;
    }
    if (location.startsWith('/admin/profile')) return 3;
    return 0;
  }

  void _navigate(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/admin/dashboard');
        return;
      case 1:
        context.go('/admin/management');
        return;
      case 2:
        context.go('/admin/management?tab=disputes');
        return;
      case 3:
        context.go('/admin/profile');
        return;
      default:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final destinations = [
      NavigationDestination(
        icon: const Icon(Icons.dashboard_outlined),
        selectedIcon: const Icon(Icons.dashboard),
        label: AppLocale.text(context, 'Dashboard', 'Dashboard'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.people_outline),
        selectedIcon: const Icon(Icons.people),
        label: AppLocale.text(context, 'Utilisateurs', 'Users'),
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
    ];

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex(GoRouterState.of(context).uri.toString()),
        onDestinationSelected: (index) => _navigate(context, index),
        indicatorColor: AppColor.primarySoft,
        destinations: destinations,
      ),
    );
  }
}