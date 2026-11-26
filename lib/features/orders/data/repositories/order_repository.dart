import '../models/order_model.dart';

abstract class OrderRepository {
  Future<Map<String, dynamic>> createCheckoutIntent(List<Map<String, dynamic>> cartItems);
  Future<Map<String, dynamic>> getCheckoutIntent(String intentId);
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
  });
  Future<bool> verifyPayment(String reference);
  Future<List<Order>> getMyOrders({int page = 1, int limit = 20});
  Future<Order> getOrderById(String id);
  Future<Map<String, dynamic>> trackOrder(String trackingCode);
  Future<void> cancelOrder(String orderId, String reason);
  Future<Order> confirmDelivery(String orderId);
  Future<void> reportIssue(String orderId, String reason);
  Future<void> initiateReturn(String orderId, String reason, List<Map<String, dynamic>> items, Map<String, dynamic>? refundAccount);
  Future<List<Map<String, dynamic>>> getReturns({int page = 1, int limit = 20});
}
