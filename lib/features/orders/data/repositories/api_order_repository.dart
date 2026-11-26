import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/order_model.dart';
import 'order_repository.dart';
import 'package:bems_farms/features/auth/data/repositories/token_storage.dart';
import 'package:bems_farms/core/network/api_constants.dart';

class ApiOrderRepository implements OrderRepository {
  static const String baseUrl = '${ApiConstants.baseUrl}/orders';
  final TokenStorage _tokenStorage = TokenStorage();
  final http.Client _client;

  ApiOrderRepository({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, String>> _getHeaders({bool includeAuth = true}) async {
    if (includeAuth) {
      final token = await _tokenStorage.getToken() ?? '';
      return ApiConstants.authHeaders(token);
    }
    return ApiConstants.defaultHeaders();
  }

  void _checkStatus(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String errorMessage = 'API error ${response.statusCode}';
      try {
        final body = jsonDecode(response.body);
        if (body is Map) {
          errorMessage = body['message'] ?? body['error'] ?? body['detail'] ?? errorMessage;
        }
      } catch (_) {
        if (response.body.isNotEmpty && !response.body.contains('<html')) {
          errorMessage = response.body;
        }
      }
      throw Exception(errorMessage);
    }
  }

  @override
  Future<Map<String, dynamic>> createCheckoutIntent(List<Map<String, dynamic>> cartItems) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/checkout-intent'),
      headers: await _getHeaders(),
      body: jsonEncode({'items': cartItems}),
    );
    _checkStatus(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> getCheckoutIntent(String intentId) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/checkout-intent/$intentId'),
      headers: await _getHeaders(),
    );
    _checkStatus(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  @override
  Future<Order> placeOrder({
    required List<Map<String, dynamic>> items,
    required String deliveryAddress,
    String? deliveryPhone,
    required double deliveryFee,
    required String paymentMethod,
    String? couponCode,
    double? deliveryLat,
    double? deliveryLng,
    String? checkoutIntentId,
    String? paymentRef,
    String? zoneId,
    String? paymentPin,
  }) async {
    final payload = {
      'items': items,
      'delivery_address': deliveryAddress,
      if (deliveryPhone != null) 'delivery_phone': deliveryPhone,
      'delivery_fee': deliveryFee,
      if (zoneId != null) 'zone_id': zoneId,
      'payment_method': (paymentMethod == 'card' || paymentMethod == 'monnify') ? 'monnify' : paymentMethod,
      if (paymentPin != null && paymentPin.isNotEmpty) 'payment_pin': paymentPin,
      if (couponCode != null && couponCode.trim().isNotEmpty) 'coupon_code': couponCode.trim(),
      if (deliveryLat != null) 'delivery_lat': deliveryLat,
      if (deliveryLng != null) 'delivery_lng': deliveryLng,
      if (deliveryLat != null) 'latitude': deliveryLat,
      if (deliveryLng != null) 'longitude': deliveryLng,
      if (checkoutIntentId != null) 'checkout_intent_id': checkoutIntentId,
      if (paymentRef != null) 'payment_ref': paymentRef,
      if (paymentRef != null) 'payment_reference': paymentRef,
    };
    
    final response = await _client.post(
      Uri.parse(baseUrl),
      headers: await _getHeaders(),
      body: jsonEncode(payload),
    );
    _checkStatus(response);
    
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic> && decoded.containsKey('order')) {
      return Order.fromJson(decoded['order'] as Map<String, dynamic>);
    }
    return Order.fromJson(decoded as Map<String, dynamic>);
  }

  @override
  Future<bool> verifyPayment(String reference) async {
    try {
      final response = await _client.get(
        Uri.parse('${ApiConstants.baseUrl}/payments/verify/$reference'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final status = (decoded['status'] ?? decoded['paymentStatus'] ?? decoded['data']?['status'])?.toString().toUpperCase();
        return status == 'PAID' || status == 'SUCCESS' || status == 'SUCCESSFUL';
      }
    } catch (_) {}
    return false;
  }

  @override
  Future<List<Order>> getMyOrders({int page = 1, int limit = 20}) async {
    final uri = Uri.parse(baseUrl).replace(queryParameters: {
      'page': page.toString(),
      'limit': limit.toString(),
    });
    final response = await _client.get(uri, headers: await _getHeaders());
    _checkStatus(response);
    
    final decoded = jsonDecode(response.body);
    List items = [];
    if (decoded is List) {
      items = decoded;
    } else if (decoded is Map<String, dynamic>) {
      items = decoded['orders'] ?? decoded['results'] ?? [];
    }
    return items.whereType<Map<String, dynamic>>().map((json) => Order.fromJson(json)).toList();
  }

  @override
  Future<Order> getOrderById(String id) async {
    final response = await _client.get(Uri.parse('$baseUrl/$id'), headers: await _getHeaders());
    _checkStatus(response);
    
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic> && decoded.containsKey('order')) {
      return Order.fromJson(decoded['order'] as Map<String, dynamic>);
    }
    return Order.fromJson(decoded as Map<String, dynamic>);
  }

  @override
  Future<Map<String, dynamic>> trackOrder(String trackingCode) async {
    final cleanCode = trackingCode.replaceAll('#', '').trim();
    final response = await _client.get(
      Uri.parse('$baseUrl/track/$cleanCode'),
      headers: await _getHeaders(includeAuth: true),
    );
    _checkStatus(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  @override
  Future<void> cancelOrder(String orderId, String reason) async {
    final response = await _client.patch(
      Uri.parse('$baseUrl/$orderId/cancel'),
      headers: await _getHeaders(),
      body: jsonEncode({'reason': reason}),
    );
    _checkStatus(response);
  }

  @override
  Future<Order> confirmDelivery(String orderId) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/$orderId/confirm-receipt'),
      headers: await _getHeaders(),
    );
    _checkStatus(response);
    
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic> && decoded.containsKey('order')) {
      return Order.fromJson(decoded['order'] as Map<String, dynamic>);
    }
    return Order.fromJson(decoded as Map<String, dynamic>);
  }

  @override
  Future<void> reportIssue(String orderId, String reason) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/$orderId/report'),
      headers: await _getHeaders(),
      body: jsonEncode({'reason': reason}),
    );
    _checkStatus(response);
  }

  @override
  Future<void> initiateReturn(String orderId, String reason, List<Map<String, dynamic>> items, Map<String, dynamic>? refundAccount) async {
    final payload = {
      'reason': reason,
      'items': items,
    };
    if (refundAccount != null) {
      payload['refund_account'] = refundAccount;
    }
    final response = await _client.post(
      Uri.parse('$baseUrl/returns'),
      headers: await _getHeaders(),
      body: jsonEncode(payload),
    );
    _checkStatus(response);
  }

  @override
  Future<List<Map<String, dynamic>>> getReturns({int page = 1, int limit = 20}) async {
    final uri = Uri.parse('$baseUrl/returns').replace(queryParameters: {
      'page': page.toString(),
      'limit': limit.toString(),
    });
    final response = await _client.get(uri, headers: await _getHeaders());
    _checkStatus(response);
    
    final decoded = jsonDecode(response.body);
    if (decoded is List) return decoded.whereType<Map<String, dynamic>>().toList();
    if (decoded is Map<String, dynamic>) {
      final items = decoded['returns'] ?? decoded['results'] ?? [];
      if (items is List) return items.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }
}
