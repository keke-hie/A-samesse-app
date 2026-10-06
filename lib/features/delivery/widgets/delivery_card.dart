import 'package:flutter/material.dart';

import '../../../core/constants/app_color.dart';
import '../../../core/services/delivery_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/status_chip.dart';

/// Mission dans la liste du livreur, avec les actions possibles selon l'étape.
class DeliveryCard extends StatelessWidget {
  const DeliveryCard({
    super.key,
    required this.delivery,
    required this.isBusy,
    required this.isSharingLocation,
    this.onClaim,
    this.onAccept,
    this.onDecline,
    this.onConfirm,
    this.onOpenMap,
    this.onToggleLocation,
  });

  final Map<String, dynamic> delivery;
  final bool isBusy;
  final bool isSharingLocation;
  final VoidCallback? onClaim;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onConfirm;
  final VoidCallback? onOpenMap;
  final VoidCallback? onToggleLocation;

  static Map<String, dynamic> orderOf(Map<String, dynamic> delivery) {
    final order = delivery['commandes'];
    return order is Map<String, dynamic> ? order : const {};
  }

  static String productsLabel(Map<String, dynamic> delivery) {
    final lines = orderOf(delivery)['lignes_commande'];
    if (lines is! List || lines.isEmpty) return 'Articles de la commande';
    return lines
        .whereType<Map>()
        .map((line) {
          final product = line['produits'];
          final name = product is Map
              ? product['nom_produit']?.toString() ?? 'Produit'
              : 'Produit';
          return '$name × ${line['quantite'] ?? 1}';
        })
        .join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final stage = deliveryStageOf(delivery);
    final order = orderOf(delivery);
    final (label, color) = switch (stage) {
      DeliveryStage.available => ('Disponible', AppColor.goldDark),
      DeliveryStage.assigned => ('Attribuée', AppColor.warning),
      DeliveryStage.inProgress => ('En cours', AppColor.primary),
      DeliveryStage.delivered => ('Livrée', AppColor.success),
      DeliveryStage.cancelled => ('Annulée', AppColor.danger),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Commande ${shortOrderRef(delivery['id_commande'])}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                StatusChip(label: label, color: color),
              ],
            ),
            const SizedBox(height: 10),
            _InfoRow(
              icon: Icons.place_outlined,
              text: (delivery['adresse_destination'] ?? 'Adresse à confirmer')
                  .toString(),
            ),
            _InfoRow(
              icon: Icons.shopping_bag_outlined,
              text: productsLabel(delivery),
            ),
            _InfoRow(
              icon: Icons.payments_outlined,
              text:
                  '${formatPrice(order['montant_total'])} · paiement confirmé',
            ),
            if (stage != DeliveryStage.delivered &&
                stage != DeliveryStage.cancelled) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (stage == DeliveryStage.available)
                    FilledButton.icon(
                      onPressed: isBusy ? null : onClaim,
                      icon: const Icon(Icons.add_task_rounded),
                      label: const Text('Prendre la livraison'),
                    ),
                  if (stage == DeliveryStage.assigned) ...[
                    FilledButton(
                      onPressed: isBusy ? null : onAccept,
                      child: const Text('Accepter'),
                    ),
                    OutlinedButton(
                      onPressed: isBusy ? null : onDecline,
                      child: const Text('Refuser'),
                    ),
                  ],
                  if (stage == DeliveryStage.inProgress) ...[
                    FilledButton.icon(
                      onPressed: isBusy ? null : onConfirm,
                      icon: const Icon(Icons.verified_outlined),
                      label: const Text('Confirmer la remise'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onOpenMap,
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Carte'),
                    ),
                    IconButton(
                      tooltip: isSharingLocation
                          ? 'Arrêter le partage GPS'
                          : 'Partager ma position',
                      onPressed: onToggleLocation,
                      icon: Icon(
                        isSharingLocation
                            ? Icons.location_on
                            : Icons.location_off_outlined,
                        color: isSharingLocation
                            ? AppColor.success
                            : AppColor.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColor.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
