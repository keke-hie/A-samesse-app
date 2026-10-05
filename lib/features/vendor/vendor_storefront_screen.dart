import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_color.dart';

class VendorStorefrontScreen extends StatefulWidget {
  final String shopId;

  const VendorStorefrontScreen({super.key, required this.shopId});

  @override
  State<VendorStorefrontScreen> createState() => _VendorStorefrontScreenState();
}

class _VendorStorefrontScreenState extends State<VendorStorefrontScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _shop;
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStorefront();
  }

  Future<void> _loadStorefront() async {
    try {
      final shop = await _supabase
          .from('boutiques')
          .select()
          .eq('id_boutique', widget.shopId)
          .maybeSingle();
      if (shop == null) throw Exception('Cette boutique est introuvable.');

      final products = await _supabase
          .from('produits')
          .select()
          .eq('id_boutique', widget.shopId)
          .order('date_ajout', ascending: false);

      if (!mounted) return;
      setState(() {
        _shop = shop;
        _products = List<Map<String, dynamic>>.from(products);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  String _formatPrice(dynamic value) {
    final price = value is num
        ? value
        : num.tryParse(value?.toString() ?? '') ?? 0;
    return '${price.toStringAsFixed(0)} FCFA';
  }

  @override
  Widget build(BuildContext context) {
    final shop = _shop;
    final shopName = shop?['nom_boutique']?.toString() ?? 'Boutique';
    final logoUrl = shop?['logo_url']?.toString();
    final description = shop?['description']?.toString().trim() ?? '';
    final followers = shop?['nombre_abonnements'] ?? 0;

    return Scaffold(
      backgroundColor: AppColor.background,
      appBar: AppBar(
        title: const Text('Boutique'),
        backgroundColor: AppColor.background,
        actions: [
          IconButton(
            tooltip: 'Voir le panier',
            onPressed: () => context.push('/cart'),
            icon: const Icon(Icons.shopping_bag_outlined),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColor.primary),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Chargement de la boutique impossible : $_error',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadStorefront,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: AppColor.primarySoft,
                            backgroundImage:
                                logoUrl != null && logoUrl.isNotEmpty
                                ? NetworkImage(logoUrl)
                                : null,
                            child: logoUrl == null || logoUrl.isEmpty
                                ? const Icon(
                                    Icons.storefront_outlined,
                                    color: AppColor.primary,
                                    size: 32,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  shopName,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '$followers abonnés · ${_products.length} produits',
                                  style: const TextStyle(
                                    color: AppColor.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                                if (description.isNotEmpty) ...[
                                  const SizedBox(height: 7),
                                  Text(
                                    description,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColor.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Tous les produits',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            '${_products.length}',
                            style: const TextStyle(
                              color: AppColor.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_products.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          'Cette boutique n’a pas encore de produits.',
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.67,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final product = _products[index];
                          final imageUrl =
                              (product['image_url'] ?? product['images'])
                                  ?.toString();
                          final stockValue = product['stock'];
                          final stock = stockValue is num
                              ? stockValue.toInt()
                              : int.tryParse('$stockValue');
                          final inStock = stock == null || stock > 0;
                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => context.push(
                                '/home/product-detail',
                                extra: product,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        imageUrl == null || imageUrl.isEmpty
                                            ? const ColoredBox(
                                                color: AppColor.primarySoft,
                                                child: Icon(
                                                  Icons.image_outlined,
                                                  color: AppColor.primary,
                                                  size: 36,
                                                ),
                                              )
                                            : Image.network(
                                                imageUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, _, _) =>
                                                    const ColoredBox(
                                                      color:
                                                          AppColor.primarySoft,
                                                      child: Icon(
                                                        Icons
                                                            .image_not_supported_outlined,
                                                        color: AppColor.primary,
                                                      ),
                                                    ),
                                              ),
                                        Positioned(
                                          top: 8,
                                          left: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: inStock
                                                  ? Colors.white.withValues(
                                                      alpha: 0.94,
                                                    )
                                                  : AppColor.primary,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              stock == null
                                                  ? 'Stock disponible'
                                                  : inStock
                                                  ? 'Stock : $stock'
                                                  : 'Épuisé',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: inStock
                                                    ? AppColor.textPrimary
                                                    : Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product['nom_produit']?.toString() ??
                                              'Produit',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          _formatPrice(product['prix']),
                                          style: const TextStyle(
                                            color: AppColor.primary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }, childCount: _products.length),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
