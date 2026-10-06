import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_color.dart';
import '../../../../core/services/product_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/product_image.dart';

/// Carte produit de la grille (accueil, vitrine d'une boutique).
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, this.promos = const {}});

  final Map<String, dynamic> product;
  final Map<String, num> promos;

  @override
  Widget build(BuildContext context) {
    final name = product['nom_produit']?.toString() ?? 'Produit';
    final basePrice = parseAmount(product['prix']);
    final price = ProductService.effectivePrice(product, promos);
    final hasPromo = basePrice != null && price != null && price < basePrice;
    final stock = parseAmount(product['stock']);
    final outOfStock = stock != null && stock <= 0;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.push(
          '/home/product/${product['id_produit']}',
          extra: product,
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ProductImage(url: ProductImage.urlOf(product)),
                      if (hasPromo || outOfStock)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: _Badge(
                            label: outOfStock ? 'Épuisé' : 'Promo',
                            color: outOfStock
                                ? AppColor.textSecondary
                                : AppColor.primary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      formatPrice(price),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColor.primary,
                      ),
                    ),
                  ),
                  if (hasPromo) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        formatPrice(basePrice),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColor.textMuted,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Grille responsive : 2 colonnes sur téléphone, plus sur tablette / web.
SliverGridDelegate productGridDelegate(double width) =>
    SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: width >= 900
          ? 4
          : width >= 600
          ? 3
          : 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.72,
    );
