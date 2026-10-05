import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_color.dart';
import '../core/localization/app_locale.dart';

class DeliveryWrapper extends StatelessWidget {
  final Widget child;

  const DeliveryWrapper({super.key, required this.child});

  int _selectedIndex(String location) {
    if (location.startsWith('/delivery/map')) return 1;
    if (location.startsWith('/delivery/profile')) return 2;
    return 0;
  }

  void _navigate(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/delivery/missions');
        return;
      case 1:
        context.go('/delivery/map');
        return;
      case 2:
        context.go('/delivery/profile');
        return;
      default:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final destinations = [
      NavigationDestination(
        icon: const Icon(Icons.assignment_outlined),
        selectedIcon: const Icon(Icons.assignment),
        label: AppLocale.text(context, 'Missions', 'Missions'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.map_outlined),
        selectedIcon: const Icon(Icons.map),
        label: AppLocale.text(context, 'Carte', 'Map'),
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
        selectedIndex: _selectedIndex(GoRouterState.of(context).uri.path),
        onDestinationSelected: (index) => _navigate(context, index),
        indicatorColor: AppColor.primarySoft,
        destinations: destinations,
      ),
    );
  }
}