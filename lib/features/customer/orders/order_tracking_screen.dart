import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_color.dart';
import '../../../core/models/order_status.dart';
import '../../../core/services/order_service.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/services/session_service.dart';

class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({super.key});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final _orderService = OrderService();
  final String? _userId = SessionService.instance.user?.id;
  late final Stream<List<Map<String, dynamic>>>? _ordersStream = _userId == null
      ? null
      : _orderService.watchMyOrders(_userId);

  Future<void> _cancelOrder(BuildContext sheetContext, String orderId) async {
    final confirmed = await showDialog<bool>(
      context: sheetContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Annuler la commande ?'),
        content: const Text('Les articles seront remis en vente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Garder'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColor.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Annuler la commande'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _orderService.cancelOrder(orderId);
      if (sheetContext.mounted) Navigator.pop(sheetContext);
      if (mounted) _showMessage('Commande annulée.');
    } catch (error) {
      if (mounted) _showMessage(friendlyError(error));
    }
  }

  Future<void> _openDispute(String orderId) async {
    final sent = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _DisputeDialog(orderId: orderId, orderService: _orderService),
    );
    if (sent == true && mounted) {
      _showMessage('Signalement envoyé. Un administrateur va l’examiner.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    final orderId = order['id_commande'].toString();
    final status = OrderStatus.parse(order['statut']);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColor.background,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            Text(
              'Commande ${shortOrderRef(orderId)}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: StatusChip(label: status.label, color: status.color),
            ),
            const SizedBox(height: 20),
            _StatusTimeline(status: status),
            if (status == OrderStatus.shipping) ...[
              const SizedBox(height: 16),
              _DeliveryCodeCard(
                codeFuture: _orderService.fetchDeliveryCode(orderId),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  context.push('/orders/track/$orderId');
                },
                icon: const Icon(Icons.map_outlined),
                label: const Text('Suivre le livreur'),
              ),
            ],
            const SizedBox(height: 24),
            Text('Articles', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            _OrderLines(linesFuture: _orderService.fetchOrderLines(orderId)),
            const Divider(height: 28),
            if ((parseAmount(order['frais_livraison']) ?? 0) > 0)
              _detailRow(
                'Livraison express',
                formatPrice(order['frais_livraison']),
              ),
            _detailRow('Total', formatPrice(order['montant_total'])),
            _detailRow(
              'Paiement',
              _paymentLabel(order['mode_paiement']?.toString()),
            ),
            _detailRow(
              'Date',
              formatDate(order['date_commande'], withTime: true),
            ),
            if (order['adresse_livraison'] != null)
              _detailRow('Adresse', order['adresse_livraison'].toString()),
            if (status != OrderStatus.awaitingPayment &&
                status != OrderStatus.cancelled) ...[
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () => _openDispute(orderId),
                icon: const Icon(Icons.report_problem_outlined),
                label: const Text('Signaler un problème'),
              ),
            ],
            if (status == OrderStatus.awaitingPayment) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  context.push('/pay/$orderId');
                },
                icon: const Icon(Icons.lock_outline_rounded),
                label: const Text('Payer maintenant'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColor.danger),
                onPressed: () => _cancelOrder(sheetContext, orderId),
                icon: const Icon(Icons.close_rounded),
                label: const Text('Annuler la commande'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _paymentLabel(String? mode) => switch (mode) {
    'orange_money' => 'Orange Money',
    'mobile_money' => 'MTN Mobile Money',
    'card' => 'Carte bancaire',
    _ => 'Non renseigné',
  };

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: AppColor.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes commandes')),
      body: _ordersStream == null
          ? EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Connecte-toi pour voir tes commandes',
              actionLabel: 'Se connecter',
              onAction: () => context.go('/login'),
            )
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: _ordersStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return EmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Impossible de charger tes commandes',
                    message: friendlyError(snapshot.error!),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final orders = snapshot.data!;
                if (orders.isEmpty) {
                  return EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'Aucune commande pour le moment',
                    message:
                        'Tes commandes et leur suivi en direct apparaîtront ici.',
                    actionLabel: 'Faire des achats',
                    onAction: () => context.go('/home'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: orders.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _OrderCard(
                    order: orders[index],
                    onTap: () => _showOrderDetails(orders[index]),
                  ),
                );
              },
            ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final Map<String, dynamic> order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = OrderStatus.parse(order['statut']);
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColor.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  color: AppColor.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Commande ${shortOrderRef(order['id_commande'])}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatDate(order['date_commande']),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColor.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    StatusChip(label: status.label, color: status.color),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatPrice(order['montant_total']),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColor.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColor.textMuted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == OrderStatus.awaitingPayment) {
      return const _InfoBanner(
        icon: Icons.hourglass_top_rounded,
        color: AppColor.warning,
        text:
            'Paie ta commande pour que le vendeur la prépare. '
            'Le stock est réservé pour toi.',
      );
    }
    if (status == OrderStatus.cancelled) {
      return const _InfoBanner(
        icon: Icons.cancel_outlined,
        color: AppColor.danger,
        text: 'Cette commande a été annulée.',
      );
    }

    final currentIndex = OrderStatus.timeline.indexOf(status);
    return Column(
      children: [
        for (var i = 0; i < OrderStatus.timeline.length; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Icon(
                    i <= currentIndex
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 20,
                    color: i <= currentIndex
                        ? AppColor.primary
                        : AppColor.textMuted,
                  ),
                  if (i < OrderStatus.timeline.length - 1)
                    Container(
                      width: 2,
                      height: 22,
                      color: i < currentIndex
                          ? AppColor.primary
                          : AppColor.border,
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Text(
                OrderStatus.timeline[i].label,
                style: TextStyle(
                  color: i <= currentIndex
                      ? AppColor.textPrimary
                      : AppColor.textMuted,
                  fontWeight: i == currentIndex
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryCodeCard extends StatelessWidget {
  const _DeliveryCodeCard({required this.codeFuture});

  final Future<String?> codeFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: codeFuture,
      builder: (context, snapshot) {
        final code = snapshot.data;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColor.primarySoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_outline_rounded, color: AppColor.primary),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Code de remise',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'À donner au livreur uniquement à la réception.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColor.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (code != null)
                SelectableText(
                  code,
                  style: const TextStyle(
                    color: AppColor.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                )
              else if (snapshot.connectionState == ConnectionState.waiting)
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _OrderLines extends StatelessWidget {
  const _OrderLines({required this.linesFuture});

  final Future<List<Map<String, dynamic>>> linesFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: linesFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Détail des articles indisponible pour le moment.');
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final lines = snapshot.data!;
        if (lines.isEmpty) return const Text('Aucun article détaillé.');
        return Column(
          children: [for (final line in lines) _OrderLineTile(line: line)],
        );
      },
    );
  }
}

class _OrderLineTile extends StatelessWidget {
  const _OrderLineTile({required this.line});

  final Map<String, dynamic> line;

  @override
  Widget build(BuildContext context) {
    final product = line['produits'] as Map<String, dynamic>? ?? {};
    final image = product['image_url']?.toString();
    final variants = [
      line['couleur'],
      line['taille'],
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColor.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox.square(
              dimension: 48,
              child: image != null && image.isNotEmpty
                  ? Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const ColoredBox(color: AppColor.primarySoft),
                    )
                  : const ColoredBox(color: AppColor.primarySoft),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${product['nom_produit'] ?? 'Produit'} × ${line['quantite'] ?? 1}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (variants.isNotEmpty)
                  Text(
                    variants,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColor.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            formatPrice(line['prix_unitaire']),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColor.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DisputeDialog extends StatefulWidget {
  const _DisputeDialog({required this.orderId, required this.orderService});

  final String orderId;
  final OrderService orderService;

  @override
  State<_DisputeDialog> createState() => _DisputeDialogState();
}

class _DisputeDialogState extends State<_DisputeDialog> {
  static const _reasons = [
    'Article non reçu',
    'Article endommagé',
    'Article non conforme',
    'Problème de paiement',
    'Autre',
  ];

  final _descriptionController = TextEditingController();
  String _reason = _reasons.first;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      setState(() => _error = 'Décris le problème en quelques mots.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.orderService.openDispute(
        orderId: widget.orderId,
        reason: _reason,
        description: description,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = friendlyError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Signaler un problème'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _reason,
              decoration: const InputDecoration(labelText: 'Motif'),
              items: [
                for (final reason in _reasons)
                  DropdownMenuItem(value: reason, child: Text(reason)),
              ],
              onChanged: (value) => setState(() => _reason = value ?? _reason),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Description',
                errorText: _error,
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _sending ? null : _send,
          child: const Text('Envoyer'),
        ),
      ],
    );
  }
}
