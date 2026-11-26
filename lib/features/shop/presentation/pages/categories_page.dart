import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bems_farms/core/constants/app_colors.dart';
import 'package:bems_farms/features/product/data/models/product_model.dart';
import 'package:bems_farms/features/product/presentation/providers/product_providers.dart';
import 'package:bems_farms/features/shop/presentation/pages/product_details_page.dart';
import 'package:bems_farms/features/cart/presentation/pages/cart_page.dart';
import 'package:bems_farms/features/cart/presentation/providers/cart_provider.dart';

class CategoriesPage extends ConsumerStatefulWidget {
  const CategoriesPage({super.key});

  @override
  ConsumerState<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends ConsumerState<CategoriesPage> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedCategoryIndex = 0;
  String _filterSearch = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final allProductsAsync = ref.watch(allProductsProvider);
    final cartCount = ref.watch(cartProvider.notifier).totalItems;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 12,
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() => _filterSearch = val.trim().toLowerCase());
            },
            decoration: const InputDecoration(
              hintText: 'Search categories & produce...',
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
              prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartPage()),
              );
            },
            icon: Badge(
              label: Text('$cartCount'),
              isLabelVisible: cartCount > 0,
              child: const Icon(Icons.shopping_cart_outlined, color: Colors.black87),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => _buildFallbackCategoryLayout(allProductsAsync),
        data: (rawCategories) {
          final categories = <String>['All Products'];
          for (final c in rawCategories) {
            final name = (c['name'] ?? c['category'] ?? c['title'] ?? '').toString();
            if (name.isNotEmpty && !categories.contains(name)) {
              categories.add(name);
            }
          }
          if (categories.length == 1) {
            // Default farm categories if API returns none
            categories.addAll([
              'Fresh Vegetables',
              'Tubers & Roots',
              'Grains & Staples',
              'Oils & Spices',
              'Livestock & Poultry',
              'Packaged Produce',
            ]);
          }

          if (_selectedCategoryIndex >= categories.length) {
            _selectedCategoryIndex = 0;
          }

          final activeCategory = categories[_selectedCategoryIndex];

          return Row(
            children: [
              // Left Category Rail / Sidebar
              Container(
                width: 110,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border(right: BorderSide(color: Colors.grey.shade200)),
                ),
                child: ListView.builder(
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final isSelected = index == _selectedCategoryIndex;
                    final catName = categories[index];

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedCategoryIndex = index;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.transparent,
                          border: Border(
                            left: BorderSide(
                              color: isSelected ? const Color(0xFFF68B1E) : Colors.transparent,
                              width: 3.5,
                            ),
                          ),
                        ),
                        child: Text(
                          catName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.black87 : Colors.black54,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Right Content Pane
              Expanded(
                child: allProductsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  error: (e, _) => Center(child: Text('Error loading products: $e')),
                  data: (products) {
                    var filtered = products;

                    if (activeCategory != 'All Products') {
                      final cleanCat = activeCategory.toLowerCase();
                      filtered = filtered.where((p) {
                        final pCat = p.category.toLowerCase();
                        final pName = p.name.toLowerCase();
                        return pCat.contains(cleanCat) ||
                            cleanCat.contains(pCat) ||
                            (cleanCat.contains('vegetable') && (pCat.contains('veg') || pName.contains('leaf') || pName.contains('spinach'))) ||
                            (cleanCat.contains('tuber') && (pCat.contains('yam') || pCat.contains('potato') || pName.contains('yam'))) ||
                            (cleanCat.contains('grain') && (pCat.contains('rice') || pCat.contains('grain') || pName.contains('flour')));
                      }).toList();
                    }

                    if (_filterSearch.isNotEmpty) {
                      filtered = filtered.where((p) =>
                          p.name.toLowerCase().contains(_filterSearch) ||
                          p.category.toLowerCase().contains(_filterSearch)).toList();
                    }

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              'No products in $activeCategory',
                              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54),
                            ),
                          ],
                        ),
                      );
                    }

                    return CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  activeCategory,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                                Text(
                                  '${filtered.length} items',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.all(12),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.72,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final product = filtered[index];
                                return _buildProductCard(context, product);
                              },
                              childCount: filtered.length,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFallbackCategoryLayout(AsyncValue<List<Product>> allProductsAsync) {
    return allProductsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (_, __) => const Center(child: Text('Unable to load categories')),
      data: (products) {
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: products.length,
          itemBuilder: (context, index) => _buildProductCard(context, products[index]),
        );
      },
    );
  }

  Widget _buildProductCard(BuildContext context, Product product) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product)),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                child: Container(
                  width: double.infinity,
                  color: Colors.grey.shade50,
                  child: Builder(
                    builder: (context) {
                      String img = product.imageUrl;
                      if (img.isNotEmpty) {
                        if (img.startsWith('/')) img = 'https://api.bemsfarms.com$img';
                        return Image.network(
                          img,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Image.asset('assets/images/banner.jpg', fit: BoxFit.cover),
                        );
                      }
                      return Image.asset('assets/images/banner.jpg', fit: BoxFit.cover);
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₦${product.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
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
