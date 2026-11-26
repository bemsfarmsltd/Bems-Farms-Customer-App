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
      if (json['name'].toString().contains('Gino Pepper')) {
        print('JSON for Gino:');
        print(const JsonEncoder.withIndent('  ').convert(json));
        final p = Product.fromJson(json);
        print('Parsed Product: stock=${p.stock}, isOutOfStock=${p.isOutOfStock}');
      }
    }
  } catch (e) {}
}
