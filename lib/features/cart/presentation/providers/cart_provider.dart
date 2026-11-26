import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bems_farms/features/cart/data/models/cart_item_model.dart';
import 'package:bems_farms/features/cart/data/repositories/cart_repository.dart';
import 'package:bems_farms/features/product/data/models/product_model.dart';

class CartNotifier extends StateNotifier<List<CartItem>> {
  static const _key = 'user_cart';
  final CartRepository _cartRepo;

  CartNotifier({CartRepository? cartRepo})
      : _cartRepo = cartRepo ?? CartRepository(),
        super([]) {
    _initCart();
  }

  Future<void> _initCart() async {
    // 1. Load instantly from local storage for offline / quick display
    await _loadLocalCart();

    // 2. Fetch live active cart from PostgreSQL database backend
    await refreshServerCart();
  }

  Future<void> _loadLocalCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString(_key);
      if (savedJson != null) {
        final List<dynamic> decodedList = jsonDecode(savedJson);
        state = decodedList.map((item) => CartItem.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error loading local cart: $e');
    }
  }

  Future<void> _saveLocalCart(List<CartItem> cartItems) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encodedList = jsonEncode(cartItems.map((e) => e.toJson()).toList());
      await prefs.setString(_key, encodedList);
    } catch (e) {
      debugPrint('Error saving local cart: $e');
    }
  }

  /// Refreshes cart from the server (GET /api/cart)
  Future<void> refreshServerCart() async {
    try {
      final serverItems = await _cartRepo.getCart();
      if (serverItems.isNotEmpty) {
        state = serverItems;
        await _saveLocalCart(serverItems);
      } else if (state.isNotEmpty) {
        // If server cart is empty but we have local items, sync local items to server!
        await syncGuestCartToServer();
      }
    } catch (e) {
      debugPrint('Failed to refresh server cart: $e');
    }
  }

  /// Syncs local cart to server (POST /api/cart/sync)
  Future<void> syncGuestCartToServer() async {
    if (state.isEmpty) return;
    try {
      final payload = state.map((item) {
        final numericId = int.tryParse(item.product.id);
        return {
          'productId': numericId ?? item.product.id,
          'product_id': numericId ?? item.product.id,
          'quantity': item.quantity,
        };
      }).toList();
      await _cartRepo.syncCart(payload);
    } catch (e) {
      debugPrint('Error syncing guest cart: $e');
    }
  }

  /// Adds an item or increments quantity (POST /api/cart/items)
  void addToCart(Product product, int quantity) {
    final index = state.indexWhere((item) => item.product.id == product.id);
    
    if (index >= 0) {
      final currentItem = state[index];
      // Cap by stock if available
      int newQty = currentItem.quantity + quantity;
      if (product.stock > 0 && newQty > product.stock) {
        newQty = product.stock;
      }
      final updatedItem = currentItem.copyWith(quantity: newQty);
      state = [
        ...state.sublist(0, index),
        updatedItem,
        ...state.sublist(index + 1),
      ];
    } else {
      int initialQty = quantity;
      if (product.stock > 0 && initialQty > product.stock) {
        initialQty = product.stock;
      }
      state = [...state, CartItem(product: product, quantity: initialQty)];
    }
    _saveLocalCart(state);

    // Sync to PostgreSQL backend
    _cartRepo.addToCartItem(product.id, quantity).catchError((e) {
      debugPrint('Server add item error: $e');
      return null;
    });
  }

  /// Removes an item completely (DELETE /api/cart/items/:productId)
  void removeFromCart(String productId) {
    state = state.where((item) => item.product.id != productId).toList();
    _saveLocalCart(state);

    // Sync to PostgreSQL backend
    _cartRepo.removeCartItem(productId);
  }

  /// Updates quantity in the database (PATCH /api/cart/items/:productId)
  void updateQuantity(String productId, int newQuantity) {
    if (newQuantity <= 0) {
      removeFromCart(productId);
      return;
    }

    final index = state.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      final currentProduct = state[index].product;
      int clampedQty = newQuantity;
      if (currentProduct.stock > 0 && clampedQty > currentProduct.stock) {
        clampedQty = currentProduct.stock;
      }

      final updatedItem = state[index].copyWith(quantity: clampedQty);
      state = [
        ...state.sublist(0, index),
        updatedItem,
        ...state.sublist(index + 1),
      ];
    }
    _saveLocalCart(state);

    // Sync to PostgreSQL backend
    _cartRepo.updateCartItem(productId, newQuantity).catchError((e) {
      debugPrint('Server update quantity error: $e');
      return null;
    });
  }

  /// Empties the cart (DELETE /api/cart)
  void clearCart() {
    state = [];
    _saveLocalCart(state);

    // Sync to PostgreSQL backend
    _cartRepo.clearCartServer();
  }

  int get totalItems => state.fold(0, (sum, item) => sum + item.quantity);
  
  double get subtotal => state.fold(0.0, (sum, item) => sum + item.totalPrice);
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
});
