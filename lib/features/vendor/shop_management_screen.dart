import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_color.dart';
import '../../core/services/session_service.dart';
import '../../core/services/vendor_service.dart';
import '../../core/utils/error_message.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../customer/home/widgets/product_card.dart';
import 'product_form_screen.dart';
import 'widgets/shop_info_sheet.dart';
import 'widgets/vendor_product_tile.dart';

/// Gestion de la boutique : identité (nom, logo, description) et catalogue.
/// Les statistiques sont sur le tableau de bord vendeur.
class ShopManagementScreen extends StatefulWidget {
  const ShopManagementScreen({super.key, this.productsOnly = false});

  final bool productsOnly;

  @override
  State<ShopManagementScreen> createState() => _ShopManagementScreenState();
}

class _ShopManagementScreenState extends State<ShopManagementScreen> {
  final _vendorService = VendorService();

  Map<String, dynamic>? _shop;
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  Object? _error;
  bool _uploadingLogo = false;
  final Set<String> _retouching = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final shop = await _vendorService.fetchMyShop();
      final products = await _vendorService.fetchMyProducts();
      if (!mounted) return;
      setState(() {
        _shop = shop;
        _products = products;
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editShop() async {
    final saved = await showShopInfoSheet(
      context,
      shop: _shop,
      suggestedName: SessionService.instance.user?.userMetadata?['nom_commerce']
          ?.toString(),
    );
    if (saved == true) await _load();
  }

  Future<void> _changeLogo() async {
    final shopId = _shop?['id_boutique']?.toString();
    if (shopId == null) return;
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 800,
    );
    if (file == null) return;
    setState(() => _uploadingLogo = true);
    try {
      final url = await _vendorService.uploadShopLogo(file, shopId);
      if (mounted) setState(() => _shop = {...?_shop, 'logo_url': url});
    } catch (error) {
      if (mounted) _showMessage(friendlyError(error));
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  Future<void> _openProductForm([Map<String, dynamic>? product]) async {
    if (_shop == null) {
      _showMessage('Crée d’abord ta boutique.');
      await _editShop();
      return;
    }
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)),
    );
    if (changed == true) await _load();
  }

  Future<void> _retouch(
    Map<String, dynamic> product, {
    required bool restore,
  }) async {
    final productId = product['id_produit'].toString();
    if (!restore) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Nouvelle retouche Studio IA ?'),
          content: const Text(
            'Une nouvelle image catalogue sera générée. L’original reste conservé. '
            'Chaque génération peut être facturée.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Générer'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _retouching.add(productId));
    try {
      final url = await _vendorService.retouchProductPhoto(
        productId,
        restore: restore,
      );
      if (!mounted) return;
      setState(() => product['image_url'] = url);
      _showMessage(
        restore ? 'Photo originale restaurée.' : 'Image catalogue mise à jour.',
      );
    } catch (error) {
      if (mounted) _showMessage(friendlyError(error));
    } finally {
      if (mounted) setState(() => _retouching.remove(productId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopId = _shop?['id_boutique']?.toString();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.productsOnly ? 'Mes produits' : 'Ma boutique'),
        actions: [
          if (shopId != null)
            IconButton(
              tooltip: 'Voir ma vitrine',
              onPressed: () => context.push('/shops/$shopId'),
              icon: const Icon(Icons.visibility_outlined),
            ),
        ],
      ),
      floatingActionButton: _isLoading || _error != null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openProductForm(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Produit'),
            ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Chargement impossible',
        message: friendlyError(_error!),
        actionLabel: 'Réessayer',
        onAction: _load,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          if (!widget.productsOnly)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _shop == null
                        ? _CreateShopCard(onCreate: _editShop)
                        : _ShopCard(
                            shop: _shop!,
                            uploadingLogo: _uploadingLogo,
                            onEdit: _editShop,
                            onChangeLogo: _changeLogo,
                          ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.bolt_rounded, size: 18),
                          label: const Text('Vente éphémère'),
                          onPressed: () => context.push('/vendor/deals'),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.auto_awesome, size: 18),
                          label: const Text('Campagne marketing'),
                          onPressed: () => context.go('/vendor/marketing-ia'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
            sliver: SliverToBoxAdapter(
              child: Text(
                '${_products.length} produit${_products.length > 1 ? 's' : ''} en ligne',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          if (_products.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'Aucun produit pour le moment',
                actionLabel: 'Ajouter mon premier produit',
                onAction: () => _openProductForm(),
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
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final product = _products[index];
                    return VendorProductTile(
                      product: product,
                      isRetouching: _retouching.contains(
                        product['id_produit'].toString(),
                      ),
                      onEdit: () => _openProductForm(product),
                      onRetouch: () => _retouch(product, restore: false),
                      onRestore: () => _retouch(product, restore: true),
                    );
                  }, childCount: _products.length),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({
    required this.shop,
    required this.uploadingLogo,
    required this.onEdit,
    required this.onChangeLogo,
  });

  final Map<String, dynamic> shop;
  final bool uploadingLogo;
  final VoidCallback onEdit;
  final VoidCallback onChangeLogo;

  @override
  Widget build(BuildContext context) {
    final logoUrl = shop['logo_url']?.toString();
    final description = shop['description']?.toString().trim() ?? '';
    final address = shop['adresse_physique']?.toString().trim() ?? '';
    final created = shop['date_creation'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
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
                Positioned(
                  right: -8,
                  bottom: -8,
                  child: IconButton.filledTonal(
                    tooltip: 'Changer le logo',
                    visualDensity: VisualDensity.compact,
                    onPressed: uploadingLogo ? null : onChangeLogo,
                    icon: uploadingLogo
                        ? const SizedBox.square(
                            dimension: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.photo_camera_outlined, size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shop['nom_boutique']?.toString() ?? 'Ma boutique',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description.isEmpty
                        ? 'Ajoute une description à ta boutique.'
                        : description,
                    style: TextStyle(
                      color: description.isEmpty
                          ? AppColor.textMuted
                          : AppColor.textSecondary,
                    ),
                  ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 6),
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
                              fontSize: 13,
                              color: AppColor.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (created != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Ouverte le ${formatDate(created)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColor.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Modifier',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateShopCard extends StatelessWidget {
  const _CreateShopCard({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColor.primarySoft,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ta boutique n’est pas encore créée',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              'Donne-lui un nom et une description pour pouvoir publier tes produits.',
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.storefront_outlined),
              label: const Text('Créer ma boutique'),
            ),
          ],
        ),
      ),
    );
  }
}
