import 'package:supabase_flutter/supabase_flutter.dart';

/// Toutes les écritures sur les commandes passent par des fonctions SQL
/// (prix recalculés côté serveur, opérations atomiques).
class OrderService {
  OrderService([SupabaseClient? client])
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  /// Frais affichés côté client ; le montant facturé est recalculé par `create_order`.
  static const expressDeliveryFee = 1500;

  Future<String> createOrder({
    required List<String> cartLineIds,
    required String paymentMethod,
    required String deliveryMode,
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    final id = await _supabase.rpc(
      'create_order',
      params: {
        'p_line_ids': cartLineIds,
        'p_mode_paiement': paymentMethod,
        'p_mode_livraison': deliveryMode,
        'p_adresse': address,
        'p_latitude': latitude,
        'p_longitude': longitude,
      },
    );
    return id.toString();
  }

  Future<void> cancelOrder(String orderId) =>
      _supabase.rpc('cancel_order', params: {'p_id_commande': orderId});

  /// Paiement simulé (démo) : passe la commande à « payee » et renvoie la
  /// référence de transaction fictive.
  Future<String> simulatePayment(String orderId, String paymentMethod) async {
    final reference = await _supabase.rpc(
      'simulate_payment',
      params: {'p_id_commande': orderId, 'p_mode_paiement': paymentMethod},
    );
    return reference.toString();
  }

  Future<Map<String, dynamic>?> fetchOrder(String orderId) => _supabase
      .from('commandes')
      .select()
      .eq('id_commande', orderId)
      .maybeSingle();

  Future<void> vendorAdvance(String orderId, String nextStatus) =>
      _supabase.rpc(
        'vendor_advance_order',
        params: {'p_id_commande': orderId, 'p_statut': nextStatus},
      );

  Future<List<Map<String, dynamic>>> adminListOrders() async {
    final response = await _supabase.rpc('admin_list_orders');
    return List<Map<String, dynamic>>.from(response as List);
  }

  Stream<List<Map<String, dynamic>>> watchMyOrders(String userId) => _supabase
      .from('commandes')
      .stream(primaryKey: ['id_commande'])
      .eq('id_acheteur', userId)
      .order('date_commande', ascending: false);

  Future<List<Map<String, dynamic>>> fetchOrderLines(String orderId) async {
    final response = await _supabase
        .from('lignes_commande')
        .select('*, produits(nom_produit, image_url)')
        .eq('id_commande', orderId);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> openDispute({
    required String orderId,
    required String reason,
    required String description,
  }) => _supabase.from('litiges').insert({
    'id_commande': orderId,
    'id_acheteur': _supabase.auth.currentUser?.id,
    'motif': reason,
    'description': description,
  });

  Future<String?> fetchDeliveryCode(String orderId) async {
    final response = await _supabase
        .from('delivery_otps')
        .select('code_otp')
        .eq('id_commande', orderId)
        .maybeSingle();
    return response?['code_otp']?.toString();
  }
}
