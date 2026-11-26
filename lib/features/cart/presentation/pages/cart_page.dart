import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bems_farms/core/constants/app_colors.dart';
import 'package:bems_farms/features/checkout/presentation/pages/checkout_page.dart';
import 'package:bems_farms/features/auth/presentation/pages/login_page.dart';
import 'package:bems_farms/features/auth/presentation/providers/auth_providers.dart';
import 'package:bems_farms/features/cart/presentation/providers/cart_provider.dart';
import 'package:bems_farms/features/cart/data/models/cart_item_model.dart';
import 'package:bems_farms/features/product/data/models/product_model.dart';
import 'package:bems_farms/features/product/presentation/providers/product_providers.dart';
import 'package:intl/intl.dart';

class CartPage extends ConsumerStatefulWidget {
  const CartPage({super.key});

  @override
  ConsumerState<CartPage> createState() => _CartPageState();
}

class _CartPageState extends ConsumerState<CartPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cartProvider.notifier).refreshServerCart();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartProvider);
    final totalItems = ref.read(cartProvider.notifier).totalItems;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, totalItems),
            const Divider(height: 1, color: AppColors.surface),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.read(cartProvider.notifier).refreshServerCart(),
                color: AppColors.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      if (cartItems.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(40.0),
                          child: Text(
                            'Your basket is empty.',
                            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                          ),
                        )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: cartItems.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.surface),
                        itemBuilder: (context, index) {
                          return _buildCartItem(context, ref, cartItems[index]);
                        },
                      ),
                    
                    if (cartItems.isNotEmpty)
                      const Divider(height: 1, color: AppColors.surface),
                    
                    _buildFrequentlyAddedSection(context, ref, cartItems),
                    
                    if (cartItems.isNotEmpty)
                      _buildSummarySection(context, ref),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildHeader(BuildContext context, int totalItems) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.shopping_bag_outlined, color: AppColors.textPrimary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Your Fresh Basket',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                ),
                Text(
                  '$totalItems items selected',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Icon(Icons.close, size: 16, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(BuildContext context, WidgetRef ref, CartItem item) {
    final formatCurrency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 50,
              height: 50,
              color: AppColors.surface,
              child: item.product.imageUrl.isEmpty
                  ? const Icon(Icons.image, color: AppColors.textHint)
                  : Image.network(
                      item.product.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.image, color: AppColors.textHint),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.product.unit} • ${formatCurrency.format(item.product.price)}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 16),
                // Actions row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Quantity Selector
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.white,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (item.quantity > 1) {
                                ref.read(cartProvider.notifier).updateQuantity(item.product.id, item.quantity - 1);
                              } else {
                                ref.read(cartProvider.notifier).removeFromCart(item.product.id);
                              }
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(Icons.remove, size: 14, color: AppColors.textPrimary),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${item.quantity}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () {
                              ref.read(cartProvider.notifier).updateQuantity(item.product.id, item.quantity + 1);
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(Icons.add, size: 14, color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Price
                    Text(
                      formatCurrency.format(item.totalPrice),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                    ),
                    // Trash Icon
                    GestureDetector(
                      onTap: () {
                        ref.read(cartProvider.notifier).removeFromCart(item.product.id);
                      },
                      child: const Icon(Icons.delete_outline, color: AppColors.textHint, size: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrequentlyAddedSection(BuildContext context, WidgetRef ref, List<CartItem> cartItems) {
    final allProductsAsync = ref.watch(allProductsProvider);
    
    return allProductsAsync.when(
      data: (products) {
        // Filter out items already in cart
        final cartProductIds = cartItems.map((e) => e.product.id).toSet();
        final suggestions = products.where((p) => !cartProductIds.contains(p.id) && !p.isOutOfStock).take(3).toList();

        if (suggestions.isEmpty) return const SizedBox();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'FREQUENTLY ADDED PRODUCE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.5),
                  ),
                  Text(
                    '1-Tap Add',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...suggestions.map((p) => _buildSuggestionItem(context, ref, p)),
            ],
          ),
        );
      },
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
    );
  }

  Widget _buildSuggestionItem(BuildContext context, WidgetRef ref, Product product) {
    final formatCurrency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 40,
              height: 40,
              color: AppColors.surface,
              child: product.imageUrl.isEmpty
                  ? const Icon(Icons.image, color: AppColors.textHint, size: 20)
                  : Image.network(
                      product.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.image, color: AppColors.textHint, size: 20),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${product.unit} • ${formatCurrency.format(product.price)}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Add Button
          GestureDetector(
            onTap: () {
              ref.read(cartProvider.notifier).addToCart(product, 1);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A2B), // Dark green
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                '+ ADD',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(BuildContext context, WidgetRef ref) {
    final formatCurrency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final subtotal = ref.read(cartProvider.notifier).subtotal;
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Divider(height: 32, color: AppColors.surface),
          _summaryRow('Produce Subtotal', formatCurrency.format(subtotal)),
          const SizedBox(height: 12),
          _summaryRow('Doorstep Delivery', 'Calculated at checkout'),
          const SizedBox(height: 16),
          _summaryRow('Estimated Total', formatCurrency.format(subtotal), isTotal: true),
          
          const SizedBox(height: 24),
          
          // Checkout Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A2B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () async {
                final authRepo = ref.read(authRepositoryProvider);
                final isLoggedIn = await authRepo.isLoggedIn();
                if (!context.mounted) return;

                if (!isLoggedIn) {
                  final authed = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LoginPage(returnAfterAuth: true),
                    ),
                  );
                  if (authed != true || !context.mounted) return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CheckoutPage()),
                );
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('PROCEED TO SECURE CHECKOUT', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, color: Colors.white, size: 16),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'View Full Basket Page',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          
          const SizedBox(height: 24),
          // Footer
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('100% Secure Checkout', style: TextStyle(color: AppColors.textHint, fontSize: 10)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Icon(Icons.circle, size: 3, color: AppColors.textHint),
              ),
              Text('100% Stone-Free Guarantee', style: TextStyle(color: AppColors.textHint, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label, 
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, 
            fontSize: isTotal ? 16 : 13,
            color: isTotal ? AppColors.textPrimary : AppColors.textSecondary,
          )
        ),
        Text(
          value, 
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, 
            fontSize: isTotal ? 16 : 13, 
            color: AppColors.textPrimary
          )
        ),
      ],
    );
  }
}
