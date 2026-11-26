import 'dart:convert';
import 'package:http/http.dart' as http;
import 'lib/features/product/data/models/product_model.dart';

void main() async {
  final url = Uri.parse('https://api.bemsfarms.com/api/products/');
  final response = await http.get(url);
  try {
    final decoded = jsonDecode(response.body);
    List items = [];
    if (decoded is List) {
      items = decoded;
    } else if (decoded is Map<String, dynamic>) {
      items = decoded['products'] ?? decoded['results'] ?? decoded['data'] ?? [];
      if (items.isEmpty && decoded.containsKey('data') && decoded['data'] is Map && decoded['data'].containsKey('products')) {
        items = decoded['data']['products'];
      }
    }
    
    for (var json in items) {
      final p = Product.fromJson(json);
      if (p.isOutOfStock) {
        print('OUT OF STOCK PRODUCT FOUND: ${p.name}');
        return;
      }
    }
    print('NO OUT OF STOCK PRODUCTS FOUND IN THE FIRST PAGE.');
  } catch (e) {}
}
