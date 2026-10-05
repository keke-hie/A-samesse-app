import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_color.dart';
import '../core/localization/app_locale.dart';

class VendorWrapper extends StatelessWidget {
  final Widget child;

  const VendorWrapper({super.key, required this.child});

  int _selectedIndex(String location) {
    if (location.startsWith('/vendor/shop-management') ||
        location.startsWith('/vendor/products')) return 1;
    if (location.startsWith('/vendor/sales') ||
        location.startsWith('/vendor/orders')) return 2;
    if (location.startsWith('/vendor/marketing-ia') ||
        location.startsWith('/vendor/campaign-refine')) return 3;
    if (location.startsWith('/vendor/profile')) return 4;
    return 0;
  }

  void _navigate(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/vendor/dashboard');
        return;
      case 1:
        context.go('/vendor/shop-management');
        return;
      case 2:
        context.go('/vendor/sales');
        return;
      case 3:
        context.go('/vendor/marketing-ia');
        return;
      case 4:
        context.go('/vendor/profile');
        return;
      default:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndex(GoRouterState.of(context).uri.path);

    final destinations = [
      NavigationDestination(
        icon: const Icon(Icons.dashboard_outlined),
        selectedIcon: const Icon(Icons.dashboard),
        label: AppLocale.text(context, 'Dashboard', 'Dashboard'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.storefront_outlined),
        selectedIcon: const Icon(Icons.storefront),
        label: AppLocale.text(context, 'Ma boutique', 'My Shop'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.point_of_sale_outlined),
        selectedIcon: const Icon(Icons.point_of_sale),
        label: AppLocale.text(context, 'Ventes', 'Sales'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.auto_awesome_outlined),
        selectedIcon: const Icon(Icons.auto_awesome),
        label: AppLocale.text(context, 'Marketing IA', 'Marketing AI'),
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
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => _navigate(context, index),
        indicatorColor: AppColor.primarySoft,
        destinations: destinations,
      ),
    );
  }
}