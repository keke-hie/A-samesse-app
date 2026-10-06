import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_color.dart';
import '../../../core/services/cart_service.dart';
import '../../../core/services/product_service.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/product_image.dart';
import 'widgets/quantity_selector.dart';

/// Fiche produit. Chargée par identifiant pour fonctionner aussi depuis un
/// lien partagé ; [initialProduct] évite seulement un écran de chargement.
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.productId,
    this.initialProduct,
  });

  final String productId;
  final Map<String, dynamic>? initialProduct;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final _productService = ProductService();
  final _cartService = CartService();

  Map<String, dynamic>? _product;
  Map<String, num> _promos = const {};
  Object? _loadError;
  int _quantity = 1;
  String? _selectedColor;
  String? _selectedSize;
  bool _isAddingToCart = false;

  @override
  void initState() {
    super.initState();
    _product = widget.initialProduct;
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object?>([
        _productService.fetchProduct(widget.productId),
        _productService.fetchActivePromos([widget.productId]),
      ]);
      if (!mounted) return;
      setState(() {
        _product = results[0] as Map<String, dynamic>?;
        _promos = results[1]! as Map<String, num>;
        _loadError = null;
      });
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  List<String> _options(String key) {
    final value = _product?[key];
    final Iterable<Object?> raw = value is Iterable
        ? value
        : value is String
        ? value.split(RegExp(r'[,;\n]'))
        : const [];
    return raw
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  int? get _stock {
    final value = parseAmount(_product?['stock']);
    return value?.toInt();
  }

  Future<void> _addToCart() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Connecte-toi pour ajouter au panier.'),
          action: SnackBarAction(
            label: 'Connexion',
            onPressed: () => context.go('/login'),
          ),
        ),
      );
      return;
    }
    if (_options('couleurs').isNotEmpty && _selectedColor == null) {
      _showMessage('Choisis une couleur.');
      return;
    }
    if (_options('tailles').isNotEmpty && _selectedSize == null) {
      _showMessage('Choisis une taille ou un modèle.');
      return;
    }

    setState(() => _isAddingToCart = true);
    try {
      await _cartService.addItem(
        productId: widget.productId,
        quantity: _quantity,
        color: _selectedColor ?? '',
        size: _selectedSize ?? '',
        stock: _stock,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ajouté au panier (×$_quantity).'),
          action: SnackBarAction(
            label: 'Voir le panier',
            onPressed: () => context.go('/cart'),
          ),
        ),
      );
    } catch (error) {
      if (mounted) _showMessage(friendlyError(error));
    } finally {
      if (mounted) setState(() => _isAddingToCart = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;
    if (product == null) {
      return Scaffold(
        appBar: AppBar(),
        body: _loadError != null
            ? EmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'Impossible de charger ce produit',
                message: friendlyError(_loadError!),
                actionLabel: 'Réessayer',
                onAction: _load,
              )
            : const Center(child: CircularProgressIndicator()),
      );
    }

    final name = product['nom_produit']?.toString() ?? 'Produit';
    final basePrice = parseAmount(product['prix']);
    final unitPrice = ProductService.effectivePrice(product, _promos);
    final hasPromo = basePrice != null && unitPrice != null && unitPrice < basePrice;
    final stock = _stock;
    final outOfStock = stock != null && stock <= 0;
    final colors = _options('couleurs');
    final sizes = _options('tailles');
    final features = _options('caracteristiques');
    final description = product['description']?.toString().trim() ?? '';
    final shopId = product['id_boutique']?.toString();

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: ColoredBox(
                  color: AppColor.surface,
                  child: ProductImage(
                    url: ProductImage.urlOf(product),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: AppColor.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatPrice(unitPrice),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColor.primary,
                      ),
                    ),
                    if (hasPromo) ...[
                      const SizedBox(width: 10),
                      Text(
                        formatPrice(basePrice),
                        style: const TextStyle(
                          color: AppColor.textMuted,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (stock != null) _StockBadge(stock: stock),
                  ],
                ),
                if (shopId != null && shopId.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: () => context.push('/shops/$shopId'),
                      icon: const Icon(Icons.storefront_outlined, size: 18),
                      label: const Text('Voir la boutique'),
                    ),
                  ),
                const SizedBox(height: 12),
                if (colors.isNotEmpty) ...[
                  _SectionTitle('Couleur'),
                  _OptionChips(
                    options: colors,
                    selected: _selectedColor,
                    onSelected: (value) => setState(() => _selectedColor = value),
                  ),
                  const SizedBox(height: 16),
                ],
                if (sizes.isNotEmpty) ...[
                  _SectionTitle('Taille / modèle'),
                  _OptionChips(
                    options: sizes,
                    selected: _selectedSize,
                    onSelected: (value) => setState(() => _selectedSize = value),
                  ),
                  const SizedBox(height: 16),
                ],
                if (!outOfStock) ...[
                  QuantitySelector(
                    quantity: _quantity,
                    max: stock,
                    onChanged: (value) => setState(() => _quantity = value),
                  ),
                  const SizedBox(height: 20),
                ],
                _SectionTitle('Description'),
                Text(
                  description.isEmpty
                      ? 'Aucune description renseignée pour ce produit.'
                      : description,
                  style: const TextStyle(height: 1.5, color: AppColor.textSecondary),
                ),
                if (features.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _SectionTitle('Caractéristiques'),
                  for (final feature in features)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 18,
                            color: AppColor.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              feature,
                              style: const TextStyle(color: AppColor.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: const BoxDecoration(
            color: AppColor.surface,
            border: Border(top: BorderSide(color: AppColor.border)),
          ),
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total ($_quantity art.)',
                    style: const TextStyle(fontSize: 12, color: AppColor.textSecondary),
                  ),
                  Text(
                    formatPrice(unitPrice == null ? null : unitPrice * _quantity),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColor.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isAddingToCart || unitPrice == null || outOfStock
                      ? null
                      : _addToCart,
                  icon: _isAddingToCart
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.shopping_bag_outlined),
                  label: Text(outOfStock ? 'Rupture de stock' : 'Ajouter au panier'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _OptionChips extends StatelessWidget {
  const _OptionChips({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          ChoiceChip(
            label: Text(option),
            selected: option == selected,
            onSelected: (_) => onSelected(option),
          ),
      ],
    );
  }
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.stock});

  final int stock;

  @override
  Widget build(BuildContext context) {
    final available = stock > 0;
    final low = available && stock <= 5;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: available ? AppColor.successSoft : AppColor.dangerSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        !available
            ? 'Rupture de stock'
            : low
            ? 'Plus que $stock'
            : 'En stock',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: available ? AppColor.success : AppColor.danger,
        ),
      ),
    );
  }
}
