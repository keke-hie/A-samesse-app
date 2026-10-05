import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_color.dart';

class VendorOrdersScreen extends StatefulWidget {
  const VendorOrdersScreen({super.key});

  @override
  State<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends State<VendorOrdersScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = [];
  Map<String, List<Map<String, dynamic>>> _linesByOrder = {};

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null)
        throw Exception('Connectez-vous pour voir les commandes.');

      final products = await _supabase
          .from('produits')
          .select('id_produit, nom_produit')
          .eq('id_vendeur', userId);
      final productNames = <String, String>{
        for (final product in List<Map<String, dynamic>>.from(products))
          product['id_produit'].toString():
              product['nom_produit']?.toString() ?? 'Produit',
      };

      if (productNames.isEmpty) {
        if (!mounted) return;
        setState(() {
          _orders = [];
          _linesByOrder = {};
          _isLoading = false;
        });
        return;
      }

      final linesResponse = await _supabase
          .from('lignes_commande')
          .select(
            'id_commande, id_produit, quantite, prix_unitaire, couleur, taille',
          )
          .inFilter('id_produit', productNames.keys.toList());
      final lines = List<Map<String, dynamic>>.from(linesResponse)
          .map(
            (line) => {
              ...line,
              'nom_produit':
                  productNames[line['id_produit'].toString()] ?? 'Produit',
            },
          )
          .toList();
      final orderIds = lines
          .map((line) => line['id_commande'])
          .whereType<Object>()
          .toSet();

      if (orderIds.isEmpty) {
        if (!mounted) return;
        setState(() {
          _orders = [];
          _linesByOrder = {};
          _isLoading = false;
        });
        return;
      }

      final ordersResponse = await _supabase
          .from('commandes')
          .select(
            'id_commande, montant_total, statut, date_commande, adresse_livraison, mode_paiement',
          )
          .inFilter('id_commande', orderIds.toList())
          .order('date_commande', ascending: false);
      final orders = List<Map<String, dynamic>>.from(ordersResponse);
      final linesByOrder = <String, List<Map<String, dynamic>>>{};
      for (final line in lines) {
        final id = line['id_commande'].toString();
        linesByOrder.putIfAbsent(id, () => []).add(line);
      }

      if (!mounted) return;
      setState(() {
        _orders = orders;
        _linesByOrder = linesByOrder;
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

  String _formatPrice(dynamic value) {
    final amount = value is num
        ? value
        : num.tryParse(value?.toString() ?? '') ?? 0;
    return '${amount.toStringAsFixed(0)} FCFA';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.background,
      appBar: AppBar(
        title: const Text('Commandes reçues'),
        backgroundColor: AppColor.background,
        actions: [
          IconButton(
            onPressed: _loadOrders,
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColor.primary),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      size: 36,
                      color: AppColor.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Chargement impossible : $_error',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _loadOrders,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            )
          : _orders.isEmpty
          ? RefreshIndicator(
              onRefresh: _loadOrders,
              child: ListView(
                children: const [
                  SizedBox(height: 130),
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 42,
                    color: AppColor.primary,
                  ),
                  SizedBox(height: 12),
                  Center(child: Text('Aucune commande reçue pour le moment.')),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadOrders,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: _orders.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final order = _orders[index];
                  final orderId = order['id_commande'].toString();
                  final lines = _linesByOrder[orderId] ?? [];
                  final vendorTotal = lines.fold<num>(0, (total, line) {
                    final price = num.tryParse('${line['prix_unitaire']}') ?? 0;
                    final quantity = int.tryParse('${line['quantite']}') ?? 0;
                    return total + price * quantity;
                  });
                  final status =
                      order['statut']?.toString().replaceAll('_', ' ') ??
                      'En préparation';
                  final date = order['date_commande']?.toString();
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Commande #${orderId.length > 8 ? orderId.substring(0, 8) : orderId}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColor.primarySoft,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                status,
                                style: const TextStyle(
                                  color: AppColor.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (date != null) ...[
                          const SizedBox(height: 5),
                          Text(
                            date.replaceFirst('T', ' ').split('.').first,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColor.textSecondary,
                            ),
                          ),
                        ],
                        const Divider(height: 20),
                        for (final line in lines)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${line['nom_produit']} × ${line['quantite']}',
                                  ),
                                ),
                                Text(
                                  _formatPrice(
                                    (num.tryParse('${line['prix_unitaire']}') ??
                                            0) *
                                        (int.tryParse('${line['quantite']}') ??
                                            0),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Total commande',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            Text(
                              _formatPrice(vendorTotal),
                              style: const TextStyle(
                                color: AppColor.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        if (order['adresse_livraison'] != null &&
                            order['adresse_livraison']
                                .toString()
                                .isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Livraison : ${order['adresse_livraison']}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColor.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
