import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/formatters.dart';
import 'product_service.dart';

class CartSummary {
  const CartSummary({required this.itemCount, required this.total});

  static const empty = CartSummary(itemCount: 0, total: 0);

  final int itemCount;
  final num total;
}

class CartService {
  CartService([SupabaseClient? client])
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;
  late final _productService = ProductService(_supabase);

  String? get _userId => _supabase.auth.currentUser?.id;

  Future<String?> _findCartId() async {
    final userId = _userId;
    if (userId == null) return null;
    final cart = await _supabase
        .from('paniers')
        .select('id_panier')
        .eq('id_acheteur', userId)
        .maybeSingle();
    return cart?['id_panier']?.toString();
  }

  Future<String> _getOrCreateCartId() async {
    final existing = await _findCartId();
    if (existing != null) return existing;
    final created = await _supabase
        .from('paniers')
        .insert({
          'id_acheteur': _userId,
          'date_mise_a_jour': DateTime.now().toUtc().toIso8601String(),
        })
        .select('id_panier')
        .single();
    return created['id_panier'].toString();
  }

  /// Lignes du panier avec leur produit et le prix promo éventuel
  /// (`prix_effectif`), pour afficher le même total que celui facturé.
  Future<List<Map<String, dynamic>>> fetchItems() async {
    final cartId = await _findCartId();
    if (cartId == null) return [];
    final response = await _supabase
        .from('lignes_panier')
        .select('*, produits(*)')
        .eq('id_panier', cartId)
        .order('id_ligne');
    final items = List<Map<String, dynamic>>.from(response);
    final promos = await _productService.fetchActivePromos([
      for (final item in items)
        if (item['id_produit'] != null) item['id_produit'].toString(),
    ]);
    return [
      for (final item in items)
        {
          ...item,
          'prix_effectif': ProductService.effectivePrice(
            item['produits'] as Map<String, dynamic>? ?? {},
            promos,
          ),
        },
    ];
  }

  Future<CartSummary> fetchSummary() async {
    if (_userId == null) return CartSummary.empty;
    final items = await fetchItems();
    var count = 0;
    num total = 0;
    for (final item in items) {
      final quantity = (parseAmount(item['quantite']) ?? 1).toInt();
      count += quantity;
      total += (parseAmount(item['prix_effectif']) ?? 0) * quantity;
    }
    return CartSummary(itemCount: count, total: total);
  }

  /// Ajoute un article ; si la même variante est déjà au panier, la quantité
  /// est augmentée au lieu de créer une deuxième ligne.
  Future<void> addItem({
    required String productId,
    required int quantity,
    String color = '',
    String size = '',
    int? stock,
  }) async {
    final cartId = await _getOrCreateCartId();
    final existing = await _supabase
        .from('lignes_panier')
        .select('id_ligne, quantite')
        .eq('id_panier', cartId)
        .eq('id_produit', productId)
        .eq('couleur', color)
        .eq('taille', size)
        .maybeSingle();

    if (existing == null) {
      await _supabase.from('lignes_panier').insert({
        'id_panier': cartId,
        'id_produit': productId,
        'quantite': quantity,
        'couleur': color,
        'taille': size,
      });
    } else {
      final newQuantity = (parseAmount(existing['quantite']) ?? 0).toInt() + quantity;
      if (stock != null && newQuantity > stock) {
        throw Exception(
          'Tu as déjà cet article au panier : il n’en reste que $stock en stock.',
        );
      }
      await _supabase
          .from('lignes_panier')
          .update({'quantite': newQuantity})
          .eq('id_ligne', existing['id_ligne']);
    }

    await _supabase
        .from('paniers')
        .update({'date_mise_a_jour': DateTime.now().toUtc().toIso8601String()})
        .eq('id_panier', cartId);
  }

  Future<void> setQuantity(String lineId, int quantity) async {
    if (quantity <= 0) {
      await _supabase.from('lignes_panier').delete().eq('id_ligne', lineId);
    } else {
      await _supabase
          .from('lignes_panier')
          .update({'quantite': quantity})
          .eq('id_ligne', lineId);
    }
  }

  Future<void> removeLines(Iterable<String> lineIds) async {
    if (lineIds.isEmpty) return;
    await _supabase
        .from('lignes_panier')
        .delete()
        .inFilter('id_ligne', lineIds.toList());
  }
}
