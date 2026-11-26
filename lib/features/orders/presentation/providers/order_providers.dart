import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/order_model.dart';
import '../../data/repositories/api_order_repository.dart';
import '../../data/repositories/order_repository.dart';

// ─── Repository Provider ────────────────────────────────────────────────────
// 🔁 TO SWAP TO REAL API: Replace ApiOrderRepository() with your real
//    HttpOrderRepository() — nothing else changes.
final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => ApiOrderRepository(),
);

// ─── Orders List ────────────────────────────────────────────────────────────
class OrdersNotifier extends AsyncNotifier<List<Order>> {
  @override
  Future<List<Order>> build() => _fetch();

  Future<List<Order>> _fetch() =>
      ref.read(orderRepositoryProvider).getMyOrders();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Silently update state in background without full-screen loading spinner
  Future<void> refreshSilently() async {
    final updated = await AsyncValue.guard(_fetch);
    if (updated.hasValue) {
      state = updated;
    }
  }

  /// Called by CheckoutPage after a successful payment.
  Future<Order?> placeOrder({
    required List<Map<String, dynamic>> items,
    required String deliveryAddress,
    required double deliveryFee,
    required String paymentMethod,
    String? couponCode,
    String? checkoutIntentId,
    String? paymentRef,
  }) async {
    final repo = ref.read(orderRepositoryProvider);
    try {
      final order = await repo.placeOrder(
        items: items,
        deliveryAddress: deliveryAddress,
        deliveryFee: deliveryFee,
        paymentMethod: paymentMethod,
        couponCode: couponCode,
        checkoutIntentId: checkoutIntentId,
        paymentRef: paymentRef,
      );
      // Prepend to local list without a full network round-trip
      state = AsyncData([order, ...state.valueOrNull ?? []]);
      return order;
    } catch (e) {
      return null;
    }
  }

  /// Called from OrderDetailPage when customer taps "Confirm Delivery".
  Future<void> confirmDelivery(String orderId) async {
    final repo = ref.read(orderRepositoryProvider);
    final updated = await repo.confirmDelivery(orderId);
    state = AsyncData(
      state.valueOrNull
              ?.map((o) => o.id == orderId ? updated : o)
              .toList() ??
          [],
    );
  }

  /// Called from OrderDetailPage when customer taps "Report Issue".
  Future<void> reportIssue(String orderId, String reason) async {
    await ref.read(orderRepositoryProvider).reportIssue(orderId, reason);
  }

  /// Called when customer cancels an order
  Future<void> cancelOrder(String orderId, String reason) async {
    await ref.read(orderRepositoryProvider).cancelOrder(orderId, reason);
    // After cancel, refresh the list to get updated status
    await refresh();
  }
}

final ordersProvider =
    AsyncNotifierProvider<OrdersNotifier, List<Order>>(OrdersNotifier.new);

// ─── Single Order (derived from list — no extra network call) ───────────────
final orderByIdProvider = Provider.family<Order?, String>((ref, id) {
  final orders = ref.watch(ordersProvider).valueOrNull ?? [];
  try {
    return orders.firstWhere((o) => o.id == id);
  } catch (_) {
    return null;
  }
});
