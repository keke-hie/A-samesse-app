import 'package:flutter/material.dart';

import '../../../core/constants/app_color.dart';
import '../../../core/models/order_status.dart';
import '../../../core/services/order_service.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_chip.dart';

/// Suivi des commandes et confirmation manuelle des paiements
/// (en attendant l'intégration d'un agrégateur Mobile Money).
class AdminOrdersTab extends StatefulWidget {
  const AdminOrdersTab({super.key});

  @override
  State<AdminOrdersTab> createState() => _AdminOrdersTabState();
}

class _AdminOrdersTabState extends State<AdminOrdersTab> {
  final _orderService = OrderService();
  late Future<List<Map<String, dynamic>>> _ordersFuture = _orderService
      .adminListOrders();
  bool _onlyAwaitingPayment = true;
  final Set<String> _busy = {};

  Future<void> _reload() async {
    final future = _orderService.adminListOrders();
    setState(() => _ordersFuture = future);
    await future;
  }

  Future<void> _run(
    String orderId,
    Future<void> Function() action,
    String done,
  ) async {
    setState(() => _busy.add(orderId));
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
      await _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(orderId));
    }
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Retour'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _ordersFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Chargement impossible',
            message: friendlyError(snapshot.error!),
            actionLabel: 'Réessayer',
            onAction: _reload,
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final orders = snapshot.data!
            .where(
              (order) =>
                  !_onlyAwaitingPayment ||
                  OrderStatus.parse(order['statut']) ==
                      OrderStatus.awaitingPayment,
            )
            .toList();

        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Seulement les paiements à confirmer'),
                value: _onlyAwaitingPayment,
                onChanged: (value) =>
                    setState(() => _onlyAwaitingPayment = value),
              ),
              if (orders.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: EmptyState(
                    icon: Icons.task_alt_rounded,
                    title: 'Rien à traiter',
                  ),
                ),
              for (final order in orders) _buildOrder(order),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrder(Map<String, dynamic> order) {
    final orderId = order['id_commande'].toString();
    final status = OrderStatus.parse(order['statut']);
    final busy = _busy.contains(orderId);
    final canCancel = !status.isFinal && status != OrderStatus.shipping;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Commande ${shortOrderRef(orderId)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                StatusChip(label: status.label, color: status.color),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${order['acheteur'] ?? 'Client'} · ${formatDate(order['date_commande'], withTime: true)}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColor.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${formatPrice(order['montant_total'])} · ${order['mode_paiement'] ?? '—'}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (status == OrderStatus.awaitingPayment || canCancel) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  if (status == OrderStatus.awaitingPayment)
                    FilledButton(
                      onPressed: busy
                          ? null
                          : () async {
                              if (!await _confirm(
                                'Confirmer le paiement ?',
                                'Vérifie d’abord la réception de ${formatPrice(order['montant_total'])} sur le compte marchand.',
                              )) {
                                return;
                              }
                              await _run(
                                orderId,
                                () => _orderService.confirmPayment(orderId),
                                'Paiement confirmé : le vendeur peut préparer.',
                              );
                            },
                      child: const Text('Paiement reçu'),
                    ),
                  if (canCancel)
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColor.danger,
                      ),
                      onPressed: busy
                          ? null
                          : () async {
                              if (!await _confirm(
                                'Annuler la commande ?',
                                'Le stock sera restitué. Pense au remboursement si le client a payé.',
                              )) {
                                return;
                              }
                              await _run(
                                orderId,
                                () => _orderService.cancelOrder(orderId),
                                'Commande annulée.',
                              );
                            },
                      child: const Text('Annuler'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
