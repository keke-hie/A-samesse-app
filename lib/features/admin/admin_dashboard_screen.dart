import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_color.dart';
import '../../core/models/order_status.dart';
import '../../core/services/admin_service.dart';
import '../../core/services/order_service.dart';
import '../../core/utils/error_message.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state.dart';

class _AdminSummary {
  _AdminSummary({
    required this.orders,
    required this.users,
    required this.disputes,
  });

  final List<Map<String, dynamic>> orders;
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> disputes;

  int countOrders(OrderStatus status) => orders
      .where((order) => OrderStatus.parse(order['statut']) == status)
      .length;

  num get paidSales => orders
      .where((order) {
        final status = OrderStatus.parse(order['statut']);
        return status != OrderStatus.awaitingPayment &&
            status != OrderStatus.cancelled;
      })
      .fold<num>(
        0,
        (sum, order) => sum + (parseAmount(order['montant_total']) ?? 0),
      );

  int get pendingAccounts =>
      users.where((user) => user['statut_compte'] == 'en_attente').length;

  int get openDisputes => disputes
      .where(
        (dispute) => const {'ouvert', 'en_examen'}.contains(dispute['statut']),
      )
      .length;
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _adminService = AdminService();
  final _orderService = OrderService();
  late Future<_AdminSummary> _summaryFuture = _load();

  Future<_AdminSummary> _load() async {
    final results = await Future.wait<List<Map<String, dynamic>>>([
      _orderService.adminListOrders(),
      _adminService.listUsers(),
      _adminService.listDisputes(),
    ]);
    return _AdminSummary(
      orders: results[0],
      users: results[1],
      disputes: results[2],
    );
  }

  Future<void> _reload() async {
    final future = _load();
    setState(() => _summaryFuture = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administration'),
        actions: [
          IconButton(
            onPressed: _reload,
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<_AdminSummary>(
        future: _summaryFuture,
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
          final summary = snapshot.data!;
          final toPrepare =
              summary.countOrders(OrderStatus.paid) +
              summary.countOrders(OrderStatus.preparing);

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Text(
                  'À traiter',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                _TodoTile(
                  icon: Icons.inventory_2_outlined,
                  label: 'Commandes à préparer',
                  count: toPrepare,
                  onTap: () => context.go('/admin/management?tab=orders'),
                ),
                _TodoTile(
                  icon: Icons.how_to_reg_outlined,
                  label: 'Comptes pro à valider',
                  count: summary.pendingAccounts,
                  onTap: () => context.go('/admin/management?tab=users'),
                ),
                _TodoTile(
                  icon: Icons.report_problem_outlined,
                  label: 'Litiges ouverts',
                  count: summary.openDisputes,
                  onTap: () => context.go('/admin/management?tab=disputes'),
                ),
                const SizedBox(height: 20),
                Text(
                  'Activité',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.5,
                  children: [
                    _Stat('Ventes payées', formatPrice(summary.paidSales)),
                    _Stat('Commandes', '${summary.orders.length}'),
                    _Stat(
                      'En livraison',
                      '${summary.countOrders(OrderStatus.shipping)}',
                    ),
                    _Stat('Utilisateurs', '${summary.users.length}'),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TodoTile extends StatelessWidget {
  const _TodoTile({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppColor.primary),
        title: Text(label),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Badge(
              isLabelVisible: count > 0,
              backgroundColor: AppColor.primary,
              label: Text('$count'),
              child: count > 0
                  ? const SizedBox(width: 8)
                  : const Icon(Icons.check_rounded, color: AppColor.success),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColor.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
