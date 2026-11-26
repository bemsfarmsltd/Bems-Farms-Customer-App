import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  var uri = Uri.parse('https://api.bemsfarms.com/api/products/');
  var response = await http.get(uri);
  var body = jsonDecode(response.body);
  if (body['products'] != null) {
    for (var p in body['products']) {
      if (p['name'].toString().contains('Ama Wonda')) {
        print('Found: ${p['name']} | Tags: ${p['tags']} | Category: ${p['category_name']} | is_featured: ${p['is_featured']}');
      }
    }
  }
}
