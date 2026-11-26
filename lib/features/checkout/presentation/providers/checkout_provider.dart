import 'package:url_launcher/url_launcher.dart';
import 'package:bems_farms/features/auth/data/repositories/token_storage.dart';
import 'package:bems_farms/features/orders/data/models/order_model.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:bems_farms/core/network/api_constants.dart';
import 'package:bems_farms/features/cart/presentation/providers/cart_provider.dart';
import 'package:bems_farms/features/cart/presentation/providers/cart_repo_provider.dart';
import 'package:bems_farms/features/orders/presentation/providers/order_providers.dart';
import 'package:bems_farms/features/profile/presentation/providers/address_provider.dart';
import 'package:bems_farms/features/auth/presentation/providers/auth_providers.dart';

class CheckoutState {
  final String? selectedAddressId;
  final bool isEnteringNewAddress;
  final String selectedPaymentMethod; // 'card' or 'cod'
  final String? couponCode;
  final double discountAmount;
  final double deliveryFee;
  final String? deliveryOptionName;
  final String? deliveryEta;
  final String? zoneId;
  final bool isVerified;
  final bool isProcessing;
  final String? checkoutIntentId;
  final String? paymentRef;
  final String? checkoutUrl;
  final Order? placedOrder;
  final Map<String, dynamic>? newAddressForm;
  final bool isCodEnabled;
  final String? errorMessage;

  CheckoutState({
    this.selectedAddressId,
    this.isEnteringNewAddress = false,
    this.selectedPaymentMethod = 'card',
    this.couponCode,
    this.discountAmount = 0.0,
    this.deliveryFee = 1000.0, // Standard default per spec Rule 2
    this.deliveryOptionName,
    this.deliveryEta,
    this.zoneId,
    this.isVerified = false,
    this.isProcessing = false,
    this.checkoutIntentId,
    this.paymentRef,
    this.checkoutUrl,
    this.placedOrder,
    this.newAddressForm,
    this.isCodEnabled = true,
    this.errorMessage,
  });

