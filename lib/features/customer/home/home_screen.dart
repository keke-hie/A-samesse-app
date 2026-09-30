import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_color.dart';
import '../../../core/services/product_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ProductService _productService = ProductService();
  final TextEditingController _searchController = TextEditingController();
  final _supabase = Supabase.instance.client;

  int _selectedCategoryIndex = 0;
  final List<Map<String, dynamic>> _categories = [
    {"label": "All", "category": null},
    {"label": "Headphones", "category": "Electronique"},
    {"label": "Speakers", "category": "Electronique"},
    {"label": "Mode", "category": "Mode"},
    {"label": "Beauté", "category": "Beaute"},
  ];

  String _searchQuery = "";
  String? _userName;
  bool _showAllProductsGrid = false;

  // Products state
  List<Map<String, dynamic>> _products = [];
  bool _isLoadingProducts = true;

  // Cart summary for the floating pill
  int _cartItemCount = 2;
  double _cartTotal = 1080.00;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _fetchUserProfile();
    _fetchCartSummary();
  }

  Future<void> _loadProducts() async {
    final String? selectedCategory =
        _categories[_selectedCategoryIndex]["category"] as String?;

    try {
      final fetched = await _productService
          .fetchProducts(
            category: selectedCategory,
            searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
          )
          .timeout(const Duration(seconds: 3));

      if (mounted) {
        setState(() {
          _products = fetched.isNotEmpty ? fetched : _getMockProducts();
          _isLoadingProducts = false;
        });
      }
    } catch (_) {
      // En cas d'erreur ou timeout, afficher immédiatement les produits vitrine haute définition
      if (mounted) {
        setState(() {
          _products = _getMockProducts();
          _isLoadingProducts = false;
        });
      }
    }
  }

  Future<void> _fetchUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final response = await _supabase
            .from('utilisateurs')
            .select('nom')
            .eq('id_utilisateur', user.id)
            .maybeSingle()
            .timeout(const Duration(seconds: 3));

        if (response != null && mounted) {
          setState(() {
            _userName = response['nom'];
          });
        } else {
          final metadataName = user.userMetadata?['nom'] ?? user.userMetadata?['name'];
          if (mounted) {
            setState(() {
              _userName = metadataName;
            });
          }
        }
      }
    } catch (_) {
      // Ignorer silencieusement pour ne pas bloquer l'UI
    }
  }

  Future<void> _fetchCartSummary() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final panier = await _supabase
          .from('paniers')
          .select('id_panier')
          .eq('id_acheteur', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 3));

      if (panier != null) {
        final lines = await _supabase
            .from('lignes_panier')
            .select('quantite, produits(prix)')
            .eq('id_panier', panier['id_panier'])
            .timeout(const Duration(seconds: 3));

        int totalCount = 0;
        double totalPrice = 0;
        for (var line in lines) {
          final q = (line['quantite'] ?? 1) as int;
          totalCount += q;
          final prod = line['produits'];
          if (prod != null) {
            final p = (prod['prix'] is num)
                ? (prod['prix'] as num).toDouble()
                : (double.tryParse(prod['prix'].toString()) ?? 0.0);
            totalPrice += p * q;
          }
        }

        if (mounted && totalCount > 0) {
          setState(() {
            _cartItemCount = totalCount;
            _cartTotal = totalPrice;
          });
        }
      }
    } catch (_) {
      // Garder les valeurs d'exemple de la maquette
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatPrice(dynamic raw) {
    if (raw == null) return "\$499.00";
    final num? val = raw is num ? raw : num.tryParse(raw.toString());
    if (val == null) return "$raw";
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

  Future<void> _addProductToCart(Map<String, dynamic> product, {int quantity = 1}) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Connectez-vous pour ajouter un article au panier.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColor.textPrimary,
            action: SnackBarAction(
              label: 'Connexion',
              textColor: AppColor.primarySoft,
              onPressed: () => context.go('/login'),
            ),
          ),
        );
      }
      return;
    }

    try {
      final productId = product['id_produit'];
      if (productId == null) {
        throw Exception('Identifiant du produit manquant.');
      }

      var panier = await supabase
          .from('paniers')
          .select('id_panier')
          .eq('id_acheteur', user.id)
          .maybeSingle();

      dynamic idPanier;
      if (panier == null) {
        final inserted = await supabase
            .from('paniers')
            .insert({'id_acheteur': user.id, 'date_mise_a_jour': DateTime.now().toIso8601String()})
            .select('id_panier')
            .single();
        idPanier = inserted['id_panier'];
      } else {
        idPanier = panier['id_panier'];
      }

      final existingLine = await supabase
          .from('lignes_panier')
          .select('id_ligne, quantite')
          .eq('id_panier', idPanier)
          .eq('id_produit', productId)
          .maybeSingle();

      if (existingLine != null) {
        final currentQty = (existingLine['quantite'] ?? 0) as int;
        await supabase
            .from('lignes_panier')
            .update({'quantite': currentQty + quantity})
            .eq('id_ligne', existingLine['id_ligne']);
      } else {
        await supabase.from('lignes_panier').insert({
          'id_panier': idPanier,
          'id_produit': productId,
          'quantite': quantity,
        });
      }

      if (mounted) {
        setState(() {
          _cartItemCount += quantity;
          _cartTotal += unitPrice * quantity;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product['nom_produit'] ?? 'Produit'} ajouté au panier'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColor.textPrimary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ajout au panier impossible : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayProducts = _products.isNotEmpty ? _products : _getMockProducts();

    return Scaffold(
      backgroundColor: AppColor.background, // Exact blush rose poudré #F9EAE5
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              color: AppColor.primary,
              backgroundColor: Colors.white,
              onRefresh: () async {
                await _loadProducts();
                await _fetchUserProfile();
                await _fetchCartSummary();
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // 1. En-tête pure & épurée (Menu hamburger, A'samesse, Avatar)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.menu_rounded, color: AppColor.textPrimary, size: 24),
                            onPressed: () {},
                          ),
                          const Text(
                            "A'samesse",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.4,
                              color: AppColor.textPrimary,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.go('/profile'),
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColor.primarySoft,
                              child: _userName != null && _userName!.isNotEmpty
                                  ? Text(
                                      _userName![0].toUpperCase(),
                                      style: const TextStyle(
                                        color: AppColor.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    )
                                  : const Icon(Icons.person, color: AppColor.primary, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. Barre de Recherche Blanche Pilule Pure
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onSubmitted: (val) {
                            setState(() {
                              _searchQuery = val.trim();
                              _isLoadingProducts = true;
                            });
                            _loadProducts();
                          },
                          style: const TextStyle(fontSize: 14, color: AppColor.textPrimary),
                          decoration: InputDecoration(
                            hintText: "search",
                            hintStyle: const TextStyle(
                              color: Color(0xFF9E9E9E),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: Color(0xFF9E9E9E),
                              size: 20,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                        _searchQuery = "";
                                        _isLoadingProducts = true;
                                      });
                                      _loadProducts();
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 12)),

                  // 3. Carte Flash Sale Épurée (Widget séparé avec ticker isolé)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.0),
                      child: _FlashSaleCard(),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // 4. Section "New arrivals" & Bouton Filtres
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "New\narrivals",
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                              letterSpacing: -0.8,
                              color: AppColor.textPrimary,
                            ),
                          ),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.tune_rounded, color: AppColor.textPrimary, size: 20),
                              onPressed: () {
                                setState(() {
                                  _showAllProductsGrid = !_showAllProductsGrid;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 14)),

                  // 5. Pilules de Catégories (All noir, autres blanc)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final isSelected = _selectedCategoryIndex == index;
                          final item = _categories[index];

                          return Padding(
                            padding: const EdgeInsets.only(right: 10.0),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedCategoryIndex = index;
                                  _showAllProductsGrid = false;
                                  _isLoadingProducts = true;
                                });
                                _loadProducts();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF1E1E1E) : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF1E1E1E) : Colors.transparent,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    item['label'],
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : AppColor.textPrimary,
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 20)),

                  // 6. Grille & Cartes de Produits (Affichage instantané, sans boucle infinie)
                  if (_isLoadingProducts && _products.isEmpty)
                    const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(40.0),
                          child: CircularProgressIndicator(color: AppColor.primary),
                        ),
                      ),
                    )
                  else if (_showAllProductsGrid)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.78,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return _buildStandardCard(displayProducts[index]);
                          },
                          childCount: displayProducts.length,
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // Rangée 1 : 2 cartes
                          Row(
                            children: [
                              Expanded(
                                child: _buildStandardCard(displayProducts[0]),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildStandardCard(
                                  displayProducts.length > 1 ? displayProducts[1] : displayProducts[0],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Rangée 2 : Carte panoramique large (Beats Solo)
                          _buildFeaturedWideCard(
                            displayProducts.length > 2 ? displayProducts[2] : displayProducts[0],
                          ),
                          const SizedBox(height: 16),

                          // Rangée 3 : Carte normale + Carte bordeaux "Browse All Products"
                          Row(
                            children: [
                              Expanded(
                                child: _buildStandardCard(
                                  displayProducts.length > 3 ? displayProducts[3] : displayProducts[0],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildBrowseAllCard(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 90),
                        ]),
                      ),
                    ),
                ],
              ),
            ),

            // 7. Pilule Flottante Noire Panier ($1080.00 | 🛍️ 2)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    context.go('/cart', extra: {
                      'total': _cartTotal,
                      'itemCount': _cartItemCount,
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatPrice(_cartTotal),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          width: 1,
                          height: 14,
                          color: Colors.white24,
                        ),
                        const Icon(
                          Icons.shopping_bag_outlined,
                          color: Colors.white,
                          size: 15,
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            "$_cartItemCount",
                            style: const TextStyle(
                              color: Color(0xFF1E1E1E),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStandardCard(Map<String, dynamic> product) {
    final String nom = product['nom_produit'] ?? 'Product';
    final String prix = _formatPrice(product['prix']);
    final String? imageUrl = product['image_url'] ?? product['images'];

    return GestureDetector(
      onTap: () {
        context.go('/home/product-detail', extra: product);
      },
      child: Container(
        height: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: _buildProductPhoto(nom, imageUrl),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              nom,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColor.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  prix,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColor.primary,
                  ),
                ),
                GestureDetector(
                  onTap: () => _addProductToCart(product),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColor.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Ajouter',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedWideCard(Map<String, dynamic> product) {
    final String nom = product['nom_produit'] ?? 'Beats Solo';
    final String prix = _formatPrice(product['prix'] ?? 650);
    final String? imageUrl = product['image_url'] ?? product['images'];

    return GestureDetector(
      onTap: () {
        context.go('/home/product-detail', extra: product);
      },
      child: Container(
        height: 170,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    nom,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColor.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Pure Sound. Total\nComfort.",
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF757575),
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        prix,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColor.primary,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _addProductToCart(product),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColor.primary,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'Ajouter',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Center(
                child: _buildProductPhoto(nom, imageUrl),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrowseAllCard() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showAllProductsGrid = true;
          _selectedCategoryIndex = 0;
        });
      },
      child: Container(
        height: 195,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColor.primary, // Exact bordeaux #8B2635
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: AppColor.primary.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: 38,
            ),
            SizedBox(height: 12),
            Text(
              "Browse All\nProducts",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductPhoto(String nom, String? imageUrl) {
    // Si une image asset locale ou distante est spécifiée
    if (imageUrl != null && imageUrl.isNotEmpty) {
      if (imageUrl.startsWith('assets/')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(imageUrl, fit: BoxFit.contain),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          imageUrl,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _localFallbackImage(nom),
        ),
      );
    }
    return _localFallbackImage(nom);
  }

  Widget _localFallbackImage(String nom) {
    final lower = nom.toLowerCase();
    String assetPath = 'assets/images/airpods_pro.jpg';
    if (lower.contains('speaker')) {
      assetPath = 'assets/images/smart_speaker.jpg';
    } else if (lower.contains('beat') || lower.contains('solo') || lower.contains('headphone') || lower.contains('elite')) {
      assetPath = 'assets/images/headphones_coral.jpg';
    } else if (lower.contains('earphone')) {
      assetPath = 'assets/images/earphones.jpg';
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
      ),
    );
  }

  List<Map<String, dynamic>> _getMockProducts() {
    return [
      {
        "id": "1",
        "nom_produit": "Airpods Pro",
        "prix": 499.00,
        "images": "assets/images/airpods_pro.jpg",
        "categorie": "Electronique",
        "description":
            "A mesh textile wraps the ear cushions to provide pillow-like softness. Engineered for pure sonic immersion with active noise cancellation.",
      },
      {
        "id": "2",
        "nom_produit": "Speakers",
        "prix": 359.00,
        "images": "assets/images/smart_speaker.jpg",
        "categorie": "Electronique",
        "description":
            "360-degree room filling sound with deep bass and multi-room audio synchronization.",
      },
      {
        "id": "3",
        "nom_produit": "Beats Solo",
        "prix": 650.00,
        "images": "assets/images/headphones_coral.jpg",
        "categorie": "Electronique",
        "description":
            "Pure Sound. Total Comfort. Over-ear design with premium acoustic memory foam.",
      },
      {
        "id": "4",
        "nom_produit": "Earphones",
        "prix": 160.00,
        "images": "assets/images/earphones.jpg",
        "categorie": "Electronique",
        "description":
            "Ultra-compact wireless earbuds with studio-tuned acoustic clarity.",
      },
    ];
  }
}

// Widget isolé pour le compte à rebours Flash Sale (ne déclenche pas de rebuild sur tout HomeScreen)
class _FlashSaleCard extends StatefulWidget {
  const _FlashSaleCard();

  @override
  State<_FlashSaleCard> createState() => _FlashSaleCardState();
}

class _FlashSaleCardState extends State<_FlashSaleCard> {
  late Timer _timer;
  Duration _remaining = const Duration(hours: 2, minutes: 44, seconds: 58);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_remaining.inSeconds > 0) {
        setState(() {
          _remaining = _remaining - const Duration(seconds: 1);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$h:$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/deals'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 22.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: AppColor.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    "FLASH SALE",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColor.textPrimary,
                  letterSpacing: -0.5,
                ),
                children: [
                  const TextSpan(text: "Ends in "),
                  TextSpan(
                    text: _formatDuration(_remaining),
                    style: const TextStyle(
                      color: AppColor.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Up to 40% off on premium audio essentials",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF757575),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}