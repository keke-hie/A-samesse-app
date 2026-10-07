import 'package:flutter/material.dart';

import '../../core/constants/app_color.dart';
import '../../core/models/order_status.dart';
import '../../core/services/order_service.dart';
import '../../core/services/vendor_service.dart';
import '../../core/utils/error_message.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/status_chip.dart';

class VendorOrdersScreen extends StatefulWidget {
  const VendorOrdersScreen({super.key});

  @override
  State<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends State<VendorOrdersScreen> {
  final _vendorService = VendorService();
  final _orderService = OrderService();
  late Future<List<VendorOrder>> _ordersFuture = _vendorService.fetchOrders();
  final Set<String> _updating = {};

  Future<void> _reload() async {
    final future = _vendorService.fetchOrders();
    setState(() => _ordersFuture = future);
    await future;
  }

  Future<void> _advance(VendorOrder order, OrderStatus next) async {
    setState(() => _updating.add(order.id));
    try {
      await _orderService.vendorAdvance(order.id, next.value);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            next == OrderStatus.ready
                ? 'Commande prête : elle est proposée aux livreurs.'
                : 'Préparation commencée.',
          ),
        ),
      );
      await _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _updating.remove(order.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Commandes reçues'),
        actions: [
          IconButton(
            onPressed: _reload,
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<VendorOrder>>(
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
          final orders = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _reload,
            child: orders.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 80),
                      EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Aucune commande reçue pour le moment',
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: orders.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return _VendorOrderCard(
                        order: order,
                        isUpdating: _updating.contains(order.id),
                        onAdvance: (next) => _advance(order, next),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}

class _VendorOrderCard extends StatelessWidget {
  const _VendorOrderCard({
    required this.order,
    required this.isUpdating,
    required this.onAdvance,
  });

  final VendorOrder order;
  final bool isUpdating;
  final ValueChanged<OrderStatus> onAdvance;

  @override
  Widget build(BuildContext context) {
    final status = order.status;
    final next = switch (status) {
      OrderStatus.paid => OrderStatus.preparing,
      OrderStatus.preparing => OrderStatus.ready,
      _ => null,
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
                    'Commande ${shortOrderRef(order.id)}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                StatusChip(label: status.label, color: status.color),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              formatDate(order.date, withTime: true),
              style: const TextStyle(
                fontSize: 12,
                color: AppColor.textSecondary,
              ),
            ),
            const Divider(height: 22),
            for (final line in order.lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(line.label)),
                    Text(formatPrice(line.total)),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Votre part',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  formatPrice(order.vendorTotal),
                  style: const TextStyle(
                    color: AppColor.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            if ((order.address ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Livraison : ${order.address}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColor.textSecondary,
                ),
              ),
            ],
            if (status == OrderStatus.awaitingPayment) ...[
              const SizedBox(height: 10),
              const Text(
                'En attente du paiement du client : ne pas expédier.',
                style: TextStyle(fontSize: 12, color: AppColor.warning),
              ),
            ],
            if (next != null) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: isUpdating ? null : () => onAdvance(next),
                icon: isUpdating
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        next == OrderStatus.ready
                            ? Icons.inventory_rounded
                            : Icons.play_arrow_rounded,
                      ),
                label: Text(
                  next == OrderStatus.ready
                      ? 'Marquer prête à expédier'
                      : 'Commencer la préparation',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
