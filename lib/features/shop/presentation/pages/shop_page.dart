import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bems_farms/core/constants/app_colors.dart';
import 'package:bems_farms/features/auth/presentation/providers/auth_providers.dart';
import 'package:bems_farms/features/product/data/models/product_model.dart';
import 'package:bems_farms/features/product/presentation/providers/product_providers.dart';
import 'package:bems_farms/features/product/presentation/widgets/product_card.dart';
import 'package:bems_farms/features/cart/presentation/pages/cart_page.dart';
import 'package:bems_farms/features/cart/presentation/providers/cart_provider.dart';

class ShopPage extends ConsumerStatefulWidget {
  const ShopPage({super.key});

  @override
  ConsumerState<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends ConsumerState<ShopPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _triggerSearch() {
    setState(() {
      _searchQuery = _searchController.text.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final asyncProducts = ref.watch(allProductsProvider);
    final asyncCategories = ref.watch(categoriesProvider);

    final user = ref.watch(authProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(user != null ? 'Shop' : 'Home', style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CartPage()),
            ),
            icon: Badge(
              label: Text('${ref.watch(cartProvider.notifier).totalItems}'),
              isLabelVisible: ref.watch(cartProvider).isNotEmpty,
              child: const Icon(Icons.shopping_cart_outlined),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroSection(context),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text('Filter by Produce Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 12),
            _buildCategories(ref, selectedCategory, asyncCategories),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildResultsHeader(asyncProducts),
            ),
            const SizedBox(height: 16),
            _buildProductGrid(asyncProducts, ref),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E3A2B), // Dark green background
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: Colors.green, size: 8),
                  SizedBox(width: 6),
                  Text('FARM-TO-DOOR CATALOGUE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Fresh Produce & Pantry Essentials',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, height: 1.2),
            ),
            const SizedBox(height: 12),
            const Text(
              'Explore 100% stone-free grains, authentic cold-pressed oils, farm tubers, and Nigerian staples delivered directly to your doorstep.',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            // Search Bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _triggerSearch(),
                    onChanged: (val) {
                      if (val.isEmpty && _searchQuery.isNotEmpty) {
                        setState(() => _searchQuery = '');
                      } else {
                        setState(() {});
                      }
                    },
                    style: const TextStyle(color: Colors.black87, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search rice, yam, palm oil, beans...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _triggerSearch,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Search', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 5-Second Slideshow Banner replacing the tomatoes image
            const ShopBannerSlideshow(),
          ],
        ),
      ),
    );
  }

  Widget _buildCategories(WidgetRef ref, String? selectedCategory, AsyncValue<List<Map<String, dynamic>>> asyncCategories) {
    return asyncCategories.when(
      data: (categories) {
        // Prepend "All" option
        final allCategories = [{'name': 'All', 'count': 97}, ...categories]; // 97 is hardcoded to match design for "All"
        
        return SizedBox(
          height: 36,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: allCategories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = allCategories[index];
              final filter = cat['name'] as String;
              final isSelected = index == 0 ? selectedCategory == null : selectedCategory == filter;
              
              return GestureDetector(
                onTap: () {
                  ref.read(selectedCategoryProvider.notifier).state = index == 0 ? null : filter;
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF1E3A2B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? const Color(0xFF1E3A2B) : AppColors.surface),
                  ),
                  child: Row(
                    children: [
                      Text(filter, style: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimary, fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white.withOpacity(0.2) : AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(cat['count']?.toString() ?? '0', style: TextStyle(color: isSelected ? Colors.white : AppColors.textHint, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox(height: 36, child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const SizedBox(height: 36, child: Center(child: Text('Failed to load filters'))),
    );
  }

  Widget _buildResultsHeader(AsyncValue<List<Product>> asyncProducts) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        asyncProducts.maybeWhen(
          data: (products) {
            final count = _searchQuery.isEmpty
                ? products.length
                : products.where((p) {
                    final q = _searchQuery.toLowerCase();
                    return p.name.toLowerCase().contains(q) ||
                        p.category.toLowerCase().contains(q) ||
                        p.description.toLowerCase().contains(q);
                  }).length;
            final label = _searchQuery.isNotEmpty
                ? '$count Results for "$_searchQuery"'
                : '$count Products Found';
            return Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13));
          },
          orElse: () => const Text('Loading...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.surface),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            children: [
              Text('Featured Picks', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down, size: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductGrid(AsyncValue<List<Product>> asyncProducts, WidgetRef ref) {
    return asyncProducts.when(
      loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error),
            const SizedBox(height: 8),
            const Text('Could not load products'),
            TextButton(
              onPressed: () => ref.refresh(allProductsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (products) {
        final filtered = _searchQuery.isEmpty
            ? products
            : products.where((p) {
                final q = _searchQuery.toLowerCase();
                return p.name.toLowerCase().contains(q) ||
                    p.category.toLowerCase().contains(q) ||
                    p.description.toLowerCase().contains(q);
              }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 36.0, horizontal: 24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_off, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'No products found matching "$_searchQuery"'
                        : 'No products found',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  if (_searchQuery.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      icon: const Icon(Icons.clear, size: 16),
                      label: const Text('Clear Search Filter'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.55,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) => ProductCard(product: filtered[index], subtitle: 'Verified Quality • Farm Fresh'),
        );
      },
    );
  }
}
class ShopBannerSlideshow extends StatefulWidget {
  const ShopBannerSlideshow({super.key});

  @override
  State<ShopBannerSlideshow> createState() => _ShopBannerSlideshowState();
}

class _ShopBannerSlideshowState extends State<ShopBannerSlideshow> {
  late final PageController _pageController;
  Timer? _timer;
  int _currentIndex = 0;

  final List<Map<String, dynamic>> _slides = [
    {
      'tag': '100% Stone-Free Guarantee',
      'title': 'FRESH NIGERIAN HARVESTS',
      'subtitle': 'Clean hand-sorted grains, garri, tubers & authentic palm oils.',
      'tagColor': Colors.white,
      'tagTextColor': Colors.black87,
      'accentColor': Colors.orangeAccent,
      'image': 'assets/images/bems_shop_slide1.jpg',
      'icon': Icons.verified,
    },
    {
      'tag': 'Bems Farms Global Store',
      'title': 'PREMIUM FARM PRODUCE',
      'subtitle': 'Direct from our trusted farm store counters to your home.',
      'tagColor': const Color(0xFFE8F5E9),
      'tagTextColor': const Color(0xFF1B5E20),
      'accentColor': const Color(0xFF81C784),
      'image': 'assets/images/bems_shop_slide2.jpg',
      'icon': Icons.storefront,
    },
    {
      'tag': 'Doorstep Express Dispatch',
      'title': 'FAST & RELIABLE DELIVERY',
      'subtitle': 'Fleet dispatch & temperature-controlled delivery nationwide.',
      'tagColor': const Color(0xFFFFF3E0),
      'tagTextColor': const Color(0xFFE65100),
      'accentColor': Colors.amberAccent,
      'image': 'assets/images/bems_shop_slide3.jpg',
      'icon': Icons.local_shipping,
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;
      final nextIndex = (_currentIndex + 1) % _slides.length;
      _pageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 145,
          width: double.infinity,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemCount: _slides.length,
            itemBuilder: (context, index) {
              final slide = _slides[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Full photo background
                      Image.asset(
                        slide['image'] as String,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFF143D24),
                          child: const Center(
                            child: Icon(Icons.image_not_supported, color: Colors.white54),
                          ),
                        ),
                      ),
                      // Gradient scrim to ensure high text contrast while keeping photo visible
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.2),
                              Colors.black.withOpacity(0.72),
                            ],
                          ),
                        ),
                      ),
                      // Content overlay
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: slide['tagColor'] as Color,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    slide['icon'] as IconData,
                                    size: 11,
                                    color: slide['tagTextColor'] as Color,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    slide['tag'] as String,
                                    style: TextStyle(
                                      color: slide['tagTextColor'] as Color,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              slide['title'] as String,
                              style: TextStyle(
                                color: slide['accentColor'] as Color,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              slide['subtitle'] as String,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                height: 1.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _slides.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _currentIndex == index ? 20 : 6,
              height: 4,
              decoration: BoxDecoration(
                color: _currentIndex == index ? Colors.orangeAccent : Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

