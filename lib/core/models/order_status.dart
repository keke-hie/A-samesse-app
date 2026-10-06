import 'package:flutter/material.dart';

import '../constants/app_color.dart';

/// Cycle de vie d'une commande, aligné sur les fonctions SQL
/// (`supabase/migrations/20261006090000_secure_checkout_flow.sql`).
enum OrderStatus {
  awaitingPayment('en_attente_paiement', 'En attente de paiement'),
  paid('payee', 'Payée'),
  preparing('en_preparation', 'En préparation'),
  ready('prete', 'Prête à expédier'),
  shipping('en_livraison', 'En livraison'),
  delivered('livre', 'Livrée'),
  cancelled('annule', 'Annulée');

  const OrderStatus(this.value, this.label);

  final String value;
  final String label;

  static OrderStatus parse(dynamic raw) {
    final value = raw?.toString().toLowerCase().trim() ?? '';
    for (final status in values) {
      if (status.value == value) return status;
    }
    // Anciennes valeurs encore présentes en base.
    if (value.startsWith('livr')) return delivered;
    if (value.startsWith('annul')) return cancelled;
    if (value.contains('cours')) return shipping;
    if (value.contains('prepar')) return preparing;
    return awaitingPayment;
  }

  /// Étapes affichées dans la frise de suivi.
  static const timeline = [paid, preparing, ready, shipping, delivered];

  bool get isFinal => this == delivered || this == cancelled;

  Color get color => switch (this) {
    awaitingPayment => AppColor.warning,
    paid || preparing || ready => AppColor.goldDark,
    shipping => AppColor.primary,
    delivered => AppColor.success,
    cancelled => AppColor.danger,
  };
}
