import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_color.dart';

class VendorDashboardScreen extends StatefulWidget {
  const VendorDashboardScreen({super.key});

  @override
  State<VendorDashboardScreen> createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends State<VendorDashboardScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _error;
  String _shopName = 'Ma boutique';
  int _productCount = 0;
  int _stockCount = 0;
  int _orderCount = 0;
  num _sales = 0;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Session vendeur introuvable.');
      final shop = await _supabase
          .from('boutiques')
          .select('nom_boutique')
          .eq('id_vendeur', user.id)
          .maybeSingle();
      final productsResponse = await _supabase
          .from('produits')
          .select('id_produit, stock')
          .eq('id_vendeur', user.id);
      final products = List<Map<String, dynamic>>.from(productsResponse);
      final productIds = products.map((item) => item['id_produit']).whereType<Object>().toList();
      final stock = products.fold<int>(
        0,
        (total, item) => total + (int.tryParse('${item['stock'] ?? 0}') ?? 0),
      );

      var orderCount = 0;
      num sales = 0;
      if (productIds.isNotEmpty) {
        final linesResponse = await _supabase
            .from('lignes_commande')
            .select('id_commande, id_produit, quantite, prix_unitaire')
            .inFilter('id_produit', productIds);
        final lines = List<Map<String, dynamic>>.from(linesResponse);
        final orderIds = lines.map((line) => line['id_commande']).whereType<Object>().toSet();
        if (orderIds.isNotEmpty) {
          final ordersResponse = await _supabase
              .from('commandes')
              .select('id_commande, statut')
              .inFilter('id_commande', orderIds.toList());
          final orders = List<Map<String, dynamic>>.from(ordersResponse);
          orderCount = orders.length;
          final statuses = <Object, String>{
            for (final order in orders)
              if (order['id_commande'] != null)
                order['id_commande'] as Object: order['statut']?.toString().toLowerCase() ?? '',
          };
          for (final line in lines) {
            final status = statuses[line['id_commande']] ?? '';
            if (status.contains('attente') || status.contains('paiement') || status.contains('annul')) continue;
            final quantity = int.tryParse('${line['quantite'] ?? 0}') ?? 0;
            final price = num.tryParse('${line['prix_unitaire'] ?? 0}') ?? 0;
            sales += quantity * price;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        final name = shop?['nom_boutique']?.toString().trim();
        _shopName = name == null || name.isEmpty
            ? (user.userMetadata?['nom_commerce']?.toString() ??
                'Ma boutique')
            : name;
        _productCount = products.length;
        _stockCount = stock;
        _orderCount = orderCount;
        _sales = sales;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Widget _metric(String title, String value, IconData icon) {
    return Container(
      constraints: const BoxConstraints(minHeight: 94),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 19, color: AppColor.primary),
          const SizedBox(height: 8),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColor.textSecondary)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.background,
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: AppColor.background,
        actions: [IconButton(onPressed: _loadSummary, tooltip: 'Actualiser', icon: const Icon(Icons.refresh))],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColor.primary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Chargement impossible : $_error', textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _loadSummary, child: const Text('Réessayer')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSummary,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    children: [
                      Text(_shopName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      const Text('Activité de votre boutique', style: TextStyle(color: AppColor.textSecondary)),
                      const SizedBox(height: 18),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.42,
                        children: [
                          _metric('Produits', '$_productCount', Icons.inventory_2_outlined),
                          _metric('Articles en stock', '$_stockCount', Icons.warehouse_outlined),
                          _metric('Commandes reçues', '$_orderCount', Icons.receipt_long_outlined),
                          _metric('Ventes confirmées', '${_sales.toStringAsFixed(0)} FCFA', Icons.payments_outlined),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text('Accès rapide', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/vendor/shop-management'),
                        icon: const Icon(Icons.storefront_outlined),
                        label: const Text('Ouvrir My Shop'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/vendor/sales'),
                        icon: const Icon(Icons.point_of_sale_outlined),
                        label: const Text('Voir les ventes'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/vendor/marketing-ia'),
                        icon: const Icon(Icons.auto_awesome_outlined),
                        label: const Text('Créer une campagne marketing'),
                      ),
                    ],
                  ),
                ),
    );
  }
}