import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product_model.dart';
import 'package:bems_farms/features/auth/data/repositories/token_storage.dart';
import 'package:bems_farms/core/network/api_constants.dart';

class ProductRepository {
  final http.Client _client;
  final TokenStorage _tokenStorage;

  ProductRepository({http.Client? client, TokenStorage? tokenStorage})
      : _client = client ?? http.Client(),
        _tokenStorage = tokenStorage ?? TokenStorage();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _tokenStorage.getToken();
    return ApiConstants.authHeaders(token ?? '');
  }

  Future<List<Product>> getFreshProducts() async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/products')
        .replace(queryParameters: {'limit': '20'});
    final response = await _client.get(uri, headers: await _authHeaders());
    _checkStatus(response);
    return _decodeProductsResponse(response.body);
  }

  Future<List<Product>> getDealProducts() async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/products/featured');
    final response = await _client.get(uri, headers: await _authHeaders());
    _checkStatus(response);
    return _decodeProductsResponse(response.body);
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/categories/');
    final response = await _client.get(uri, headers: await _authHeaders());
    _checkStatus(response);
    
    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      return decoded.whereType<Map<String, dynamic>>().toList();
    } else if (decoded is Map<String, dynamic>) {
      final items = decoded['categories'] ?? decoded['results'] ?? [];
      if (items is List) {
        return items.whereType<Map<String, dynamic>>().toList();
      }
    }
    return [];
  }

  Future<Map<String, dynamic>> getAllProducts({String? category, String? search, int? page, int? limit}) async {
    final queryParams = <String, String>{};
    if (category != null) queryParams['category'] = category;
    if (search != null) queryParams['search'] = search;
    if (page != null) queryParams['page'] = page.toString();
    if (limit != null) queryParams['limit'] = limit.toString();

    final uri = Uri.parse('${ApiConstants.baseUrl}/products').replace(
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    final response = await _client.get(uri, headers: await _authHeaders());
    _checkStatus(response);
    return jsonDecode(response.body); // Return full payload including count, page, pages
  }

  Future<List<Product>> searchProducts(String query, {int? limit}) async {
    final queryParams = <String, String>{'q': query};
    if (limit != null) queryParams['limit'] = limit.toString();

    final uri = Uri.parse('${ApiConstants.baseUrl}/products/search').replace(
      queryParameters: queryParams,
    );
    final response = await _client.get(uri, headers: await _authHeaders());
    _checkStatus(response);
    return _decodeProductsResponse(response.body);
  }

  Future<Product> getProductById(String id) async {
    final response = await _client.get(
      Uri.parse('${ApiConstants.baseUrl}/products/$id/'),
      headers: await _authHeaders(),
    );
    _checkStatus(response);
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic> && decoded.containsKey('product')) {
      return Product.fromJson(decoded['product'] as Map<String, dynamic>);
    }
    return Product.fromJson(decoded as Map<String, dynamic>);
  }

  Future<List<ProductReview>> getProductReviews(String id, {int? page, int? limit}) async {
    final queryParams = <String, String>{};
    if (page != null) queryParams['page'] = page.toString();
    if (limit != null) queryParams['limit'] = limit.toString();

    final uri = Uri.parse('${ApiConstants.baseUrl}/products/$id/reviews').replace(
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    final response = await _client.get(uri, headers: await _authHeaders());
    _checkStatus(response);
    final decoded = jsonDecode(response.body);
    
    List items = [];
    if (decoded is List) {
      items = decoded;
    } else if (decoded is Map<String, dynamic>) {
      items = decoded['reviews'] ?? decoded['results'] ?? [];
    }

    return items.whereType<Map<String, dynamic>>().map(ProductReview.fromJson).toList();
  }

  Future<void> submitReview(String id, double rating, String comment, {String? reviewerName}) async {
    final payload = <String, dynamic>{
      'rating': rating,
      'comment': comment,
    };
    if (reviewerName != null && reviewerName.trim().isNotEmpty) {
      final name = reviewerName.trim();
      payload['name'] = name;
      payload['user_name'] = name;
      payload['userName'] = name;
      payload['reviewer_name'] = name;
    }

    final response = await _client.post(
      Uri.parse('${ApiConstants.baseUrl}/products/$id/reviews'),
      headers: await _authHeaders(),
      body: jsonEncode(payload),
    );
    _checkStatus(response);
  }

  Future<List<String>> getWishlist() async {
    final response = await _client.get(
      Uri.parse('${ApiConstants.baseUrl}/wishlist/'),
      headers: await _authHeaders(),
    );
    _checkStatus(response);
    final decoded = jsonDecode(response.body);
    
    // Attempt to extract product IDs from response
    List items = [];
    if (decoded is List) {
      items = decoded;
    } else if (decoded is Map<String, dynamic>) {
      items = decoded['wishlist'] ?? decoded['items'] ?? decoded['results'] ?? [];
    }

    return items.map((item) {
      if (item is String) return item;
      if (item is Map) {
        if (item.containsKey('product_id')) return item['product_id'].toString();
        if (item.containsKey('id')) return item['id'].toString();
        if (item.containsKey('product') && item['product'] is Map) return item['product']['id'].toString();
      }
      return item.toString();
    }).toList();
  }

  Future<void> addToWishlist(String productId) async {
    final response = await _client.post(
      Uri.parse('${ApiConstants.baseUrl}/wishlist/'),
      headers: await _authHeaders(),
      body: jsonEncode({'productId': productId}),
    );
    _checkStatus(response);
  }

  Future<void> removeFromWishlist(String productId) async {
    final response = await _client.delete(
      Uri.parse('${ApiConstants.baseUrl}/wishlist/$productId'),
      headers: await _authHeaders(),
    );
    _checkStatus(response);
  }

  List<Product> _decodeProductsResponse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Product.fromJson)
          .toList();
    }

    if (decoded is Map<String, dynamic>) {
      final items = decoded['products'] ?? decoded['results'] ?? [];
      if (items is List) {
        return items
            .whereType<Map<String, dynamic>>()
            .map(Product.fromJson)
            .toList();
      }
    }

    throw const FormatException('Products response was not a list or wrapped list');
  }

  void _checkStatus(http.Response response) {
    if (response.statusCode == 401) {
      throw Exception('Session expired. Please log in again.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String errorMessage = 'API error ${response.statusCode}: ${response.reasonPhrase}';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body.containsKey('message')) {
          errorMessage = body['message'];
        } else if (body is Map && body.containsKey('detail')) {
          errorMessage = body['detail'];
        }
      } catch (_) {
        // ignore
      }
      throw Exception(errorMessage);
    }
  }
}
