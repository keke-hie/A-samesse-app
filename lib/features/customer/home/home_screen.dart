import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_color.dart';
import '../../../core/services/cart_service.dart';
import '../../../core/services/product_service.dart';
import '../../../core/services/session_service.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import 'widgets/product_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _allCategories = 'Tout';

  final _productService = ProductService();
  final _cartService = CartService();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _products = [];
  Map<String, num> _promos = const {};
  CartSummary _cart = CartSummary.empty;
  String _category = _allCategories;
  String _query = '';
  bool _isLoading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object>([
        _productService.fetchCatalog(),
        _productService.fetchActivePromos(),
        // Le résumé du panier est secondaire : son échec ne bloque pas l'accueil.
        _cartService.fetchSummary().catchError((_) => CartSummary.empty),
      ]);
      if (!mounted) return;
      setState(() {
        _products = results[0] as List<Map<String, dynamic>>;
        _promos = results[1] as Map<String, num>;
        _cart = results[2] as CartSummary;
        if (!_categories.contains(_category)) _category = _allCategories;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }

  List<String> get _categories {
    final found =
        _products
            .map((product) => product['categorie']?.toString().trim() ?? '')
            .where((category) => category.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return [_allCategories, ...found];
  }

  List<Map<String, dynamic>> get _visibleProducts {
    final query = _query.toLowerCase();
    return _products.where((product) {
      final category = product['categorie']?.toString() ?? '';
      if (_category != _allCategories && category != _category) return false;
      if (query.isEmpty) return true;
      return [
        product['nom_produit'],
        product['description'],
        category,
      ].whereType<Object>().join(' ').toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final firstName = SessionService.instance.displayName
        ?.trim()
        .split(' ')
        .first;
    final products = _visibleProducts;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "A'samesse",
                                  style: TextStyle(
                                    color: AppColor.primary,
                                    fontFamily: 'serif',
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  firstName == null || firstName.isEmpty
                                      ? 'Bonjour 👋'
                                      : 'Bonjour, $firstName 👋',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const Text(
                                  'Qu’est-ce qui vous ferait plaisir ?',
                                  style: TextStyle(
                                    color: AppColor.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Panier',
                            onPressed: () => context.go('/cart'),
                            icon: Badge(
                              isLabelVisible: _cart.itemCount > 0,
                              label: Text('${_cart.itemCount}'),
                              child: const Icon(Icons.shopping_bag_outlined),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                    sliver: SliverToBoxAdapter(
                      child: SearchBar(
                        controller: _searchController,
                        hintText: 'Rechercher un produit',
                        leading: const Icon(Icons.search_rounded),
                        trailing: [
                          if (_query.isNotEmpty)
                            IconButton(
                              tooltip: 'Effacer',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _query = value.trim()),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 56,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                        itemCount: _categories.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final category = _categories[index];
                          return ChoiceChip(
                            label: Text(category),
                            selected: category == _category,
                            onSelected: (_) =>
                                setState(() => _category = category),
                          );
                        },
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _category == _allCategories
                                  ? 'Tous les produits'
                                  : _category,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (!_isLoading)
                            Text(
                              '${products.length} article${products.length > 1 ? 's' : ''}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColor.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (_isLoading && _products.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null && _products.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: Icons.cloud_off_outlined,
                        title: 'Impossible de charger les produits',
                        message: friendlyError(_error!),
                        actionLabel: 'Réessayer',
                        onAction: _load,
                      ),
                    )
                  else if (products.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: Icons.search_off_rounded,
                        title: _products.isEmpty
                            ? 'Aucun produit en vente pour le moment'
                            : 'Aucun résultat',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      sliver: SliverLayoutBuilder(
                        builder: (context, constraints) => SliverGrid(
                          gridDelegate: productGridDelegate(
                            constraints.crossAxisExtent,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => ProductCard(
                              product: products[index],
                              promos: _promos,
                            ),
                            childCount: products.length,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (_cart.itemCount > 0)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(child: _CartPill(summary: _cart)),
              ),
          ],
        ),
      ),
    );
  }
}

class _CartPill extends StatelessWidget {
  const _CartPill({required this.summary});

  final CartSummary summary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColor.darkPill,
      elevation: 6,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => context.go('/cart'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.shopping_bag_outlined,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '${summary.itemCount} article${summary.itemCount > 1 ? 's' : ''} · ${formatPrice(summary.total)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
