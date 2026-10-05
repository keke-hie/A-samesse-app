import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_color.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic>? product;

  const ProductDetailScreen({super.key, this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantite = 1;
  String? _selectedColor;
  String? _selectedSize;
  bool _isFavorite = false;
  bool _isAddingToCart = false;

  List<String> _readOptions(String key) {
    final value = widget.product?[key];
    if (value is Iterable) {
      return value.map((item) => item.toString().trim()).where((item) => item.isNotEmpty).toList();
    }
    if (value is String) {
      return value.split(RegExp(r'[,;\n]')).map((item) => item.trim()).where((item) => item.isNotEmpty).toList();
    }
    return const [];
  }

  double? _getRawPrice() {
    final raw = widget.product?['prix'];
    if (raw is num) return raw.toDouble();
    return raw == null ? null : double.tryParse(raw.toString());
  }

  int? _getStock() {
    final raw = widget.product?['stock'];
    if (raw is num) return raw.toInt();
    return raw == null ? null : int.tryParse(raw.toString());
  }

  String _formatPrice(num val) {
    final digits = val.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return '${buffer.toString()} FCFA';
  }

  Widget _buildHeroImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.trim().isEmpty) return _productImagePlaceholder();
    if (imageUrl.startsWith('assets/')) {
      return Image.asset(imageUrl, fit: BoxFit.contain, width: double.infinity, height: double.infinity,
          errorBuilder: (_, _, _) => _productImagePlaceholder());
    }
    return Image.network(
      imageUrl,
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, _, _) => _productImagePlaceholder(),
    );
  }

  Widget _productImagePlaceholder() {
    return const ColoredBox(
      color: AppColor.primarySoft,
      child: Center(child: Icon(Icons.image_not_supported_outlined, size: 42, color: AppColor.primary)),
    );
  }

  Color _colorForName(String name) {
    final value = name.toLowerCase();
    if (value.startsWith('#') && (value.length == 7 || value.length == 9)) {
      final parsed = int.tryParse(value.substring(1), radix: 16);
      if (parsed != null) return Color(value.length == 7 ? 0xFF000000 | parsed : parsed);
    }
    if (value.contains('noir') || value.contains('black')) return const Color(0xFF222222);
    if (value.contains('blanc') || value.contains('white')) return Colors.white;
    if (value.contains('rouge') || value.contains('red')) return const Color(0xFFB8444E);
    if (value.contains('bleu') || value.contains('blue')) return const Color(0xFF5582B1);
    if (value.contains('vert') || value.contains('green')) return const Color(0xFF6F9A78);
    if (value.contains('jaune') || value.contains('yellow')) return const Color(0xFFD8B94C);
    if (value.contains('rose') || value.contains('pink')) return const Color(0xFFE9A3AA);
    if (value.contains('beige') || value.contains('cream')) return const Color(0xFFD8C6AB);
    return AppColor.primarySoft;
  }

  Future<void> _addToCart() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Connectez-vous pour ajouter au panier.'),
          backgroundColor: AppColor.textPrimary,
          action: SnackBarAction(
            label: 'Connexion',
            textColor: AppColor.primarySoft,
            onPressed: () => context.go('/login'),
          ),
        ),
      );
      return;
    }

    setState(() => _isAddingToCart = true);

    try {
      final idProduit = widget.product?['id_produit'];
      if (idProduit == null) {
        throw Exception('Identifiant du produit manquant. Ouvrez un produit chargé depuis la boutique.');
      }
      final colors = _readOptions('couleurs');
      final sizes = _readOptions('tailles');
      if (colors.isNotEmpty && _selectedColor == null) {
        throw Exception('Choisis une couleur avant de continuer.');
      }
      if (sizes.isNotEmpty && _selectedSize == null) {
        throw Exception('Choisis une taille ou un modèle avant de continuer.');
      }
      final nom = widget.product?['nom_produit'] ?? 'Produit';

      var panierResponse = await supabase
          .from('paniers')
          .select('id_panier')
          .eq('id_acheteur', user.id)
          .maybeSingle();

      dynamic idPanier;
      if (panierResponse == null) {
        final newPanier = await supabase
            .from('paniers')
            .insert({
              'id_acheteur': user.id,
              'date_mise_a_jour': DateTime.now().toIso8601String(),
            })
            .select('id_panier')
            .single();
        idPanier = newPanier['id_panier'];
      } else {
        idPanier = panierResponse['id_panier'];
        await supabase
            .from('paniers')
            .update({'date_mise_a_jour': DateTime.now().toIso8601String()})
            .eq('id_panier', idPanier);
      }

      await supabase.from('lignes_panier').insert({
        'id_panier': idPanier,
        'id_produit': idProduit,
        'quantite': _quantite,
        'couleur': _selectedColor ?? '',
        'taille': _selectedSize ?? '',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColor.textPrimary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text("'$nom' ajouté au panier (x$_quantite)."),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'Voir panier',
              textColor: AppColor.primarySoft,
              onPressed: () => context.go('/cart', extra: widget.product),
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ajout au panier impossible : $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingToCart = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    if (product == null) {
      return Scaffold(
        backgroundColor: AppColor.background,
        appBar: AppBar(title: const Text("A'samesse")),
        body: const Center(child: Text('Ce produit n’est plus disponible.')),
      );
    }

    final nom = product['nom_produit']?.toString() ?? 'Produit';
    final rawUnitPrice = _getRawPrice();
    final totalPrice = rawUnitPrice == null ? null : rawUnitPrice * _quantite;
    final imageUrl = (product['image_url'] ?? product['images'])?.toString();
    final stock = _getStock();
    final colors = _readOptions('couleurs');
    final sizes = _readOptions('tailles');
    final features = _readOptions('caracteristiques');
    final description = product['description']?.toString().trim() ?? '';

    return Scaffold(
      backgroundColor: AppColor.background, // Exact rose poudré #F9EAE5
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColor.textPrimary, size: 24),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/home');
            }
          },
        ),
        title: const Text(
          "A'samesse",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.4,
            color: AppColor.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: _isFavorite ? AppColor.primary : AppColor.textPrimary,
              size: 22,
            ),
            onPressed: () {
              setState(() => _isFavorite = !_isFavorite);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Zone Hero Image avec Bouton Play flottant
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // Image du produit
                  Container(
                    height: 320,
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: SizedBox.expand(child: _buildHeroImage(imageUrl)),
                        ),
                        Positioned(
                          bottom: 34,
                          right: 14,
                          child: _isFavorite
                              ? const Icon(Icons.favorite, color: AppColor.primary)
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),

                  // 2. Fiche Détail Blanche avec Bords Arrondis Supérieurs (Image 4)
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (stock != null)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: stock > 0 ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                stock > 0 ? 'En stock : $stock' : 'Rupture de stock',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: stock > 0 ? const Color(0xFF2E7D32) : Colors.red,
                                ),
                              ),
                            ),
                          ),

                        const SizedBox(height: 12),

                        // Titre & Prix Unitaire
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                nom,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                  color: AppColor.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              rawUnitPrice == null ? 'Prix non renseigné' : _formatPrice(rawUnitPrice),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColor.primary,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        if (colors.isNotEmpty) ...[
                          const Text('Couleur', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            children: colors.map((colorName) {
                              final isSelected = _selectedColor == colorName;
                              return Semantics(
                                button: true,
                                selected: isSelected,
                                label: colorName,
                                child: GestureDetector(
                                  onTap: () => setState(() => _selectedColor = colorName),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSelected ? AppColor.primary : Colors.transparent,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Container(
                                          width: 30,
                                          height: 30,
                                          decoration: BoxDecoration(
                                            color: _colorForName(colorName),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: AppColor.border),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(colorName, style: const TextStyle(fontSize: 10)),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 18),
                        ],
                        if (sizes.isNotEmpty) ...[
                          const Text('Taille / modèle', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 9),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: sizes.map((size) {
                              final isSelected = _selectedSize == size;
                              return ChoiceChip(
                                label: Text(size),
                                selected: isSelected,
                                showCheckmark: false,
                                selectedColor: AppColor.primary,
                                backgroundColor: Colors.white,
                                side: BorderSide(color: isSelected ? AppColor.primary : AppColor.border),
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : AppColor.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                                onSelected: (_) => setState(() => _selectedSize = size),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 18),
                        ],

                        // 5. Sélecteur de Quantité (Ajouter / Réduire)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9F7F5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Quantité",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColor.textPrimary,
                                ),
                              ),
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: _quantite > 1
                                        ? () => setState(() => _quantite--)
                                        : null,
                                    child: Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.05),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.remove_rounded,
                                        size: 18,
                                        color: _quantite > 1 ? AppColor.textPrimary : Colors.grey.shade400,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      "$_quantite",
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColor.textPrimary,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: stock == null || _quantite < stock
                                        ? () => setState(() => _quantite++)
                                        : null,
                                    child: Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: stock == null || _quantite < stock ? AppColor.primary : Colors.grey,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColor.primary.withValues(alpha: 0.25),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.add_rounded,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Paragraphe descriptif
                        const Text('Description', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 7),
                        Text(
                          description.isEmpty ? 'Aucune description renseignée pour ce produit.' : description,
                          style: const TextStyle(fontSize: 13, height: 1.5, color: AppColor.textSecondary),
                        ),
                        if (features.isNotEmpty) ...[
                          const SizedBox(height: 22),
                          const Text('Caractéristiques', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 9),
                          ...features.map((feature) => Padding(
                                padding: const EdgeInsets.only(bottom: 7),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.check_circle_outline, size: 17, color: AppColor.primary),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(feature, style: const TextStyle(fontSize: 13, color: AppColor.textSecondary))),
                                  ],
                                ),
                              )),
                        ],

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Barre Fixe Inférieure : Prix Total Dynamique + Bouton Ajouter au Panier
          Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Colonne Prix Total calculé
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Total ($_quantite art.)",
                      style: const TextStyle(fontSize: 11, color: Color(0xFF757575), fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      totalPrice == null ? 'Prix indisponible' : _formatPrice(totalPrice),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColor.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),

                // Bouton pilule bordeaux Add to cart 🛍️
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                        onPressed: _isAddingToCart || rawUnitPrice == null || (stock != null && stock <= 0)
                          ? null
                          : _addToCart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColor.primary, // Exact bordeaux #8B2635
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      child: _isAddingToCart
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Ajouter au panier",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.shopping_bag_outlined, size: 18),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}