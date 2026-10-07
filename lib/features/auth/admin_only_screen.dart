import 'package:flutter/material.dart';

import '../../core/services/session_service.dart';
import '../../core/widgets/empty_state.dart';

/// Version web : affichée quand un compte non administrateur se connecte.
class AdminOnlyScreen extends StatelessWidget {
  const AdminOnlyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: EmptyState(
        icon: Icons.admin_panel_settings_outlined,
        title: 'Espace réservé aux administrateurs',
        message:
            'Les clients, vendeurs et livreurs utilisent l’application mobile '
            'A’samesse.',
        actionLabel: 'Se déconnecter',
        onAction: SessionService.instance.signOut,
      ),
    );
  }
}
