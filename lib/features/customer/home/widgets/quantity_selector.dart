import 'package:flutter/material.dart';

import '../../../../core/constants/app_color.dart';

/// Sélecteur − / quantité / +, borné par le stock disponible.
class QuantitySelector extends StatelessWidget {
  const QuantitySelector({
    super.key,
    required this.quantity,
    required this.onChanged,
    this.max,
    this.compact = false,
  });

  final int quantity;
  final int? max;
  final bool compact;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final canDecrease = quantity > 1;
    final canIncrease = max == null || quantity < max!;
    final buttons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.outlined(
          tooltip: 'Retirer un',
          visualDensity: compact ? VisualDensity.compact : null,
          onPressed: canDecrease ? () => onChanged(quantity - 1) : null,
          icon: const Icon(Icons.remove_rounded, size: 18),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        IconButton.filled(
          tooltip: 'Ajouter un',
          visualDensity: compact ? VisualDensity.compact : null,
          onPressed: canIncrease ? () => onChanged(quantity + 1) : null,
          icon: const Icon(Icons.add_rounded, size: 18),
        ),
      ],
    );
    if (compact) return buttons;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColor.background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text('Quantité', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          buttons,
        ],
      ),
    );
  }
}
