import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/localization/app_locale.dart';

class MainWrapper extends StatefulWidget {
  final Widget child;
  const MainWrapper({super.key, required this.child});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/deals')) return 1;
    if (location.startsWith('/cart')) return 2;
    if (location.startsWith('/orders')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/home');
        return;
      case 1:
        context.go('/deals');
        return;
      case 2:
        context.go('/cart');
        return;
      case 3:
        context.go('/orders');
        return;
      case 4:
        context.go('/profile');
        return;
      default:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);

    final items = [
      BottomNavigationBarItem(
        icon: const Icon(Icons.home_outlined),
        activeIcon: const Icon(Icons.home_rounded),
        label: AppLocale.text(context, 'Accueil', 'Home'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.local_offer_outlined),
        activeIcon: const Icon(Icons.local_offer_rounded),
        label: AppLocale.text(context, 'Offres', 'Deals'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.shopping_cart_outlined),
        activeIcon: const Icon(Icons.shopping_cart_rounded),
        label: AppLocale.text(context, 'Panier', 'Cart'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.inventory_2_outlined),
        activeIcon: const Icon(Icons.inventory_2_rounded),
        label: AppLocale.text(context, 'Commandes', 'Orders'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.person_outline_rounded),
        activeIcon: const Icon(Icons.person_rounded),
        label: AppLocale.text(context, 'Profil', 'Profile'),
      ),
    ];

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: const Color(0xFFF0DDD7), width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: selectedIndex,
          onTap: (index) => _onItemTapped(index, context),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF8B2635),
          unselectedItemColor: const Color(0xFF8E8E93),
          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
          elevation: 0,
          items: items,
        ),
      ),
    );
  }
}