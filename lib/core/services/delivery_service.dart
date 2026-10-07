import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Statut d'une livraison vu par le livreur.
enum DeliveryStage { available, assigned, inProgress, delivered, cancelled }

DeliveryStage deliveryStageOf(Map<String, dynamic> delivery) {
  final status = (delivery['statut_livraison'] ?? '')
      .toString()
      .toLowerCase()
      .trim();
  if (status == 'disponible') return DeliveryStage.available;
  if (status.startsWith('livr') ||
      status.startsWith('termin') ||
      status == 'delivered') {
    return DeliveryStage.delivered;
  }
  if (status.startsWith('annul') || status.startsWith('refus')) {
    return DeliveryStage.cancelled;
  }
  if (status.contains('cours') || status.contains('route')) {
    return DeliveryStage.inProgress;
  }
  return DeliveryStage.assigned;
}

/// Accès aux livraisons : fonctions SQL côté livreur et flux temps réel
/// pour le suivi (`positions_livreurs`).
class DeliveryService {
  DeliveryService([SupabaseClient? client])
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<List<Map<String, dynamic>>> listAssigned() async {
    final response = await _supabase.rpc('courier_list_assigned_deliveries');
    return List<Map<String, dynamic>>.from(response as List);
  }

  /// Livraisons prêtes que personne n'a encore prises (vide si le compte
  /// livreur n'est pas validé).
  Future<List<Map<String, dynamic>>> listAvailable() async {
    final response = await _supabase.rpc('courier_list_available_deliveries');
    return List<Map<String, dynamic>>.from(response as List);
  }

  Future<void> claim(String deliveryId) => _supabase.rpc(
    'courier_claim_delivery',
    params: {'p_id_livraison': deliveryId},
  );

  Future<void> accept(String deliveryId) => _supabase.rpc(
    'accept_assigned_delivery',
    params: {'p_id_livraison': deliveryId},
  );

  Future<void> decline(String deliveryId) => _supabase.rpc(
    'decline_assigned_delivery',
    params: {'p_id_livraison': deliveryId},
  );

  /// Valide la remise avec le code du client ; `false` si le code est faux.
  Future<bool> confirmWithCode(String deliveryId, String code) async {
    final verified = await _supabase.rpc(
      'verify_delivery_otp',
      params: {'p_id_livraison': deliveryId, 'p_code': code},
    );
    return verified == true;
  }

  Stream<List<Map<String, dynamic>>> watchMyDeliveries(String courierId) =>
      _supabase
          .from('livraisons')
          .stream(primaryKey: ['id_livraison'])
          .eq('id_livreur', courierId);

  Stream<Map<String, dynamic>?> watchDeliveryForOrder(String orderId) =>
      _supabase
          .from('livraisons')
          .stream(primaryKey: ['id_livraison'])
          .eq('id_commande', orderId)
          .map((rows) => rows.isEmpty ? null : rows.first);

  Stream<LatLng?> watchCourierPosition(String deliveryId) => _supabase
      .from('positions_livreurs')
      .stream(primaryKey: ['id_livraison'])
      .eq('id_livraison', deliveryId)
      .map((rows) {
        if (rows.isEmpty) return null;
        final latitude = rows.first['latitude'];
        final longitude = rows.first['longitude'];
        return latitude is num && longitude is num
            ? LatLng(latitude.toDouble(), longitude.toDouble())
            : null;
      });

  Future<void> publishPosition({
    required String deliveryId,
    required String courierId,
    required double latitude,
    required double longitude,
  }) => _supabase.from('positions_livreurs').upsert({
    'id_livraison': deliveryId,
    'id_livreur': courierId,
    'latitude': latitude,
    'longitude': longitude,
    'date_position': DateTime.now().toUtc().toIso8601String(),
  }, onConflict: 'id_livraison');
}
