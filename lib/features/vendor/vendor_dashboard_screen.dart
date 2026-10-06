import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_color.dart';
import '../../core/services/vendor_service.dart';
import '../../core/utils/error_message.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state.dart';

class VendorDashboardScreen extends StatefulWidget {
  const VendorDashboardScreen({super.key});

  @override
  State<VendorDashboardScreen> createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends State<VendorDashboardScreen> {
  final _vendorService = VendorService();
  late Future<VendorSummary> _summaryFuture = _vendorService.fetchSummary();

  Future<void> _reload() async {
    final future = _vendorService.fetchSummary();
    setState(() => _summaryFuture = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord'),
        actions: [
          IconButton(
            onPressed: _reload,
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<VendorSummary>(
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
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Text(
                  summary.shopName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Activité de votre boutique',
                  style: TextStyle(color: AppColor.textSecondary),
                ),
                if (summary.toPrepareCount > 0) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: AppColor.primarySoft,
                    child: ListTile(
                      leading: const Icon(
                        Icons.notifications_active_outlined,
                        color: AppColor.primary,
                      ),
                      title: Text(
                        summary.toPrepareCount == 1
                            ? '1 commande à préparer'
                            : '${summary.toPrepareCount} commandes à préparer',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.go('/vendor/sales'),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.42,
                  children: [
                    _Metric('Produits', '${summary.productCount}', Icons.inventory_2_outlined),
                    _Metric('Articles en stock', '${summary.stockCount}', Icons.warehouse_outlined),
                    _Metric('Commandes reçues', '${summary.orderCount}', Icons.receipt_long_outlined),
                    _Metric('Ventes payées', formatPrice(summary.confirmedSales), Icons.payments_outlined),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Accès rapide', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                _Shortcut(
                  icon: Icons.storefront_outlined,
                  label: 'Gérer ma boutique',
                  onTap: () => context.go('/vendor/shop-management'),
                ),
                _Shortcut(
                  icon: Icons.point_of_sale_outlined,
                  label: 'Voir les commandes',
                  onTap: () => context.go('/vendor/sales'),
                ),
                _Shortcut(
                  icon: Icons.auto_awesome_outlined,
                  label: 'Créer une campagne marketing',
                  onTap: () => context.go('/vendor/marketing-ia'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.title, this.value, this.icon);

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: AppColor.primary),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColor.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppColor.primary),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
