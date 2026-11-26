import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bems_farms/core/constants/app_colors.dart';
import 'package:bems_farms/features/auth/presentation/providers/auth_providers.dart';
import 'package:bems_farms/features/auth/data/models/auth_model.dart';
import 'package:bems_farms/features/product/data/models/product_model.dart';
import 'package:bems_farms/features/product/presentation/providers/product_providers.dart';
import 'package:bems_farms/features/product/presentation/widgets/product_card.dart';
import 'main_nav_page.dart';
import 'package:bems_farms/features/cart/presentation/providers/cart_provider.dart';
import 'package:bems_farms/features/cart/presentation/pages/cart_page.dart';
import 'package:bems_farms/core/services/customer_order_monitor.dart';
import 'package:bems_farms/features/notifications/presentation/widgets/customer_notifications_sheet.dart';
import 'package:bems_farms/features/wallet/presentation/providers/customer_wallet_provider.dart';
import 'package:bems_farms/features/wallet/presentation/widgets/wallet_setup_dialog.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _searchQuery = '';
  static bool _hasDismissedWalletSetupThisSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkWalletSetup();
    });
  }

  Future<void> _checkWalletSetup() async {
    if (_hasDismissedWalletSetupThisSession) return;
    final user = ref.read(authProvider).valueOrNull;
    if (user == null) return;

    try {
      await ref.read(customerWalletProvider.notifier).fetchWallet(silent: true);
      final wallet = ref.read(customerWalletProvider).wallet;

      final hasNoPhone = user.phone == null || user.phone!.trim().isEmpty;
      final hasNoNuban = wallet?.accountNumber == null || wallet!.accountNumber!.trim().isEmpty;

      if ((hasNoPhone || hasNoNuban) && mounted) {
        _hasDismissedWalletSetupThisSession = true;
        await WalletSetupDialog.show(context, initialPhone: user.phone);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = query;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).valueOrNull;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAF9),
      appBar: _buildAppBar(user),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(categoriesProvider);
            ref.invalidate(allProductsProvider);
            ref.invalidate(searchProductsProvider);
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_searchQuery.isEmpty) ...[
                  _buildHeroSection(context, user),
                  const SizedBox(height: 24),
                ],
                
                // Search Bar below Hero
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search fresh produce catalogue (e.g. Rice, Yam, Palm Oil, Pepper...)',
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _searchQuery.isNotEmpty 
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        ) 
                      : null,
                    fillColor: Colors.white,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                if (_searchQuery.isEmpty) ...[
                  // Static Specific Category Sections as requested by Web Design
                  _buildStaticSections(ref, context),
                  const SizedBox(height: 32),
                ] else ...[
                  // Search Results
                  Text('Search Results for "$_searchQuery"', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildSearchResultsSection(ref, _searchQuery),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AuthUser? user) {
    return AppBar(
      backgroundColor: const Color(0xFFF9FAF9),
      elevation: 0,
      title: Image.asset('assets/images/logo.png', height: 32, fit: BoxFit.contain),
      actions: [
        // Notification Bell Icon with Badge
        Consumer(
          builder: (context, ref, child) {
            final unreadCount = ref.watch(customerNotificationStoreProvider).unreadCount;
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                IconButton(
                  tooltip: 'Notifications',
                  icon: const Icon(Icons.notifications_outlined, color: AppColors.primary),
                  onPressed: () => CustomerNotificationsSheet.show(context),
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                      child: Text(
                        unreadCount > 9 ? '9+' : '$unreadCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        // Cart Icon with Badge
        Consumer(
          builder: (context, ref, child) {
            final cartCount = ref.watch(cartProvider).length;
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined, color: AppColors.primary),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CartPage()));
                  },
                ),
                if (cartCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                      child: Text(
                        '$cartCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        // Profile Icon
        Padding(
          padding: const EdgeInsets.only(right: 16, left: 8),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary,
            child: Text(
              user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'G',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStaticSections(WidgetRef ref, BuildContext context) {
    final shopAsync = ref.watch(allProductsProvider);

    return shopAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => const SizedBox(),
      data: (products) {
        if (products.isEmpty) return const SizedBox();

        // 1. Weekly Household Staples: Flour, Beans & Grains, Cooking Oil, Kitchen Essentials
        final staples = products.where((p) {
          final cat = p.category.toLowerCase();
          final name = p.name.toLowerCase();
          final isPastaOrNoodle = cat.contains('pasta') ||
              cat.contains('noodle') ||
              name.contains('spaghetti') ||
              name.contains('noodle') ||
              name.contains('pasta');
          if (isPastaOrNoodle) return false;

          return cat.contains('flour') ||
              name.contains('poundo') ||
              name.contains('yam') ||
              cat.contains('beans') ||
              cat.contains('grain') ||
              cat.contains('oil') ||
              name.contains('palm oil') ||
              name.contains('beans') ||
              cat.contains('staple');
        }).toList();

        // 2. Fresh Seasonal Harvests: Pasta, Noodles, Packaged Farm Staples
        final seasonal = products.where((p) {
          final cat = p.category.toLowerCase();
          final name = p.name.toLowerCase();
          return cat.contains('pasta') ||
              cat.contains('noodle') ||
              name.contains('spaghetti') ||
              name.contains('noodle') ||
              name.contains('pasta');
        }).toList();

        // Safe fallbacks to ensure both sections populate
        final effectiveStaples = staples.isNotEmpty
            ? staples
            : products.where((p) => !seasonal.contains(p)).toList();
        final effectiveSeasonal = seasonal.isNotEmpty
            ? seasonal
            : products.take(10).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Weekly Household Staples (Matching Web Section 1)
            _buildSection(
              title: 'Weekly Household Staples',
              subtitle: 'Quick 1-tap reorder of Nigerian kitchen essentials',
              buttonText: 'View Full Shop',
              products: effectiveStaples.take(10).toList(),
              onViewShop: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const MainNavPage(initialIndex: 1)),
                  (route) => false,
                );
              },
            ),
            const SizedBox(height: 32),

            // Fresh Seasonal Harvests (Matching Web Section 2)
            _buildSection(
              title: 'Fresh Seasonal Harvests',
              subtitle: '100% stone-free grains and unadulterated oils direct from farm',
              buttonText: 'See all grains',
              products: effectiveSeasonal.take(10).toList(),
              onViewShop: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const MainNavPage(initialIndex: 1)),
                  (route) => false,
                );
              },
            ),
            const SizedBox(height: 32),

            // Complete Store Inventory (Matching Web Section 3)
            _buildStoreInventoryBanner(context),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildStoreInventoryBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1B4D3E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'COMPLETE STORE INVENTORY',
              style: TextStyle(
                color: Color(0xFFFFC107),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Looking for tubers, leafy greens, or bulk bags?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Browse our full catalogue with comprehensive category filtering and live stock in the Shop.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const MainNavPage(initialIndex: 1)),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC107),
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text(
                'EXPLORE FULL SHOP',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required List<Product> products,
    required VoidCallback onViewShop,
    String buttonText = 'View Full Shop',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            TextButton(
              onPressed: onViewShop,
              child: Row(
                children: [
                  Text(buttonText, style: const TextStyle(color: Colors.orange, fontSize: 12)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward, color: Colors.orange, size: 12),
                ],
              ),
            )
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 280, // Height for ProductCard
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              return SizedBox(
                width: 160,
                child: ProductCard(
                  product: products[index],
                  subtitle: 'Fresh Harvest',
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResultsSection(WidgetRef ref, String query) {
    final asyncValue = ref.watch(searchProductsProvider(query));
    return asyncValue.when(
      loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
      error: (error, _) => SizedBox(
        height: 100,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error),
              const SizedBox(height: 8),
              const Text('Could not load products', style: TextStyle(color: Colors.grey)),
              TextButton(onPressed: () => ref.refresh(searchProductsProvider(query)), child: const Text('Retry')),
            ],
          ),
        ),
      ),
      data: (products) => products.isEmpty
          ? const SizedBox(height: 80, child: Center(child: Text('No products available')))
          : GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.55,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) => ProductCard(product: products[index], subtitle: 'Fresh Harvest'),
            ),
    );
  }

  Widget _buildHeroSection(BuildContext context, AuthUser? user) {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }

    final firstName = user?.name.split(' ').first ?? 'Guest';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1B4D3E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(color: Color(0xFF6DA34D), shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                const Text('DIRECT FROM FARM TO TABLE',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              children: [
                TextSpan(text: '$greeting, '),
                TextSpan(text: '$firstName!', style: const TextStyle(color: Color(0xFFFFC107))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Shop 100% stone-free grains, authentic cold-pressed oils, and farm-fresh harvests delivered right to your doorstep.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}
