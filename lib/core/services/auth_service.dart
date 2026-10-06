import 'package:supabase_flutter/supabase_flutter.dart';

import 'session_service.dart';

/// Connexion, inscription et réinitialisation du mot de passe.
/// Après connexion, le profil est rechargé pour que le routeur connaisse le rôle.
class AuthService {
  AuthService([SupabaseClient? client])
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<void> signIn({required String email, required String password}) async {
    await _supabase.auth.signInWithPassword(email: email, password: password);
    await SessionService.instance.refresh();
  }

  /// Renvoie `true` si une session est ouverte, `false` si l'email doit
  /// d'abord être confirmé.
  Future<bool> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> metadata,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: metadata,
    );
    if (response.session == null) return false;
    await SessionService.instance.refresh();
    return true;
  }

  Future<void> sendPasswordReset(String email) =>
      _supabase.auth.resetPasswordForEmail(email);
}
