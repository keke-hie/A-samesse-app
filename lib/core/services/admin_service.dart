import 'package:supabase_flutter/supabase_flutter.dart';

class AdminService {
  AdminService([SupabaseClient? client])
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<List<Map<String, dynamic>>> listUsers() async {
    final response = await _supabase.rpc('admin_list_utilisateurs');
    return List<Map<String, dynamic>>.from(response as List);
  }

  Future<void> setAccountStatus({
    required String userId,
    required String status,
    String? reason,
  }) => _supabase.rpc(
    'admin_set_account_status',
    params: {'p_id_utilisateur': userId, 'p_statut': status, 'p_motif': reason},
  );

  Future<List<Map<String, dynamic>>> listDisputes() async {
    final response = await _supabase
        .from('litiges')
        .select(
          'id_litige, id_commande, id_acheteur, motif, description, statut_litige, date_creation, decision_admin',
        )
        .order('date_creation', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> decideDispute({
    required String disputeId,
    required String status,
    required String decision,
  }) => _supabase
      .from('litiges')
      .update({
        'statut_litige': status,
        'decision_admin': decision,
        'id_administrateur': _supabase.auth.currentUser?.id,
        'date_resolution': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id_litige', disputeId);
}
