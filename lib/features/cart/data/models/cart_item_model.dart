import 'package:bems_farms/features/product/data/models/product_model.dart';

class CartItem {
  final Product product;
  final int quantity;

  const CartItem({
    required this.product,
    required this.quantity,
  });

  CartItem copyWith({
    Product? product,
    int? quantity,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    Product prod;
    if (json['product'] is Map<String, dynamic>) {
      prod = Product.fromJson(json['product'] as Map<String, dynamic>);
    } else if (json['Product'] is Map<String, dynamic>) {
      prod = Product.fromJson(json['Product'] as Map<String, dynamic>);
    } else if (json['product_metadata'] is Map<String, dynamic>) {
      prod = Product.fromJson(json['product_metadata'] as Map<String, dynamic>);
    } else {
      prod = Product.fromJson(json);
    }

    if (prod.id.isEmpty) {
      final pid = json['productId'] ?? json['product_id'] ?? json['id'] ?? '';
      prod = prod.copyWith(id: pid.toString());
    }

    return CartItem(
      product: prod,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product': product.toJson(),
      'quantity': quantity,
    };
  }

  double get totalPrice => product.price * quantity;
}
