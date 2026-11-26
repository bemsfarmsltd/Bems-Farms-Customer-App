import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:bems_farms/core/network/api_constants.dart';
import 'package:bems_farms/features/auth/data/repositories/token_storage.dart';
import 'package:bems_farms/features/cart/data/models/cart_item_model.dart';

class CartRepository {
  final http.Client _client;
  final TokenStorage _tokenStorage;
  static const String _cartBaseUrl = '${ApiConstants.baseUrl}/cart';

  CartRepository({http.Client? client, TokenStorage? tokenStorage})
      : _client = client ?? http.Client(),
        _tokenStorage = tokenStorage ?? TokenStorage();

  Future<Map<String, String>> _headers({bool requireAuth = false}) async {
    final token = await _tokenStorage.getToken() ?? '';
    if (token.isNotEmpty) {
      return ApiConstants.authHeaders(token);
    }
    return ApiConstants.defaultHeaders();
  }

  void _checkStatus(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String errorMessage = 'API error ${response.statusCode}';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body.containsKey('message')) {
          errorMessage = body['message'];
        }
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }

  // ==========================================
  // SERVER-SIDE CART ENDPOINTS (/api/cart)
  // ==========================================

  /// 1. GET /api/cart
  /// Reads active cart for the customer with live prices and stock
  Future<List<CartItem>> getCart() async {
    try {
      final response = await _client.get(
        Uri.parse(_cartBaseUrl),
        headers: await _headers(),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List itemsJson = [];
        if (decoded is List) {
          itemsJson = decoded;
        } else if (decoded is Map<String, dynamic>) {
          if (decoded['cart'] is Map && decoded['cart']['items'] is List) {
            itemsJson = decoded['cart']['items'];
          } else if (decoded['items'] is List) {
            itemsJson = decoded['items'];
          } else if (decoded['data'] is Map && decoded['data']['items'] is List) {
            itemsJson = decoded['data']['items'];
          } else if (decoded['data'] is List) {
            itemsJson = decoded['data'];
          }
        }
        return itemsJson.map((e) => CartItem.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('getCart server error: $e');
    }
    return [];
  }

  /// 2. POST /api/cart/items
  /// Adds item or increments quantity, capped by available stock
  Future<Map<String, dynamic>?> addToCartItem(String productId, int quantity) async {
    try {
      final numericId = int.tryParse(productId);
      final response = await _client.post(
        Uri.parse('$_cartBaseUrl/items'),
        headers: await _headers(),
        body: jsonEncode({
          'productId': numericId ?? productId,
          'product_id': numericId ?? productId,
          'quantity': quantity,
        }),
      );
      _checkStatus(response);
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('addToCartItem server error: $e');
      rethrow;
    }
  }

  /// 3. PATCH /api/cart/items/{productId}
  /// Updates quantity in backend database (Setting quantity: 0 automatically removes the item)
  Future<Map<String, dynamic>?> updateCartItem(String productId, int quantity) async {
    try {
      final response = await _client.patch(
        Uri.parse('$_cartBaseUrl/items/$productId'),
        headers: await _headers(),
        body: jsonEncode({'quantity': quantity}),
      );
      _checkStatus(response);
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('updateCartItem server error: $e');
      rethrow;
    }
  }

  /// 4. DELETE /api/cart/items/{productId}
  /// Removes product completely from customer's database cart
  Future<void> removeCartItem(String productId) async {
    try {
      final response = await _client.delete(
        Uri.parse('$_cartBaseUrl/items/$productId'),
        headers: await _headers(),
      );
      _checkStatus(response);
    } catch (e) {
      debugPrint('removeCartItem server error: $e');
    }
  }

  /// DELETE /api/cart
  /// Empties the entire server cart
  Future<void> clearCartServer() async {
    try {
      final response = await _client.delete(
        Uri.parse(_cartBaseUrl),
        headers: await _headers(),
      );
      _checkStatus(response);
    } catch (e) {
      debugPrint('clearCartServer error: $e');
    }
  }

  /// 5. POST /api/cart/sync
  /// Merges guest cart items added prior to login into user's account in database
  Future<void> syncCart(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    try {
      final headers = await _headers(requireAuth: true);
      final formattedItems = items.map((item) {
        final rawId = item['productId'] ?? item['product_id'];
        final numericId = int.tryParse(rawId.toString());
        return {
          'productId': numericId ?? rawId,
          'product_id': numericId ?? rawId,
          'quantity': item['quantity'],
        };
      }).toList();

      final res = await _client.post(
        Uri.parse('$_cartBaseUrl/sync'),
        headers: headers,
        body: jsonEncode({'items': formattedItems}),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) return;

      // Fallback fallback to /merge if /sync is an alternative route on backend
      final res2 = await _client.post(
        Uri.parse('$_cartBaseUrl/merge'),
        headers: headers,
        body: jsonEncode({'items': formattedItems}),
      );
      _checkStatus(res2);
    } catch (e) {
      debugPrint('syncCart error: $e');
    }
  }

  /// POST /api/cart/notify
  /// Webhook endpoint for AI Chef orders
  Future<void> notifyAiChefCart(Map<String, dynamic> payload) async {
    try {
      final response = await _client.post(
        Uri.parse('$_cartBaseUrl/notify'),
        headers: await _headers(),
        body: jsonEncode(payload),
      );
      _checkStatus(response);
    } catch (e) {
      debugPrint('notifyAiChefCart error: $e');
    }
  }

  // ==========================================
  // COUPONS, LOCATIONS & ADDRESSES
  // ==========================================

  // POST /api/admin/coupons/validate
  Future<Map<String, dynamic>> validateCoupon(String code, double orderTotal, int customerId) async {
    final response = await _client.post(
      Uri.parse('${ApiConstants.baseUrl}/admin/coupons/validate'),
      headers: await _headers(requireAuth: true),
      body: jsonEncode({
        'code': code,
        'order_total': orderTotal,
        'customer_id': customerId,
      }),
    );
    _checkStatus(response);
    return jsonDecode(response.body);
  }

  // POST /api/locations/verify
  Future<Map<String, dynamic>> verifyDeliveryLocation(String address, String state, double lat, double lng) async {
    final response = await _client.post(
      Uri.parse('${ApiConstants.baseUrl}/locations/verify'),
      headers: await _headers(requireAuth: false),
      body: jsonEncode({
        'address': address,
        'state': state,
        'latitude': lat,
        'longitude': lng,
      }),
    );
    _checkStatus(response);
    return jsonDecode(response.body);
  }

  // GET /api/addresses
  Future<List<Map<String, dynamic>>> getAddresses() async {
    final response = await _client.get(
      Uri.parse('${ApiConstants.baseUrl}/addresses'),
      headers: await _headers(requireAuth: true),
    );
    _checkStatus(response);
    final data = jsonDecode(response.body);
    if (data is List) return data.whereType<Map<String, dynamic>>().toList();
    if (data is Map && data.containsKey('addresses')) {
      return (data['addresses'] as List).whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  // POST /api/addresses
  Future<Map<String, dynamic>> saveAddress(Map<String, dynamic> addressData) async {
    final response = await _client.post(
      Uri.parse('${ApiConstants.baseUrl}/addresses'),
      headers: await _headers(requireAuth: true),
      body: jsonEncode(addressData),
    );
    _checkStatus(response);
    return jsonDecode(response.body);
  }

  // Legacy AI cart helpers
  Future<void> aiCartWebhook(Map<String, dynamic> payload) async {
    await notifyAiChefCart(payload);
  }

  Future<List<Map<String, dynamic>>> getPendingCartAdditions() async {
    try {
      final response = await _client.get(
        Uri.parse('${ApiConstants.baseUrl}/ai/cart/pending'),
        headers: await _headers(requireAuth: true),
      );
      _checkStatus(response);
      final data = jsonDecode(response.body);
      if (data is List) return data.whereType<Map<String, dynamic>>().toList();
      if (data is Map && data.containsKey('items')) {
        return (data['items'] as List).whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return [];
  }
}
