import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Traduit une exception technique en message lisible par l'utilisateur.
///
/// Les erreurs levées par nos fonctions SQL (`raise exception '...'`) sont déjà
/// rédigées pour l'utilisateur : on les affiche telles quelles.
String friendlyError(Object error) {
  // SocketException (mobile) / ClientException (web) : pas de dart:io pour rester compatible web.
  final type = error.runtimeType.toString();
  if (error is TimeoutException ||
      type.contains('SocketException') ||
      type.contains('ClientException')) {
    return 'Connexion internet indisponible. Vérifie ton réseau et réessaie.';
  }
  if (error is AuthException) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login')) {
      return 'Email ou mot de passe incorrect.';
    }
    if (message.contains('email not confirmed')) {
      return 'Confirme ton adresse email avant de te connecter.';
    }
    if (message.contains('already registered')) {
      return 'Un compte existe déjà avec cette adresse email.';
    }
    if (message.contains('password')) {
      return 'Le mot de passe doit contenir au moins 6 caractères.';
    }
    return error.message;
  }
  if (error is PostgrestException) {
    // P0001 = raise exception, 22023/42501 = codes utilisés par nos fonctions.
    if (const {'P0001', '22023', '42501'}.contains(error.code)) {
      return error.message;
    }
    return 'Le serveur n’a pas pu traiter la demande. Réessaie dans un instant.';
  }
  if (error is FunctionException) {
    final details = error.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    return 'Le service est momentanément indisponible.';
  }
  if (error is StorageException) {
    return 'L’envoi du fichier a échoué. Réessaie avec une image plus légère.';
  }
  final text = error.toString();
  if (text.startsWith('Exception: ')) return text.substring(11);
  return 'Une erreur est survenue. Réessaie.';
}
