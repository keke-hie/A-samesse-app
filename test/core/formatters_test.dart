import 'package:asamesse_app/core/models/order_status.dart';
import 'package:asamesse_app/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatPrice', () {
    test('sépare les milliers', () {
      expect(formatPrice(12500), '12 500 FCFA');
      expect(formatPrice(1500000), '1 500 000 FCFA');
      expect(formatPrice(950), '950 FCFA');
    });

    test('accepte les montants texte et les valeurs manquantes', () {
      expect(formatPrice('3000.0'), '3 000 FCFA');
      expect(formatPrice(null), 'Prix non renseigné');
      expect(formatPrice('abc', fallback: '—'), '—');
    });
  });

  test('shortOrderRef', () {
    expect(shortOrderRef('3f2a9c1b-1234-5678'), '#3F2A9C1B');
    expect(shortOrderRef('42'), '#42');
  });

  group('OrderStatus.parse', () {
    test('reconnaît les statuts du serveur', () {
      expect(
        OrderStatus.parse('en_attente_paiement'),
        OrderStatus.awaitingPayment,
      );
      expect(OrderStatus.parse('prete'), OrderStatus.ready);
      expect(OrderStatus.parse('livre'), OrderStatus.delivered);
    });

    test('reconnaît les anciennes valeurs', () {
      expect(OrderStatus.parse('Livrée'), OrderStatus.delivered);
      expect(OrderStatus.parse('annulé'), OrderStatus.cancelled);
      expect(OrderStatus.parse('en cours'), OrderStatus.shipping);
    });
  });
}
