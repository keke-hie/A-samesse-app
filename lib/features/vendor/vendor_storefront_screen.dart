import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_color.dart';
import '../../core/services/product_service.dart';
import '../../core/utils/error_message.dart';
import '../../core/widgets/empty_state.dart';
import '../customer/home/widgets/product_card.dart';

/// Vitrine publique d'une boutique (accessible par lien partagé).
class VendorStorefrontScreen extends StatefulWidget {
  const VendorStorefrontScreen({super.key, required this.shopId});

  final String shopId;

  @override
  State<VendorStorefrontScreen> createState() => _VendorStorefrontScreenState();
}

class _VendorStorefrontScreenState extends State<VendorStorefrontScreen> {
  final _productService = ProductService();
  Map<String, dynamic>? _shop;
  List<Map<String, dynamic>> _products = [];
  Map<String, num> _promos = const {};
  bool _isLoading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final shop = await _productService.fetchShop(widget.shopId);
      if (shop == null) throw Exception('Cette boutique est introuvable.');
      final products = await _productService.fetchShopProducts(widget.shopId);
      final promos = await _productService.fetchActivePromos([
        for (final product in products) product['id_produit'].toString(),
      ]);
      if (!mounted) return;
      setState(() {
        _shop = shop;
        _products = products;
        _promos = promos;
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: Text(_shop?['nom_boutique']?.toString() ?? 'Boutique'),
        actions: [
          IconButton(
            tooltip: 'Panier',
            onPressed: () => context.go('/cart'),
            icon: const Icon(Icons.shopping_bag_outlined),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? EmptyState(
              icon: Icons.storefront_outlined,
              title: 'Boutique indisponible',
              message: friendlyError(_error!),
              actionLabel: 'Retour à l’accueil',
              onAction: () => context.go('/home'),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    sliver: SliverToBoxAdapter(
                      child: _ShopHeader(
                        shop: _shop!,
                        productCount: _products.length,
                      ),
                    ),
                  ),
                  if (_products.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'Cette boutique n’a pas encore de produits',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverLayoutBuilder(
                        builder: (context, constraints) => SliverGrid(
                          gridDelegate: productGridDelegate(
                            constraints.crossAxisExtent,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => ProductCard(
                              product: _products[index],
                              promos: _promos,
                            ),
                            childCount: _products.length,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _ShopHeader extends StatelessWidget {
  const _ShopHeader({required this.shop, required this.productCount});

  final Map<String, dynamic> shop;
  final int productCount;

  @override
  Widget build(BuildContext context) {
    final logoUrl = shop['logo_url']?.toString();
    final description = shop['description']?.toString().trim() ?? '';
    final address = shop['adresse_physique']?.toString().trim() ?? '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: AppColor.primarySoft,
              backgroundImage: logoUrl != null && logoUrl.isNotEmpty
                  ? NetworkImage(logoUrl)
                  : null,
              child: logoUrl == null || logoUrl.isEmpty
                  ? const Icon(
                      Icons.storefront_outlined,
                      color: AppColor.primary,
                      size: 30,
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shop['nom_boutique']?.toString() ?? 'Boutique',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    '$productCount produit${productCount > 1 ? 's' : ''}',
                    style: const TextStyle(color: AppColor.textSecondary),
                  ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 16,
                          color: AppColor.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            address,
                            style: const TextStyle(
                              color: AppColor.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      description,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
