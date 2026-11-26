import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bems_farms/core/constants/app_colors.dart';
import 'package:bems_farms/features/product/data/models/product_model.dart';
import 'package:bems_farms/features/shop/presentation/pages/product_details_page.dart';
import 'package:bems_farms/features/product/presentation/providers/favorite_provider.dart';
import 'package:bems_farms/features/cart/presentation/providers/cart_provider.dart';

class ProductCard extends ConsumerWidget {
  final Product product;
  final String subtitle;

  const ProductCard({
    super.key,
    required this.product,
    this.subtitle = 'Fresh Harvest',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(favoriteProvider).contains(product.id);
    final cartItem = ref.watch(cartProvider).where((item) => item.product.id == product.id).firstOrNull;
    final int cartQuantity = cartItem?.quantity ?? 0;
    
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product))),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Stack
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: product.imageUrl.isEmpty
                        ? Image.asset('assets/images/banner.jpg',
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity)
                        : Image.network(
                            product.imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (_, __, ___) => Image.asset(
                                'assets/images/banner.jpg',
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity),
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                  color: AppColors.surface,
                                  child: const Center(
                                      child: CircularProgressIndicator(strokeWidth: 2)));
                            },
                          ),
                  ),
                  // Heart icon top right
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {
                        ref.read(favoriteProvider.notifier).toggleFavorite(product.id);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          size: 16,
                          color: isFavorite ? Colors.red : AppColors.textHint,
                        ),
                      ),
                    ),
                  ),
                  // Out of stock badge bottom center of image
                  if (product.isOutOfStock)
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Presently Out of Stock',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    )
                  else if (product.stock > 0 && product.stock <= 5)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF39C12), // Orange color from image
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('Only ${product.stock} left',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
            // Info padding
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category & Unit Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(product.category.toUpperCase(), style: const TextStyle(color: AppColors.textHint, fontSize: 10, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 4),
                      Text(product.unit, style: const TextStyle(color: AppColors.textHint, fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Name
                  Text(product.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  // Subtitle
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
                  const SizedBox(height: 12),
                  // Divider
                  const Divider(height: 1, color: AppColors.surface),
                  const SizedBox(height: 8),
                  // Price and Button Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('PRICE', style: TextStyle(color: AppColors.textHint, fontSize: 8, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            if (product.isOutOfStock)
                              const Text('Presently Out...', style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold))
                            else
                              Text(product.formattedPrice, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      // Button
                      if (product.isOutOfStock)
                        GestureDetector(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product)));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E3A2B),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Text(
                              'Notify Me',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        )
                      else if (cartQuantity == 0)
                        GestureDetector(
                          onTap: () {
                            ref.read(cartProvider.notifier).addToCart(product, 1);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('${product.name} added to cart'),
                              backgroundColor: AppColors.primary,
                              duration: const Duration(seconds: 1),
                            ));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E3A2B), // Dark green
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Text(
                              '+ Add',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
                                  if (cartQuantity > 1) {
                                    ref.read(cartProvider.notifier).updateQuantity(product.id, cartQuantity - 1);
                                  } else {
                                    ref.read(cartProvider.notifier).removeFromCart(product.id);
                                  }
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Icon(Icons.remove, size: 14, color: Colors.black),
                                ),
                              ),
                              Text('$cartQuantity', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              GestureDetector(
                                onTap: () {
                                  ref.read(cartProvider.notifier).updateQuantity(product.id, cartQuantity + 1);
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Icon(Icons.add, size: 14, color: Colors.black),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
