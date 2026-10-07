import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Campagnes marketing générées par l'IA (edge function `generate-marketing-copy`).
class MarketingService {
  MarketingService([SupabaseClient? client])
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  String get _userId {
    final id = _supabase.auth.currentUser?.id;
    if (id == null) throw Exception('Connecte-toi à ton espace vendeur.');
    return id;
  }

  Future<List<Map<String, dynamic>>> fetchCampaigns() async {
    final response = await _supabase
        .from('campagnes')
        .select(
          'id_campagne, nom_campagne, plateformes, contenus, statut, date_creation',
        )
        .eq('id_vendeur', _userId)
        .order('date_creation', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Photo de référence envoyée à l'IA (stockage public `images`).
  Future<String> uploadReferenceImage(XFile image) async {
    final extension = image.name.split('.').last.toLowerCase();
    final mimeType = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    final path =
        'marketing-input/$_userId/${DateTime.now().millisecondsSinceEpoch}.$extension';
    final storage = _supabase.storage.from('images');
    await storage.uploadBinary(
      path,
      await image.readAsBytes(),
      fileOptions: FileOptions(contentType: mimeType),
    );
    return storage.getPublicUrl(path);
  }

  /// Génère une publication par réseau. Les erreurs de la fonction remontent
  /// en `FunctionException` (message lisible via `friendlyError`).
  Future<List<Map<String, dynamic>>> generate({
    required String productName,
    required String description,
    required String price,
    required List<String> platforms,
    String? productImageUrl,
    String? creativeDirection,
    bool includeVisuals = false,
  }) async {
    final response = await _supabase.functions.invoke(
      'generate-marketing-copy',
      body: {
        'productName': productName,
        'description': description,
        'price': price,
        'platforms': platforms,
        'productImageUrl': ?productImageUrl,
        'creativeDirection': ?creativeDirection,
        'includeVisuals': includeVisuals,
      },
    );
    final data = response.data;
    final contents = data is Map ? data['contents'] : null;
    if (contents is! List || contents.isEmpty) {
      throw Exception('L’IA n’a renvoyé aucune publication. Réessaie.');
    }
    return contents.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  Future<void> saveDraft({
    required String name,
    required List<String> platforms,
    required List<Map<String, dynamic>> contents,
    Object? productId,
  }) => _supabase.from('campagnes').insert({
    'id_vendeur': _userId,
    'id_produit': productId,
    'nom_campagne': name,
    'plateformes': platforms,
    'contenus': contents,
    'statut': 'brouillon',
  });
}