  CheckoutState copyWith({
    String? selectedAddressId,
    bool? isEnteringNewAddress,
    String? selectedPaymentMethod,
    String? couponCode,
    double? discountAmount,
    double? deliveryFee,
    String? deliveryOptionName,
    String? deliveryEta,
    String? zoneId,
    bool? isVerified,
    bool? isProcessing,
    String? checkoutIntentId,
    String? paymentRef,
    String? checkoutUrl,
    Order? placedOrder,
    Map<String, dynamic>? newAddressForm,
    bool? isCodEnabled,
    String? errorMessage,
  }) {
    return CheckoutState(
      selectedAddressId: selectedAddressId ?? this.selectedAddressId,
      isEnteringNewAddress: isEnteringNewAddress ?? this.isEnteringNewAddress,
      selectedPaymentMethod: selectedPaymentMethod ?? this.selectedPaymentMethod,
      couponCode: couponCode ?? this.couponCode,
      discountAmount: discountAmount ?? this.discountAmount,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      deliveryOptionName: deliveryOptionName ?? this.deliveryOptionName,
      deliveryEta: deliveryEta ?? this.deliveryEta,
      zoneId: zoneId ?? this.zoneId,
      isVerified: isVerified ?? this.isVerified,
      isProcessing: isProcessing ?? this.isProcessing,
      checkoutIntentId: checkoutIntentId ?? this.checkoutIntentId,
      paymentRef: paymentRef ?? this.paymentRef,
      checkoutUrl: checkoutUrl ?? this.checkoutUrl,
      placedOrder: placedOrder ?? this.placedOrder,
      newAddressForm: newAddressForm ?? this.newAddressForm,
      isCodEnabled: isCodEnabled ?? this.isCodEnabled,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class CheckoutNotifier extends StateNotifier<CheckoutState> {
  final Ref ref;

  CheckoutNotifier(this.ref) : super(CheckoutState()) {
    // Attempt to select the default address initially
    final addresses = ref.read(addressProvider).valueOrNull ?? [];
    if (addresses.isNotEmpty) {
      final defaultAddr = addresses.firstWhere((a) => a.isDefault, orElse: () => addresses.first);
      state = state.copyWith(selectedAddressId: defaultAddr.id);
      verifyLocation(
        defaultAddr.street,
        defaultAddr.state,
        defaultAddr.latitude ?? 0.0,
        defaultAddr.longitude ?? 0.0,
        city: defaultAddr.city,
      );
    }
  }

  /// Step 2 of Specification: Monnify Gateway Checkout Intent
  /// Locks total amount, zone_id, and delivery_fee into the server
  Future<void> fetchCheckoutIntent() async {
    try {
      final cartItems = ref.read(cartProvider);
      if (cartItems.isEmpty) return;

      final mappedItems = cartItems.map((c) => {
        'product_id': int.tryParse(c.product.id) ?? c.product.id,
        'quantity': c.quantity,
        'price': c.product.price,
      }).toList();

      // Gather current address coordinates
      double? lat;
      double? lng;
      String addressStr = 'Nigeria';
      String cityStr = 'Aba';
      String stateStr = 'Abia';

      if (state.isEnteringNewAddress && state.newAddressForm != null) {
        final form = state.newAddressForm!;
        addressStr = form['street']?.toString() ?? addressStr;
        cityStr = form['city']?.toString() ?? cityStr;
        stateStr = form['state']?.toString() ?? stateStr;
        lat = double.tryParse(form['latitude']?.toString() ?? '');
        lng = double.tryParse(form['longitude']?.toString() ?? '');
      } else {
        final addresses = ref.read(addressProvider).valueOrNull ?? [];
        if (addresses.isNotEmpty) {
          final addr = addresses.firstWhere(
            (a) => a.id == state.selectedAddressId,
            orElse: () => addresses.first,
          );
          addressStr = addr.street;
          cityStr = addr.city;
          stateStr = addr.state;
          lat = addr.latitude;
          lng = addr.longitude;
        }
      }

      final payload = {
        'items': mappedItems,
        'address': addressStr,
        'city': cityStr,
        'state': stateStr,
        if (lat != null) 'latitude': lat,
        if (lng != null) 'longitude': lng,
        if (state.zoneId != null && state.zoneId!.isNotEmpty) 'zone_id': state.zoneId,
        'delivery_fee': state.deliveryFee,
        if (state.couponCode != null && state.couponCode!.trim().isNotEmpty)
          'coupon_code': state.couponCode!.trim(),
        'payment_method': 'monnify',
      };

      final token = await TokenStorage().getToken();
      final headers = token != null && token.isNotEmpty
          ? ApiConstants.authHeaders(token)
          : ApiConstants.defaultHeaders();

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/orders/checkout-intent'),
        headers: headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> decoded = jsonDecode(response.body);
        final data = decoded['data'] is Map<String, dynamic>
            ? decoded['data'] as Map<String, dynamic>
            : decoded;
        final intentId = data['intentId']?.toString() ??
            data['intent_id']?.toString() ??
            data['id']?.toString();

        String? paymentRef = data['transactionReference']?.toString() ??
            data['transaction_ref']?.toString() ??
            data['paymentReference']?.toString() ??
            data['payment_ref']?.toString() ??
            data['reference']?.toString();

        String? checkoutUrl = data['checkoutUrl']?.toString() ??
            data['checkout_url']?.toString() ??
            data['payment_url']?.toString() ??
            data['paymentUrl']?.toString() ??
            data['redirect_url']?.toString() ??
            data['redirectUrl']?.toString();

        double currentFee = state.deliveryFee;
        if (data.containsKey('delivery_fee') || data.containsKey('deliveryFee')) {
          currentFee = double.tryParse(
                data['delivery_fee']?.toString() ?? data['deliveryFee']?.toString() ?? '',
              ) ??
              state.deliveryFee;
        }

        // Option A fallback: If checkout-intent did not return checkoutUrl, call /api/payments/initialize
        if (checkoutUrl == null || checkoutUrl.isEmpty) {
          try {
            final user = ref.read(authProvider).valueOrNull;
            final subtotal = cartItems.fold<double>(0.0, (s, i) => s + (i.product.price * i.quantity));
            final totalAmt = subtotal + currentFee - state.discountAmount;

            final initPayload = {
              if (intentId != null && intentId.isNotEmpty) 'checkout_intent_id': intentId,
              'amount': totalAmt.round(),
              'customerEmail': user?.email ?? 'customer@bemsfarms.com',
              'customerName': user?.name ?? 'Customer',
              if (user?.phone?.isNotEmpty == true) 'customerPhone': user!.phone,
              'redirect_url': 'https://bemsfarms.com/checkout/callback',
            };

            final initResp = await http.post(
              Uri.parse('${ApiConstants.baseUrl}/payments/initialize'),
              headers: headers,
              body: jsonEncode(initPayload),
            );

            if (initResp.statusCode >= 200 && initResp.statusCode < 300) {
              final initDecoded = jsonDecode(initResp.body);
              final initData = initDecoded['data'] is Map<String, dynamic>
                  ? initDecoded['data']
                  : initDecoded;
              checkoutUrl = initData['checkoutUrl']?.toString() ?? initData['checkout_url']?.toString();
              paymentRef ??= initData['transactionReference']?.toString() ??
                  initData['paymentReference']?.toString() ??
                  initData['payment_ref']?.toString();
            } else {
              debugPrint('payments/initialize status: ${initResp.statusCode}, body: ${initResp.body}');
            }
          } catch (initErr) {
            debugPrint('payments/initialize error: $initErr');
          }
        }

        state = state.copyWith(
          deliveryFee: currentFee,
          checkoutIntentId: intentId ?? state.checkoutIntentId,
          paymentRef: paymentRef ?? state.paymentRef,
          checkoutUrl: checkoutUrl ?? state.checkoutUrl,
        );
      } else {
        String serverErr = 'Checkout error (${response.statusCode})';
        try {
          final b = jsonDecode(response.body);
          serverErr = b['message'] ?? b['error'] ?? serverErr;
        } catch (_) {
          if (response.body.isNotEmpty && !response.body.contains('<html')) serverErr = response.body;
        }
        state = state.copyWith(errorMessage: serverErr);
        debugPrint('fetchCheckoutIntent server error: $serverErr');
      }
    } catch (e) {
      final err = e.toString().replaceFirst('Exception: ', '').trim();
      state = state.copyWith(errorMessage: err);
      debugPrint('Failed to fetch checkout intent: $err');
    }
  }

  /// Step 1 of Specification: Location Verification & Zone Mapping (POST /api/locations/verify)
  Future<void> verifyLocation(
    String addressStr,
    String stateStr,
    double lat,
    double lng, {
    String? city,
  }) async {
    // 1. QA Test Zone Mode (Rule 1 of spec):
    // If user enters 'test' in address, city, or state, assign ₦0 delivery fee
    final checkLower = '$addressStr $stateStr ${city ?? ''}'.toLowerCase();
    if (checkLower.contains('test')) {
      state = state.copyWith(
        deliveryFee: 0.0,
        deliveryOptionName: 'Test Zone (QA Free Delivery)',
        deliveryEta: 'Instant Dispatch',
        zoneId: 'ZONE_TEST',
        isVerified: true,
      );
      return;
    }

    try {
      final payload = {
        'address': addressStr,
        'city': city ?? '',
        'state': stateStr,
        'latitude': lat != 0.0 ? lat : null,
        'longitude': lng != 0.0 ? lng : null,
      };

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/locations/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] ?? decoded;

        var zoneData = data;
        if (data['zone'] is Map) {
          zoneData = data['zone'];
        }

        final feeStr = zoneData['delivery_fee']?.toString() ??
            zoneData['fee']?.toString() ??
            data['delivery_fee']?.toString() ??
            '1000';
        final fee = double.tryParse(feeStr) ?? 1000.0;

        final zoneId = zoneData['zone_id']?.toString() ?? data['zone_id']?.toString();
        final name = zoneData['zone_name']?.toString() ??
            zoneData['delivery_option_name']?.toString() ??
            data['delivery_option_name']?.toString() ??
            'Nationwide Delivery';
        final eta = zoneData['estimated_delivery_time']?.toString() ??
            zoneData['delivery_eta']?.toString() ??
            zoneData['eta']?.toString() ??
            data['delivery_eta']?.toString() ??
            'Next Day Dispatch';

        final isGpsVerified = decoded['verified'] == true || (lat != 0.0 && lng != 0.0);

        bool isCod = true;
        if (zoneData['cod_enabled'] == false || 
            zoneData['is_cod_available'] == false || 
            zoneData['allow_cod'] == false ||
            data['cod_enabled'] == false ||
            data['is_cod_available'] == false ||
            data['allow_cod'] == false) {
          isCod = false;
        }

        state = state.copyWith(
          deliveryFee: fee,
          deliveryOptionName: name,
          deliveryEta: eta,
          zoneId: zoneId,
          isVerified: isGpsVerified,
          isCodEnabled: isCod,
          selectedPaymentMethod: (!isCod && state.selectedPaymentMethod == 'cod') ? 'card' : state.selectedPaymentMethod,
        );
      } else {
        // Fallback using Haversine algorithm & Zone Matrix from Section 3 & 4
        _applyLocalHaversineFallback(addressStr, stateStr, lat, lng);
      }
    } catch (e) {
      debugPrint('verifyLocation error: $e');
      _applyLocalHaversineFallback(addressStr, stateStr, lat, lng);
    }
  }

