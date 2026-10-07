import 'package:flutter/material.dart';

import '../../../../core/constants/app_color.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/product_image.dart';
import '../../home/widgets/quantity_selector.dart';

class CartLineTile extends StatelessWidget {
  const CartLineTile({
    super.key,
    required this.line,
    required this.selected,
    required this.onSelected,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  final Map<String, dynamic> line;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final product = line['produits'] as Map<String, dynamic>? ?? {};
    final name = product['nom_produit']?.toString() ?? 'Produit';
    final price = parseAmount(line['prix_effectif']);
    final basePrice = parseAmount(product['prix']);
    final quantity = (parseAmount(line['quantite']) ?? 1).toInt();
    final stock = parseAmount(product['stock'])?.toInt();
    final outOfStock = stock != null && stock <= 0;
    final overStock = stock != null && quantity > stock;
    final variants = [
      line['couleur'],
      line['taille'],
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' · ');

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: selected,
              onChanged: outOfStock
                  ? null
                  : (value) => onSelected(value ?? false),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox.square(
                dimension: 76,
                child: ProductImage(url: ProductImage.urlOf(product)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Retirer du panier',
                        visualDensity: VisualDensity.compact,
                        onPressed: onRemove,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  if (variants.isNotEmpty)
                    Text(
                      variants,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColor.textSecondary,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        formatPrice(price),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColor.primary,
                        ),
                      ),
                      if (price != null &&
                          basePrice != null &&
                          price < basePrice) ...[
                        const SizedBox(width: 6),
                        Text(
                          formatPrice(basePrice),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColor.textMuted,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (outOfStock || overStock)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        outOfStock
                            ? 'Rupture de stock'
                            : 'Plus que $stock disponible${stock > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColor.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  QuantitySelector(
                    compact: true,
                    quantity: quantity,
                    max: stock,
                    onChanged: onQuantityChanged,
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
