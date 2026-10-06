import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/formatters.dart';

class ProductService {
  ProductService([SupabaseClient? client])
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  /// Catalogue complet, le plus récent d'abord. Le filtrage (catégorie,
  /// recherche) est fait localement : le catalogue reste de taille modeste.
  Future<List<Map<String, dynamic>>> fetchCatalog() async {
    final response = await _supabase
        .from('produits')
        .select()
        .order('date_ajout', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> fetchProduct(String productId) => _supabase
      .from('produits')
      .select()
      .eq('id_produit', productId)
      .maybeSingle();

  Future<List<Map<String, dynamic>>> fetchShopProducts(String shopId) async {
    final response = await _supabase
        .from('produits')
        .select()
        .eq('id_boutique', shopId)
        .order('date_ajout', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> fetchShop(String shopId) => _supabase
      .from('boutiques')
      .select()
      .eq('id_boutique', shopId)
      .maybeSingle();

  /// Ventes éphémères actives, en temps réel (les ventes expirées sont
  /// filtrées par l'appelant : le flux ne peut pas filtrer sur l'heure).
  Stream<List<Map<String, dynamic>>> watchActiveDeals() => _supabase
      .from('ventes_ephemeres')
      .stream(primaryKey: ['id_vente_ephemere'])
      .eq('statut', 'actif')
      .order('date_fin', ascending: true);

  Future<List<Map<String, dynamic>>> fetchProductsByIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return [];
    final response = await _supabase
        .from('produits')
        .select('id_produit, nom_produit, prix, image_url')
        .inFilter('id_produit', ids);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> createDeal({
    required String name,
    required String productId,
    required num promoPrice,
    required String saleType,
    required DateTime endsAt,
  }) => _supabase.from('ventes_ephemeres').insert({
    'nom_vente': name,
    'id_produit': productId,
    'prix_promo': promoPrice,
    'type_vente': saleType,
    'date_debut': DateTime.now().toUtc().toIso8601String(),
    'date_fin': endsAt.toUtc().toIso8601String(),
    'statut': 'actif',
  });

  /// Prix promo des ventes éphémères en cours, par produit.
  /// Même règle que la fonction SQL `current_unit_price` utilisée au paiement.
  Future<Map<String, num>> fetchActivePromos([List<String>? productIds]) async {
    if (productIds != null && productIds.isEmpty) return {};
    final now = DateTime.now().toUtc().toIso8601String();
    var query = _supabase
        .from('ventes_ephemeres')
        .select('id_produit, prix_promo, date_debut')
        .eq('statut', 'actif')
        .gt('date_fin', now);
    if (productIds != null) query = query.inFilter('id_produit', productIds);
    final rows = await query;

    final promos = <String, num>{};
    final nowDate = DateTime.now();
    for (final row in rows) {
      final start = DateTime.tryParse(row['date_debut']?.toString() ?? '');
      if (start != null && start.isAfter(nowDate)) continue;
      final id = row['id_produit']?.toString();
      final price = parseAmount(row['prix_promo']);
      if (id == null || price == null) continue;
      final current = promos[id];
      if (current == null || price < current) promos[id] = price;
    }
    return promos;
  }

  /// Prix à payer : le prix promo s'il est inférieur au prix catalogue.
  static num? effectivePrice(
    Map<String, dynamic> product,
    Map<String, num> promos,
  ) {
    final base = parseAmount(product['prix']);
    final promo = promos[product['id_produit']?.toString()];
    if (base == null) return promo;
    if (promo == null) return base;
    return promo < base ? promo : base;
  }
}
