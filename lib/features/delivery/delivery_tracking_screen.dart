import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_color.dart';
import '../../core/services/delivery_service.dart';
import '../../core/services/location_sharing.dart';
import '../../core/utils/error_message.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/status_chip.dart';
import 'widgets/delivery_code_dialog.dart';
import 'widgets/live_delivery_map.dart';

/// Suivi d'une livraison sur la carte.
///
/// Côté client : position du livreur en direct. Côté livreur ([courierMode]) :
/// partage GPS et confirmation de la remise avec le code du client.
class DeliveryTrackingScreen extends StatelessWidget {
  const DeliveryTrackingScreen({
    super.key,
    required this.orderId,
    this.courierMode = false,
  });

  final String orderId;
  final bool courierMode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(courierMode ? '/delivery/missions' : '/orders'),
        ),
        title: Text('Livraison ${shortOrderRef(orderId)}'),
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: DeliveryService().watchDeliveryForOrder(orderId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Suivi indisponible',
              message: friendlyError(snapshot.error!),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final delivery = snapshot.data;
          if (delivery == null) {
            return const EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Pas encore de livraison',
              message: 'Le suivi démarre quand un livreur prend ta commande.',
            );
          }
          return _TrackingBody(delivery: delivery, courierMode: courierMode);
        },
      ),
    );
  }
}

class _TrackingBody extends StatelessWidget {
  const _TrackingBody({required this.delivery, required this.courierMode});

  final Map<String, dynamic> delivery;
  final bool courierMode;

  @override
  Widget build(BuildContext context) {
    final stage = deliveryStageOf(delivery);
    final (label, color) = switch (stage) {
      DeliveryStage.delivered => ('Livrée', AppColor.success),
      DeliveryStage.inProgress => ('En route', AppColor.primary),
      DeliveryStage.cancelled => ('Annulée', AppColor.danger),
      _ => ('En attente d’un livreur', AppColor.warning),
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.local_shipping_outlined),
            title: Text(
              (delivery['adresse_destination'] ?? 'Adresse de livraison')
                  .toString(),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: delivery['date_attribution'] == null
                ? null
                : Text(
                    'Prise en charge le ${formatDate(delivery['date_attribution'], withTime: true)}',
                  ),
            trailing: StatusChip(label: label, color: color),
          ),
        ),
        const SizedBox(height: 16),
        LiveDeliveryMap(delivery: delivery),
        if (courierMode && stage == DeliveryStage.inProgress) ...[
          const SizedBox(height: 16),
          _CourierControls(deliveryId: delivery['id_livraison'].toString()),
        ],
        if (!courierMode && stage == DeliveryStage.inProgress) ...[
          const SizedBox(height: 16),
          const Card(
            color: AppColor.primarySoft,
            child: ListTile(
              leading: Icon(Icons.lock_outline_rounded),
              title: Text('Garde ton code de remise à portée de main'),
              subtitle: Text(
                'Il est dans le détail de ta commande. Donne-le au livreur à la réception.',
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CourierControls extends StatelessWidget {
  const _CourierControls({required this.deliveryId});

  final String deliveryId;

  @override
  Widget build(BuildContext context) {
    final location = LocationSharing.instance;
    return ListenableBuilder(
      listenable: location,
      builder: (context, _) {
        final sharing = location.isSharing(deliveryId);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (location.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  location.error!,
                  style: const TextStyle(color: AppColor.danger),
                ),
              ),
            OutlinedButton.icon(
              onPressed: () =>
                  sharing ? location.stop() : location.start(deliveryId),
              icon: Icon(
                sharing ? Icons.location_on : Icons.location_off_outlined,
              ),
              label: Text(
                sharing
                    ? 'Arrêter le partage de position'
                    : 'Partager ma position',
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () async {
                final confirmed = await showDeliveryCodeDialog(
                  context,
                  deliveryId,
                );
                if (confirmed != true) return;
                await location.stop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Livraison confirmée. Merci !'),
                    ),
                  );
                  context.go('/delivery/missions');
                }
              },
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Confirmer la remise'),
            ),
          ],
        );
      },
    );
  }
}
