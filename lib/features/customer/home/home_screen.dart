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

  String _selectedCategory = 'Toutes';
  List<String> _categories = ['Toutes'];
  String _searchQuery = "";
  String? _userName;
  String? _productsError;

  // Products state
  List<Map<String, dynamic>> _products = [];
  bool _isLoadingProducts = true;

  // Cart summary for the floating pill
  int _cartItemCount = 0;
  double _cartTotal = 0;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _fetchUserProfile();
    _fetchCartSummary();
  }

  Future<void> _loadProducts() async {
    if (mounted) {
      setState(() {
        _isLoadingProducts = true;
        _productsError = null;
      });
    }
    try {
      final fetched = await _productService.fetchProducts();
      final categories =
          fetched
              .map((product) => product['categorie']?.toString().trim() ?? '')
              .where((category) => category.isNotEmpty)
              .toSet()
              .toList()
            ..sort();

      if (mounted) {
        setState(() {
          _products = fetched;
          _categories = ['Toutes', ...categories];
          if (!_categories.contains(_selectedCategory)) {
            _selectedCategory = 'Toutes';
          }
          _isLoadingProducts = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _productsError = error.toString();
          _isLoadingProducts = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _visibleProducts {
    final query = _searchQuery.toLowerCase();
    return _products.where((product) {
      final category = product['categorie']?.toString() ?? '';
      final matchesCategory =
          _selectedCategory == 'Toutes' || category == _selectedCategory;
      final searchableText = [
        product['nom_produit'],
        product['description'],
        category,
      ].whereType<Object>().join(' ').toLowerCase();
      return matchesCategory &&
          (query.isEmpty || searchableText.contains(query));
    }).toList();
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
          final metadataName =
              user.userMetadata?['nom'] ?? user.userMetadata?['name'];
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
      if (user == null) {
        if (mounted)
          setState(() {
            _cartItemCount = 0;
            _cartTotal = 0;
          });
        return;
      }

      final panier = await _supabase
          .from('paniers')
          .select('id_panier')
          .eq('id_acheteur', user.id)
          .maybeSingle();

      if (panier != null) {
        final lines = await _supabase
            .from('lignes_panier')
            .select('quantite, produits(prix)')
            .eq('id_panier', panier['id_panier']);

        int totalCount = 0;
        double totalPrice = 0;
        for (var line in lines) {
          final q = (line['quantite'] as num?)?.toInt() ?? 1;
          totalCount += q;
          final prod = line['produits'];
          if (prod != null) {
            final p = (prod['prix'] is num)
                ? (prod['prix'] as num).toDouble()
                : (double.tryParse(prod['prix'].toString()) ?? 0.0);
            totalPrice += p * q;
          }
        }

        if (mounted) {
          setState(() {
            _cartItemCount = totalCount;
            _cartTotal = totalPrice;
          });
        }
      }
    } catch (_) {
      // Keep the last successfully loaded cart summary.
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatPrice(dynamic raw) {
    if (raw == null) return 'Prix non renseigné';
    final num? val = raw is num ? raw : num.tryParse(raw.toString());
    if (val == null) return "$raw";
    final price = val.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < price.length; i++) {
      if (i > 0 && (price.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(price[i]);
    }
    return '${buffer.toString()} FCFA';
  }

  @override
  Widget build(BuildContext context) {
    final displayProducts = _visibleProducts;

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
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  "A'samesse",
                                  style: TextStyle(
                                    color: AppColor.primary,
                                    fontFamily: 'serif',
                                    fontSize: 23,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Voir le panier',
                                onPressed: () => context.go('/cart'),
                                icon: const Icon(
                                  Icons.shopping_bag_outlined,
                                  color: AppColor.primary,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => context.go('/profile'),
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppColor.primarySoft,
                                  child:
                                      _userName != null && _userName!.isNotEmpty
                                      ? Text(
                                          _userName![0].toUpperCase(),
                                          style: const TextStyle(
                                            color: AppColor.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.person,
                                          color: AppColor.primary,
                                          size: 18,
                                        ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _userName == null || _userName!.trim().isEmpty
                                ? 'Bonjour 👋'
                                : 'Bonjour, ${_userName!.trim().split(' ').first} 👋',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: AppColor.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Qu’est-ce qui vous ferait plaisir ?',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColor.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Search
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 8.0,
                      ),
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
                            });
                            _loadProducts();
                          },
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColor.textPrimary,
                          ),
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
                                    icon: const Icon(
                                      Icons.clear,
                                      size: 18,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                        _searchQuery = "";
                                      });
                                      _loadProducts();
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 12)),

                  // Category filters
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Catégories',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColor.textPrimary,
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 14)),

                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 38,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final category = _categories[index];
                          final isSelected = _selectedCategory == category;

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                category == 'Toutes' ? 'Tout' : category,
                              ),
                              selected: isSelected,
                              showCheckmark: false,
                              selectedColor: AppColor.primary,
                              backgroundColor: Colors.white,
                              side: BorderSide(
                                color: isSelected
                                    ? AppColor.primary
                                    : AppColor.border,
                              ),
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AppColor.textPrimary,
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                              onSelected: (_) {
                                setState(() => _selectedCategory = category);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Tous les produits',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColor.textPrimary,
                            ),
                          ),
                          Text(
                            '${displayProducts.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColor.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_isLoadingProducts && _products.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColor.primary,
                          ),
                        ),
                      ),
                    )
                  else if (_productsError != null && _products.isEmpty)
                    SliverToBoxAdapter(
                      child: _buildProductsMessage(
                        'Impossible de charger les produits.',
                        actionLabel: 'Réessayer',
                        onAction: _loadProducts,
                      ),
                    )
                  else if (displayProducts.isEmpty)
                    SliverToBoxAdapter(
                      child: _buildProductsMessage(
                        _products.isEmpty
                            ? 'Aucun produit en vente pour le moment.'
                            : 'Aucun résultat pour cette recherche.',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.76,
                            ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              _buildProductCard(displayProducts[index]),
                          childCount: displayProducts.length,
                        ),
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
                    context.go(
                      '/cart',
                      extra: {'total': _cartTotal, 'itemCount': _cartItemCount},
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
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

  Widget _buildProductCard(Map<String, dynamic> product) {
    final name = product['nom_produit']?.toString() ?? 'Produit';
    final imageUrl = (product['image_url'] ?? product['images'])?.toString();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          final shopId = product['id_boutique']?.toString();
          if (shopId != null && shopId.isNotEmpty) {
            context.push('/shops/$shopId');
          } else {
            context.push('/home/product-detail', extra: product);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SizedBox.expand(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: _buildProductPhoto(imageUrl),
                  ),
                ),
              ),
              const SizedBox(height: 9),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColor.textPrimary,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _formatPrice(product['prix']),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColor.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductsMessage(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 44),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 34,
            color: AppColor.primary.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColor.textSecondary),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ],
      ),
    );
  }

  Widget _buildProductPhoto(String? imageUrl) {
    if (imageUrl == null || imageUrl.trim().isEmpty)
      return _productImagePlaceholder();
    if (imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _productImagePlaceholder(),
      );
    }
    return Image.network(
      imageUrl,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _productImagePlaceholder(),
      errorBuilder: (_, _, _) => _productImagePlaceholder(),
    );
  }

  Widget _productImagePlaceholder() {
    return const ColoredBox(
      color: AppColor.primarySoft,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: AppColor.primary,
          size: 30,
        ),
      ),
    );
  }
}
