import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final uri = Uri.parse('https://api.bemsfarms.com/api/products/');
  try {
    final response = await http.get(uri);
    final decoded = jsonDecode(response.body);
    print(const JsonEncoder.withIndent('  ').convert(decoded));
  } catch (e) {
    print('Error: $e');
  }
}
