import 'package:asamesse_app/core/services/product_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProductService.effectivePrice', () {
    final product = {'id_produit': 'p1', 'prix': 10000};

    test('prix catalogue sans promo', () {
      expect(ProductService.effectivePrice(product, {}), 10000);
    });

    test('prix promo s’il est inférieur', () {
      expect(ProductService.effectivePrice(product, {'p1': 7500}), 7500);
    });

    test('une promo plus chère que le prix catalogue est ignorée', () {
      expect(ProductService.effectivePrice(product, {'p1': 12000}), 10000);
    });

    test('prix texte accepté', () {
      expect(
        ProductService.effectivePrice({'id_produit': 'p2', 'prix': '4500'}, {}),
        4500,
      );
    });
  });
}
