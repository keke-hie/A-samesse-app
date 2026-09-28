import 'package:supabase_flutter/supabase_flutter.dart';

class ProductService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Récupérer les produits avec filtrage optionnel par catégorie, recherche et tri par date
  Future<List<Map<String, dynamic>>> fetchProducts({
    String? category,
    String? searchQuery,
  }) async {
    try {
      var query = _supabase.from('produits').select('*');

      // Filtrer par catégorie (si ce n'est pas "Tous" et que ce n'est pas null)
      if (category != null && category != "Tous") {
        query = query.eq('categorie', category);
      }

      // Filtrer par recherche (insensible à la casse sur le nom du produit)
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.ilike('nom_produit', '%$searchQuery%');
      }

      // Appliquer le tri par date d'ajout à la fin et exécuter la requête
      final response = await query.order('date_ajout', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erreur lors de la récupération des produits : $e');
    }
  }
}