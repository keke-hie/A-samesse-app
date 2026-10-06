import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order_status.dart';
import '../utils/formatters.dart';

class VendorOrderLine {
  VendorOrderLine({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.color,
    this.size,
  });

  final String productName;
  final int quantity;
  final num unitPrice;
  final String? color;
  final String? size;

  num get total => unitPrice * quantity;

  String get label {
    final variants = [color, size]
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .join(', ');
    return variants.isEmpty
        ? '$productName × $quantity'
        : '$productName ($variants) × $quantity';
  }
}

class VendorOrder {
  VendorOrder({
    required this.id,
    required this.status,
    required this.date,
    required this.address,
    required this.lines,
  });

  final String id;
  final OrderStatus status;
  final String? date;
  final String? address;
  final List<VendorOrderLine> lines;

  num get vendorTotal => lines.fold<num>(0, (sum, line) => sum + line.total);
}

class VendorSummary {
  VendorSummary({
    required this.shopName,
    required this.productCount,
    required this.stockCount,
    required this.orderCount,
    required this.toPrepareCount,
    required this.confirmedSales,
  });

  final String shopName;
  final int productCount;
  final int stockCount;
  final int orderCount;
  final int toPrepareCount;
  final num confirmedSales;
}

class VendorService {
  VendorService([SupabaseClient? client])
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  String get _userId {
    final id = _supabase.auth.currentUser?.id;
    if (id == null) throw Exception('Connecte-toi à ton espace vendeur.');
    return id;
  }

  Future<List<Map<String, dynamic>>> fetchMyProducts() async {
    final response = await _supabase
        .from('produits')
        .select()
        .eq('id_vendeur', _userId)
        .order('date_ajout', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> fetchMyShop() => _supabase
      .from('boutiques')
      .select()
      .eq('id_vendeur', _userId)
      .maybeSingle();

  /// Commandes contenant au moins un produit du vendeur, avec uniquement ses lignes.
  Future<List<VendorOrder>> fetchOrders() async {
    final products = await _supabase
        .from('produits')
        .select('id_produit, nom_produit')
        .eq('id_vendeur', _userId);
    final names = <String, String>{
      for (final product in products)
        product['id_produit'].toString():
            product['nom_produit']?.toString() ?? 'Produit',
    };
    if (names.isEmpty) return [];

    final lines = await _supabase
        .from('lignes_commande')
        .select('id_commande, id_produit, quantite, prix_unitaire, couleur, taille')
        .inFilter('id_produit', names.keys.toList());
    final linesByOrder = <String, List<VendorOrderLine>>{};
    for (final line in lines) {
      linesByOrder
          .putIfAbsent(line['id_commande'].toString(), () => [])
          .add(
            VendorOrderLine(
              productName: names[line['id_produit'].toString()] ?? 'Produit',
              quantity: (parseAmount(line['quantite']) ?? 0).toInt(),
              unitPrice: parseAmount(line['prix_unitaire']) ?? 0,
              color: line['couleur']?.toString(),
              size: line['taille']?.toString(),
            ),
          );
    }
    if (linesByOrder.isEmpty) return [];

    final orders = await _supabase
        .from('commandes')
        .select('id_commande, statut, date_commande, adresse_livraison')
        .inFilter('id_commande', linesByOrder.keys.toList())
        .order('date_commande', ascending: false);

    return [
      for (final order in orders)
        VendorOrder(
          id: order['id_commande'].toString(),
          status: OrderStatus.parse(order['statut']),
          date: order['date_commande']?.toString(),
          address: order['adresse_livraison']?.toString(),
          lines: linesByOrder[order['id_commande'].toString()] ?? const [],
        ),
    ];
  }

  Future<VendorSummary> fetchSummary() async {
    final shop = await fetchMyShop();
    final products = await fetchMyProducts();
    final orders = await fetchOrders();

    const countedStatuses = {
      OrderStatus.paid,
      OrderStatus.preparing,
      OrderStatus.ready,
      OrderStatus.shipping,
      OrderStatus.delivered,
    };
    final shopName = shop?['nom_boutique']?.toString().trim();
    return VendorSummary(
      shopName: shopName == null || shopName.isEmpty
          ? (_supabase.auth.currentUser?.userMetadata?['nom_commerce']
                    ?.toString() ??
                'Ma boutique')
          : shopName,
      productCount: products.length,
      stockCount: products.fold<int>(
        0,
        (sum, product) => sum + (parseAmount(product['stock']) ?? 0).toInt(),
      ),
      orderCount: orders
          .where((order) => order.status != OrderStatus.cancelled)
          .length,
      toPrepareCount: orders
          .where(
            (order) =>
                order.status == OrderStatus.paid ||
                order.status == OrderStatus.preparing,
          )
          .length,
      confirmedSales: orders
          .where((order) => countedStatuses.contains(order.status))
          .fold<num>(0, (sum, order) => sum + order.vendorTotal),
    );
  }
}
