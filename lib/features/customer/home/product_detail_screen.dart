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
  int _selectedColorIndex = 0;
  int _selectedSizeIndex = 0;
  bool _isFavorite = false;
  bool _isAddingToCart = false;

  final List<Map<String, dynamic>> _availableColors = [
    {"name": "Rose Corail", "color": const Color(0xFFD67373)},
    {"name": "Noir Minuit", "color": const Color(0xFF1E1E1E)},
    {"name": "Blanc Pur", "color": const Color(0xFFFFFFFF)},
    {"name": "Vert Sauge", "color": const Color(0xFFC1DEC6)},
    {"name": "Champagne", "color": const Color(0xFFD8CCC5)},
  ];

  final List<String> _availableSizes = ['Standard', 'S', 'M', 'L', 'XL'];

  final List<Map<String, dynamic>> _setupAccessories = [
    {
      "name": "MagStand",
      "price": "\$79.00",
      "image": "assets/images/magstand.jpg",
    },
    {
      "name": "Smart Speaker",
      "price": "\$359.00",
      "image": "assets/images/smart_speaker.jpg",
    },
    {
      "name": "AirPods Pro",
      "price": "\$499.00",
      "image": "assets/images/airpods_pro.jpg",
    },
  ];

  double _getRawPrice() {
    final raw = widget.product?['prix'] ?? 499.0;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString()) ?? 499.0;
  }

  String _formatPrice(num val) {
    if (val > 1000) {
      final str = val.toStringAsFixed(0);
      final buffer = StringBuffer();
      for (int i = 0; i < str.length; i++) {
        if (i > 0 && (str.length - i) % 3 == 0) buffer.write(' ');
        buffer.write(str[i]);
      }
      return "${buffer.toString()} FCFA";
    }
    return "\$${val.toStringAsFixed(2)}";
  }

  Widget _buildHeroImage(String? imageUrl, String nom) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      if (imageUrl.startsWith('assets/')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(imageUrl, fit: BoxFit.contain, height: 210),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.network(
          imageUrl,
          fit: BoxFit.contain,
          height: 210,
          errorBuilder: (_, _, _) => _fallbackHeroImage(nom),
        ),
      );
    }
    return _fallbackHeroImage(nom);
  }

  Widget _fallbackHeroImage(String nom) {
    final lower = nom.toLowerCase();
    String assetPath = 'assets/images/headphones_coral.jpg';
    if (lower.contains('speaker')) {
      assetPath = 'assets/images/smart_speaker.jpg';
    } else if (lower.contains('airpod')) {
      assetPath = 'assets/images/airpods_pro.jpg';
    } else if (lower.contains('earphone')) {
      assetPath = 'assets/images/earphones.jpg';
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Image.asset(assetPath, fit: BoxFit.contain, height: 210),
    );
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
      final idProduit = widget.product?['id'] ?? widget.product?['id_produit'] ?? '1';
      final nom = widget.product?['nom_produit'] ?? 'Produit';
      final selectedColorName = _availableColors[_selectedColorIndex]['name'];
      final selectedSize = _availableSizes[_selectedSizeIndex];

      var panierResponse = await supabase
          .from('paniers')
          .select('id_panier')
          .eq('id_acheteur', user.id)
          .maybeSingle();

      int idPanier;
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
        'couleur': selectedColorName,
        'taille': selectedSize,
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
                  child: Text("'$nom' (x$_quantite, $selectedColorName) ajouté au panier !"),
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$_quantite article(s) ajouté(s) au panier')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingToCart = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nom = widget.product?['nom_produit'] ?? 'Elite Series X1';
    final rawUnitPrice = _getRawPrice();
    final totalPrice = rawUnitPrice * _quantite;
    final prixFormatted = _formatPrice(rawUnitPrice);
    final String? imageUrl = widget.product?['images'] ?? widget.product?['image_url'];
    final int stock = (widget.product?['stock'] is num)
        ? (widget.product?['stock'] as num).toInt()
        : int.tryParse(widget.product?['stock']?.toString() ?? '15') ?? 15;

    final description = widget.product?['description'] ??
        "A mesh textile wraps the ear cushions to provide pillow-like softness. Engineered for pure sonic immersion with active noise cancellation and spatial audio transparency.";

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
                    height: 230,
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Center(
                          child: _buildHeroImage(imageUrl, nom),
                        ),
                        // Bouton Play circulaire bordeaux en bas à droite de l'image
                        Positioned(
                          bottom: 12,
                          right: 16,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColor.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColor.primary.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
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
                    padding: const EdgeInsets.fromLTRB(26, 24, 26, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avis étoilés & Statut Stock
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.star_outline_rounded, size: 15, color: AppColor.primary),
                                const SizedBox(width: 4),
                                Text(
                                  "4.9 (120 reviews)",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColor.primary,
                                  ),
                                ),
                              ],
                            ),
                            // Indicateur de stock
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: stock > 0
                                    ? const Color(0xFFE8F5E9)
                                    : const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    stock > 0 ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                    size: 13,
                                    color: stock > 0 ? const Color(0xFF2E7D32) : Colors.red,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    stock > 0 ? "En stock : $stock unités" : "Rupture de stock",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: stock > 0 ? const Color(0xFF2E7D32) : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                              prixFormatted,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColor.primary,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // 3. Sélecteur de couleur (Choisir couleur disponible)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Select Color",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColor.textPrimary,
                              ),
                            ),
                            Text(
                              _availableColors[_selectedColorIndex]['name'],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColor.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: List.generate(_availableColors.length, (index) {
                            final isSelected = _selectedColorIndex == index;
                            final colorItem = _availableColors[index];
                            final Color color = colorItem['color'] as Color;

                            return GestureDetector(
                              onTap: () {
                                setState(() => _selectedColorIndex = index);
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? AppColor.primary : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: color == Colors.white
                                        ? Border.all(color: Colors.grey.shade300)
                                        : null,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.08),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),

                        const SizedBox(height: 20),

                        // 4. Sélecteur de Taille (Choisir taille disponible)
                        const Text(
                          "Taille / Modèle",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColor.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          children: List.generate(_availableSizes.length, (index) {
                            final isSelected = _selectedSizeIndex == index;
                            final size = _availableSizes[index];

                            return GestureDetector(
                              onTap: () {
                                setState(() => _selectedSizeIndex = index);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColor.primary : const Color(0xFFF7F7F7),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? AppColor.primary : Colors.transparent,
                                  ),
                                ),
                                child: Text(
                                  size,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? Colors.white : AppColor.textPrimary,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),

                        const SizedBox(height: 20),

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
                                    onTap: () => setState(() => _quantite++),
                                    child: Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: AppColor.primary,
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
                        Text(
                          description,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: Color(0xFF6E6E6E),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Badges Fonctionnalités (40 Hours Battery Life / Lossless Audio Quality)
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFCEEE9),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.battery_charging_full_rounded,
                                      color: AppColor.primary,
                                      size: 20,
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                      "40 Hours\nBattery Life",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        height: 1.25,
                                        color: AppColor.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4F4F4),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.graphic_eq_rounded,
                                      color: AppColor.primary,
                                      size: 20,
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                      "Lossless\nAudio Quality",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        height: 1.25,
                                        color: AppColor.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // Section Complete the Setup avec les vraies images studio
                        const Text(
                          "Complete the Setup",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                            color: AppColor.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 80,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _setupAccessories.length,
                            itemBuilder: (context, index) {
                              final item = _setupAccessories[index];
                              return Container(
                                width: 175,
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9F7F5),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.asset(
                                          item['image'] as String,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            item['name'],
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: AppColor.textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            item['price'],
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              color: AppColor.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),

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
                      _formatPrice(totalPrice),
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
                      onPressed: _isAddingToCart ? null : _addToCart,
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