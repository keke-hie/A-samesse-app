import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/delivery_service.dart';
import '../../core/utils/error_message.dart';
import '../../core/widgets/empty_state.dart';
import 'delivery_tracking_screen.dart';

/// Onglet Carte du livreur : ouvre la livraison en cours, s'il y en a une.
class CourierMapScreen extends StatelessWidget {
  const CourierMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DeliveryService().listAssigned(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Carte')),
            body: EmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Chargement impossible',
              message: friendlyError(snapshot.error!),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final active = snapshot.data!
            .where(
              (delivery) =>
                  deliveryStageOf(delivery) == DeliveryStage.inProgress,
            )
            .firstOrNull;
        if (active == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Carte')),
            body: EmptyState(
              icon: Icons.map_outlined,
              title: 'Aucune livraison en cours',
              message: 'Prends une livraison pour la suivre sur la carte.',
              actionLabel: 'Voir les missions',
              onAction: () => context.go('/delivery/missions'),
            ),
          );
        }
        return DeliveryTrackingScreen(
          orderId: active['id_commande'].toString(),
          courierMode: true,
        );
      },
    );
  }
}
