import 'package:flutter/material.dart';

import '../../../core/constants/app_color.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/product_image.dart';

/// Produit dans la gestion de boutique : modifiable au toucher, avec les
/// actions Studio IA (nouvelle retouche / restauration de l'original).
class VendorProductTile extends StatelessWidget {
  const VendorProductTile({
    super.key,
    required this.product,
    required this.isRetouching,
    required this.onEdit,
    required this.onRetouch,
    required this.onRestore,
  });

  final Map<String, dynamic> product;
  final bool isRetouching;
  final VoidCallback onEdit;
  final VoidCallback onRetouch;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final stock = parseAmount(product['stock'])?.toInt() ?? 0;
    final hasOriginal =
        (product['image_originale_url']?.toString() ?? '').isNotEmpty &&
        product['image_originale_url'] != product['image_url'];

    return Card(
      child: InkWell(
        onTap: onEdit,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ProductImage(url: ProductImage.urlOf(product)),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Column(
                      children: [
                        _ImageAction(
                          tooltip: 'Nouvelle retouche Studio IA',
                          onPressed: isRetouching ? null : onRetouch,
                          child: isRetouching
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.auto_awesome,
                                  size: 18,
                                  color: AppColor.primary,
                                ),
                        ),
                        if (hasOriginal) ...[
                          const SizedBox(height: 6),
                          _ImageAction(
                            tooltip: 'Restaurer la photo originale',
                            onPressed: isRetouching ? null : onRestore,
                            child: const Icon(Icons.history_rounded, size: 18),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['nom_produit']?.toString() ?? 'Sans nom',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatPrice(product['prix']),
                    style: const TextStyle(
                      color: AppColor.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stock > 0 ? '$stock en stock' : 'Rupture de stock',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: stock > 0 ? AppColor.success : AppColor.danger,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageAction extends StatelessWidget {
  const _ImageAction({
    required this.tooltip,
    required this.onPressed,
    required this.child,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColor.surface.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
        icon: child,
      ),
    );
  }
}
