import 'package:flutter/material.dart';
import 'package:bems_farms/core/constants/app_colors.dart';
import 'package:bems_farms/features/product/data/models/product_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bems_farms/features/auth/presentation/providers/auth_providers.dart';
import 'package:bems_farms/features/product/presentation/providers/favorite_provider.dart';
import 'package:bems_farms/features/cart/presentation/providers/cart_provider.dart';
import 'package:bems_farms/features/product/presentation/widgets/product_reviews_section.dart';

class ProductDetailsPage extends ConsumerStatefulWidget {
  final Product product;
  const ProductDetailsPage({super.key, required this.product});

  @override
  ConsumerState<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends ConsumerState<ProductDetailsPage> {
  int _selectedTabIndex = 0;

  double _quantity = 1;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).value;
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    if (product.isOutOfStock) {
      return _buildOutofStockPage(context, product);
    }

    return _buildInStockPage(context, product);
  }

  Widget _buildOutofStockPage(BuildContext context, Product product) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A2B), // Dark green background for out of stock alert
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: Colors.white, size: 6),
                        SizedBox(width: 6),
                        Text('PRESENTLY OUT OF STOCK',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Restock Waitlist Alert',
                      style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Get notified immediately the moment fresh harvest arrives.',
                      style: TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 32),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Summary Card
                  Container(
                    padding: const EdgeInsets.all(12),
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
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: product.imageUrl.isEmpty
                              ? Image.asset('assets/images/banner.jpg', width: 64, height: 64, fit: BoxFit.cover)
                              : Image.network(
                                  product.imageUrl,
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Image.asset('assets/images/banner.jpg', width: 64, height: 64, fit: BoxFit.cover),
                                ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text('• ${product.unit}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text('Email Address *',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'bemssofthubltd@gmail.com',
                      hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Phone / WhatsApp Number (Optional)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: '+2349152777303',
                      hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No spam guaranteed. We will only contact you regarding this product\'s restock status.',
                    style: TextStyle(color: AppColors.textHint, fontSize: 12),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A2B), // Dark green button
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('You have been added to the waitlist!'),
                          backgroundColor: Color(0xFF1E3A2B),
                        ));
                        Navigator.pop(context);
                      },
                      child: const Text('Notify Me When Available',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 32), // Extra padding for scroll
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInStockPage(BuildContext context, Product product) {
    final displayDescription = product.description.isNotEmpty 
        ? product.description 
        : 'Fresh, premium quality ${product.name} sourced directly from trusted farms. Delivered fresh to your doorstep with guaranteed quality.';
    final isFavorite = ref.watch(favoriteProvider).contains(product.id);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () {
              ref.read(favoriteProvider.notifier).toggleFavorite(product.id);
            },
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? Colors.red : null,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 300,
              width: double.infinity,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: product.imageUrl.isEmpty
                        ? Image.asset('assets/images/banner.jpg', fit: BoxFit.cover)
                        : Image.network(
                            product.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppColors.surface,
                              child: const Icon(Icons.image_not_supported_outlined,
                                  size: 80, color: AppColors.textHint),
                            ),
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                  color: AppColors.surface,
                                  child: const Center(child: CircularProgressIndicator()));
                            },
                          ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(product.category.toUpperCase(),
                          style: const TextStyle(
                              color: AppColors.textHint,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                      Text(product.unit,
                          style: const TextStyle(
                              color: AppColors.textHint, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(product.name,
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.bold)),
                      ),
                      if (product.isOnDeal)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: AppColors.warning,
                              borderRadius: BorderRadius.circular(8)),
                          child: const Text('DEAL',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(product.formattedPrice,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary)),
                  const SizedBox(height: 16),
                                    if (product.stock > 0 && product.stock <= 20) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text('Only ${product.stock} left!', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Stock level', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
                        Text('${product.stock} remaining', style: const TextStyle(color: Colors.red, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (product.stock / 50).clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.shade200,
                        color: Colors.red,
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  Text(
                    displayDescription,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.local_shipping_outlined, color: AppColors.textSecondary, size: 20),
                            SizedBox(width: 8),
                            Text('Doorstep Delivery', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Padding(
                          padding: EdgeInsets.only(left: 28.0),
                          child: Text('Calculated at checkout', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
                        ),
                        Divider(height: 24),
                        Row(
                          children: [
                            Icon(Icons.swap_horiz_outlined, color: AppColors.textSecondary, size: 20),
                            SizedBox(width: 8),
                            Text('Return Policy', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Padding(
                          padding: EdgeInsets.only(left: 28.0),
                          child: Text('Free returns within 7 days', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Tabs Header
                  Row(
                    children: [
                      _buildTabButton(0, 'Description'),
                      const SizedBox(width: 16),
                      _buildTabButton(1, 'Reviews'),
                      const SizedBox(width: 16),
                      _buildTabButton(2, 'Shipping'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Tab Content
                  if (_selectedTabIndex == 0)
                    Text(displayDescription,
                        style: const TextStyle(
                            color: AppColors.textSecondary, height: 1.5))
                  else if (_selectedTabIndex == 1)
                    ProductReviewsSection(productId: product.id)
                  else if (_selectedTabIndex == 2)
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Standard delivery: 1-2 business days', style: TextStyle(color: AppColors.textSecondary, height: 1.5)),
                        SizedBox(height: 8),
                        Text('Express delivery: Same day in Abia State', style: TextStyle(color: AppColors.textSecondary, height: 1.5)),
                        SizedBox(height: 8),
                        Text('Nationwide door-to-door dispatch', style: TextStyle(color: AppColors.textSecondary, height: 1.5)),
                        SizedBox(height: 16),
                        Text('Return Policy: Free returns within 7 days', style: TextStyle(color: AppColors.textSecondary, height: 1.5, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  if (product.nutritionalInfo.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text('Nutritional Information (per 100g)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: product.nutritionalInfo.entries
                          .take(3)
                          .map((e) => _buildNutrient(e.key, e.value))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    border: Border.all(color: AppColors.surface),
                    borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (_quantity > 1) setState(() => _quantity--);
                      },
                      child: const Icon(Icons.remove),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('${_quantity.toInt()}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _quantity++),
                      child: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      ref.read(cartProvider.notifier).addToCart(product, _quantity.toInt());
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('${_quantity.toInt()} ${product.unit} of ${product.name} added to cart'),
                        backgroundColor: AppColors.primary,
                        duration: const Duration(seconds: 1),
                      ));
                    },
                    child: const Text('Add to Cart', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNutrient(String label, String value) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTabButton(int index, String title) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textHint,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
