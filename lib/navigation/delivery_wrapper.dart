import 'package:flutter/material.dart';

import 'nav_shell.dart';

class DeliveryWrapper extends StatelessWidget {
  const DeliveryWrapper({super.key, required this.child});

  final Widget child;

  static const _items = [
    NavItem(
      location: '/delivery/missions',
      label: 'Missions',
      icon: Icons.assignment_outlined,
      selectedIcon: Icons.assignment_rounded,
    ),
    NavItem(
      location: '/delivery/map',
      label: 'Carte',
      icon: Icons.map_outlined,
      selectedIcon: Icons.map_rounded,
    ),
    NavItem(
      location: '/delivery/profile',
      label: 'Profil',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) => NavShell(items: _items, child: child);
}
