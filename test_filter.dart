import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  // Test 1: Category filter
  var uri = Uri.parse('https://api.bemsfarms.com/api/products/?category=Weekly%20Household%20Staples');
  var response = await http.get(uri);
  print('Category filter response:');
  var body = jsonDecode(response.body);
  if (body['products'] != null) {
    for (var p in body['products']) {
      print(p['name']);
    }
  } else if (body is List) {
    for (var p in body) print(p['name']);
  }

  // Test 2: Search filter
  uri = Uri.parse('https://api.bemsfarms.com/api/products/search?q=Weekly%20Household%20Staples');
  response = await http.get(uri);
  print('\nSearch filter response:');
  body = jsonDecode(response.body);
  if (body['products'] != null) {
    for (var p in body['products']) {
      print(p['name']);
    }
  } else if (body is List) {
    for (var p in body) print(p['name']);
  } else if (body['results'] != null) {
    for (var p in body['results']) {
      print(p['name']);
    }
  }
}