  /// Haversine algorithm (Section 4) & Master Lookup Table (Section 3) client fallback
  void _applyLocalHaversineFallback(String address, String stateStr, double lat, double lng) {
    if (lat == 0.0 || lng == 0.0) {
      state = state.copyWith(
        deliveryFee: 1000.0,
        deliveryOptionName: 'Standard Nationwide Delivery',
        deliveryEta: '2-3 Business Days',
        isVerified: false,
      );
      return;
    }

    final s = stateStr.toLowerCase();
    double baseFee;
    double kmRate;
    double hubLat;
    double hubLng;
    String zoneName;
    String zoneId;

    if (s.contains('abia') || s.contains('umuahia')) {
      baseFee = 600;
      kmRate = 80;
      hubLat = 5.5255;
      hubLng = 7.4916;
      zoneName = 'Umuahia Urban & Metro';
      zoneId = 'ZONE001';
    } else if (s.contains('aba')) {
      baseFee = 1800;
      kmRate = 90;
      hubLat = 5.1065;
      hubLng = 7.3667;
      zoneName = 'Aba Commercial Metro';
      zoneId = 'ZONE002';
    } else if (s.contains('rivers') ||
        s.contains('enugu') ||
        s.contains('imo') ||
        s.contains('anambra') ||
        s.contains('ebonyi') ||
        s.contains('delta') ||
        s.contains('akwa ibom') ||
        s.contains('cross river') ||
        s.contains('bayelsa')) {
      baseFee = 3500;
      kmRate = 40;
      hubLat = 5.0000;
      hubLng = 7.0000;
      zoneName = 'Southeast & South-South Express';
      zoneId = 'ZONE004';
    } else {
      baseFee = 6000;
      kmRate = 15;
      hubLat = 9.0765;
      hubLng = 7.3986;
      zoneName = 'Nationwide Express';
      zoneId = 'ZONE005';
    }

    final distKm = _haversineKm(lat, lng, hubLat, hubLng);
    final distanceFee = (distKm * kmRate).roundToDouble();
    final totalFee = baseFee + distanceFee;

    state = state.copyWith(
      deliveryFee: totalFee,
      deliveryOptionName: zoneName,
      deliveryEta: 'Next Day Dispatch',
      zoneId: zoneId,
      isVerified: true,
    );
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = (lat2 - lat1) * (math.pi / 180.0);
    final dLon = (lon2 - lon1) * (math.pi / 180.0);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180.0)) *
            math.cos(lat2 * (math.pi / 180.0)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return (earthRadiusKm * c * 10).round() / 10;
  }

  void selectAddress(String id) {
    state = state.copyWith(selectedAddressId: id, isEnteringNewAddress: false);
    final addresses = ref.read(addressProvider).valueOrNull ?? [];
    try {
      final addr = addresses.firstWhere((a) => a.id == id);
      verifyLocation(
        addr.street,
        addr.state,
        addr.latitude ?? 0.0,
        addr.longitude ?? 0.0,
        city: addr.city,
      );
    } catch (_) {}
  }

  void toggleNewAddress(bool isNew) {
    state = state.copyWith(isEnteringNewAddress: isNew, selectedAddressId: null);
  }

  void setNewAddressForm(Map<String, dynamic> form, {double? lat, double? lng}) {
    if (lat != null) form['latitude'] = lat;
    if (lng != null) form['longitude'] = lng;
    state = state.copyWith(newAddressForm: form);
    if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
      verifyLocation(
        form['street']?.toString() ?? '',
        form['state']?.toString() ?? '',
        lat,
        lng,
        city: form['city']?.toString(),
      );
    }
  }

  void setPaymentMethod(String method) {
    if (method == 'cod' && !state.isCodEnabled) {
      return; // COD is disabled by backend
    }
    state = state.copyWith(selectedPaymentMethod: method);
  }

  Future<void> applyCoupon(String code, double subtotal) async {
    try {
      state = state.copyWith(isProcessing: true);
      final repo = ref.read(cartRepositoryProvider);
      final result = await repo.validateCoupon(code, subtotal, 1);
      state = state.copyWith(
        couponCode: code,
        discountAmount: double.parse(result['discount']?.toString() ?? '0'),
        isProcessing: false,
      );
    } catch (e) {
      state = state.copyWith(isProcessing: false);
      throw Exception('Invalid coupon code');
    }
  }

  /// Launches the Monnify checkout session in an in-app browser
  Future<String?> launchMonnifyCheckout() async {
    state = state.copyWith(isProcessing: true, errorMessage: null);
    try {
      await fetchCheckoutIntent();
      final url = state.checkoutUrl;
      if (url != null && url.isNotEmpty) {
        final uri = Uri.parse(url);
        try {
          await launchUrl(uri, mode: LaunchMode.inAppWebView);
          state = state.copyWith(isProcessing: false);
          return url;
        } catch (_) {
          try {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            state = state.copyWith(isProcessing: false);
            return url;
          } catch (_) {}
        }
      }
      final err = state.errorMessage ?? 'Unable to open Monnify payment page. Please try again.';
      state = state.copyWith(
        isProcessing: false,
        errorMessage: err,
      );
      return null;
    } catch (e) {
      state = state.copyWith(isProcessing: false, errorMessage: e.toString());
      return null;
    }
  }

  /// Verifies with backend if Monnify payment was successful
  Future<bool> checkPaymentVerification() async {
    final refCode = state.paymentRef;
    if (refCode == null || refCode.isEmpty) return false;
    final orderRepo = ref.read(orderRepositoryProvider);
    return await orderRepo.verifyPayment(refCode);
  }

  /// Step 3 of Specification: Final Order Creation (POST /api/orders)
  Future<bool> confirmOrder({bool isAfterPayment = false, String? paymentPin}) async {
    state = state.copyWith(isProcessing: true, errorMessage: null);
    try {
      final cartItems = ref.read(cartProvider);
      if (cartItems.isEmpty) throw Exception('Your cart is empty');

      final orderRepo = ref.read(orderRepositoryProvider);

      final mappedItems = cartItems.map((c) => {
        'product_id': c.product.id,
        'quantity': c.quantity,
        'price': c.product.price,
      }).toList();

      String deliveryAddressStr = '';
      double? lat;
      double? lng;
      if (state.isEnteringNewAddress && state.newAddressForm != null) {
        final form = state.newAddressForm!;
        deliveryAddressStr = '${form['street']}, ${form['city']}, ${form['state']}';
        lat = double.tryParse(form['latitude']?.toString() ?? '');
        lng = double.tryParse(form['longitude']?.toString() ?? '');
      } else if (state.selectedAddressId != null) {
        final addresses = ref.read(addressProvider).valueOrNull ?? [];
        final addr = addresses.firstWhere(
          (a) => a.id == state.selectedAddressId,
          orElse: () => addresses.first,
        );
        deliveryAddressStr = '${addr.street}, ${addr.city}, ${addr.state}';
        lat = addr.latitude;
        lng = addr.longitude;
      }

      // Fallback if address string is still empty
      if (deliveryAddressStr.trim().isEmpty) {
        final addresses = ref.read(addressProvider).valueOrNull ?? [];
        if (addresses.isNotEmpty) {
          final addr = addresses.firstWhere((a) => a.isDefault, orElse: () => addresses.first);
          deliveryAddressStr = '${addr.street}, ${addr.city}, ${addr.state}';
          lat ??= addr.latitude;
          lng ??= addr.longitude;
        }
      }

      if (deliveryAddressStr.trim().isEmpty) {
        throw Exception('Please select or pin a delivery address');
      }

      final userProfile = ref.read(authProvider).valueOrNull;
      final phone = state.newAddressForm?['phone'] ?? userProfile?.phone ?? '';

      String? paymentRef = state.paymentRef;
      String? intentId = state.checkoutIntentId;
      String method = state.selectedPaymentMethod;

      if (method == 'card' || method == 'monnify') {
        method = 'monnify';
        if (intentId == null || paymentRef == null) {
          await fetchCheckoutIntent();
          paymentRef = state.paymentRef;
          intentId = state.checkoutIntentId;
        }
      } else if (method == 'cod' || method == 'wallet') {
        // Cash on Delivery or Bems Wallet - omit online gateway references
        paymentRef = null;
        intentId = null;
      }

      final placed = await orderRepo.placeOrder(
        items: mappedItems,
        deliveryAddress: deliveryAddressStr,
        deliveryPhone: phone.isNotEmpty ? phone : null,
        deliveryFee: state.deliveryFee,
        zoneId: state.zoneId,
        paymentMethod: method,
        couponCode: state.couponCode,
        deliveryLat: lat,
        deliveryLng: lng,
        checkoutIntentId: intentId,
        paymentRef: paymentRef,
        paymentPin: paymentPin,
      );

      // Clear cart
      ref.read(cartProvider.notifier).clearCart();
      state = state.copyWith(
        isProcessing: false, 
        errorMessage: null,
        placedOrder: placed,
      );
      return true;
    } catch (e) {
      final cleanErr = e.toString().replaceFirst('Exception: ', '').trim();
      state = state.copyWith(isProcessing: false, errorMessage: cleanErr);
      debugPrint('confirmOrder error: $cleanErr');
      return false;
    }
  }
}

final checkoutProvider = StateNotifierProvider<CheckoutNotifier, CheckoutState>((ref) {
  return CheckoutNotifier(ref);
});
