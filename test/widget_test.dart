import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:bems_farms/features/orders/data/models/order_model.dart';
import 'package:bems_farms/features/product/data/models/product_model.dart';

void main() {
  test('cancelled status maps to the expected label and enum', () {
    expect(OrderStatusX.fromString('cancelled'), OrderStatus.cancelled);
    expect(OrderStatusX.fromString('canceled'), OrderStatus.cancelled);
    expect(OrderStatus.cancelled.label, 'Cancelled');
  });

  test('product payload with wrapped products list maps correctly', () {
    final payload = {
      'products': [
        {
          'id': 15,
          'name': 'Plantain',
          'price': '1.20',
          'image_url': 'https://example.com/plantain.jpg',
          'category': 'Vegetables',
          'unit': 'Bunch (5-6 pieces)',
          'description': 'Ripe yellow plantain',
          'is_featured': true,
        },
      ],
    };

    final products = (payload['products'] as List)
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();

    expect(products, hasLength(1));
    expect(products.first.name, 'Plantain');
    expect(products.first.price, 1.2);
    expect(products.first.imageUrl, 'https://example.com/plantain.jpg');
    expect(products.first.isOnDeal, true);
  });
}
