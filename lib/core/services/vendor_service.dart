import 'dart:convert';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order_status.dart';
import '../utils/formatters.dart';

/// Résultat de l'enregistrement d'une photo produit.
class ProductPhotos {
  ProductPhotos({
    required this.imageUrl,
    required this.originalUrl,
    this.verticalUrl,
    required this.enhanced,
  });

  final String imageUrl;
  final String originalUrl;
  final String? verticalUrl;

  /// `false` si la retouche IA a échoué : la photo originale est utilisée.
  final bool enhanced;
}

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
    final variants = [
      color,
      size,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(', ');
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

  /// Envoie la photo d'origine puis, si demandé, la version retouchée par
  /// l'IA. Si la retouche échoue, la photo d'origine est utilisée.
  Future<ProductPhotos> uploadProductPhoto({
    required XFile file,
    required String productName,
    required String description,
    String? scene,
  }) async {
    const bucket = 'images';
    final storage = _supabase.storage.from(bucket);
    final bytes = await file.readAsBytes();
    final extension = file.name.split('.').last.toLowerCase();
    final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';
    final stem = '$_userId/${DateTime.now().millisecondsSinceEpoch}';

    final originalPath =
        'originals/$stem.${extension == 'png' ? 'png' : 'jpg'}';
    await storage.uploadBinary(
      originalPath,
      bytes,
      fileOptions: FileOptions(contentType: mimeType),
    );
    final originalUrl = storage.getPublicUrl(originalPath);
    if (scene == null) {
      return ProductPhotos(
        imageUrl: originalUrl,
        originalUrl: originalUrl,
        enhanced: false,
      );
    }

    try {
      final response = await _supabase.functions.invoke(
        'enhance-product-image',
        body: {
          'productName': productName,
          'description': description,
          'imageBase64': base64Encode(bytes),
          'mimeType': mimeType,
          'scene': scene,
        },
      );
      final data = response.data;
      final square = data is Map ? data['imageBase64'] : null;
      if (square is! String || square.isEmpty) throw Exception('Retouche vide');

      final squarePath = 'products/$stem.jpg';
      await storage.uploadBinary(
        squarePath,
        base64Decode(square),
        fileOptions: const FileOptions(contentType: 'image/jpeg'),
      );
      String? verticalUrl;
      final vertical = (data as Map)['imageVerticalBase64'];
      if (vertical is String && vertical.isNotEmpty) {
        final verticalPath = 'products/${stem}_story.jpg';
        await storage.uploadBinary(
          verticalPath,
          base64Decode(vertical),
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
        verticalUrl = storage.getPublicUrl(verticalPath);
      }
      return ProductPhotos(
        imageUrl: storage.getPublicUrl(squarePath),
        originalUrl: originalUrl,
        verticalUrl: verticalUrl,
        enhanced: true,
      );
    } catch (_) {
      return ProductPhotos(
        imageUrl: originalUrl,
        originalUrl: originalUrl,
        enhanced: false,
      );
    }
  }

  Future<void> saveProduct({
    String? productId,
    required Map<String, dynamic> values,
  }) async {
    if (productId == null) {
      final shop = await fetchMyShop();
      if (shop == null) {
        throw Exception('Crée d’abord ta boutique (onglet Ma boutique).');
      }
      await _supabase.from('produits').insert({
        ...values,
        'id_vendeur': _userId,
        'id_boutique': shop['id_boutique'],
        'date_ajout': DateTime.now().toUtc().toIso8601String(),
      });
    } else {
      await _supabase
          .from('produits')
          .update(values)
          .eq('id_produit', productId)
          .eq('id_vendeur', _userId);
    }
  }

  Future<void> deleteProduct(String productId) async {
    try {
      await _supabase
          .from('produits')
          .delete()
          .eq('id_produit', productId)
          .eq('id_vendeur', _userId);
    } on PostgrestException catch (error) {
      if (error.code == '23503') {
        throw Exception(
          'Ce produit figure dans des commandes : mets son stock à 0 pour le retirer de la vente.',
        );
      }
      rethrow;
    }
  }

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
        .select(
          'id_commande, id_produit, quantite, prix_unitaire, couleur, taille',
        )
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
