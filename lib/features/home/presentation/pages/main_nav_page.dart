import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bems_farms/core/constants/app_colors.dart';
import 'package:bems_farms/core/services/customer_order_monitor.dart';
import 'package:bems_farms/features/auth/presentation/providers/auth_providers.dart';
import 'package:bems_farms/features/home/presentation/pages/home_page.dart';
import 'package:bems_farms/features/orders/presentation/pages/orders_page.dart';
import 'package:bems_farms/features/orders/presentation/pages/track_delivery_page.dart';
import 'package:bems_farms/features/shop/presentation/pages/shop_page.dart';
import 'package:bems_farms/features/shop/presentation/pages/categories_page.dart';
import 'package:bems_farms/features/cart/presentation/pages/cart_page.dart';
import 'package:bems_farms/features/cart/presentation/providers/cart_provider.dart';
import 'package:bems_farms/features/product/presentation/pages/favorites_page.dart';
import 'package:bems_farms/features/profile/presentation/pages/profile_page.dart';
import 'package:bems_farms/features/ai/presentation/pages/chef_bems_chat_page.dart';

/// Global provider to allow any page to switch the bottom nav tab.
/// Set this to 1 (Shop) from anywhere (e.g. wallet "Shop & Pay" button).
final selectedNavIndexProvider = StateProvider<int>((ref) => 0);

class MainNavPage extends ConsumerStatefulWidget {
  final int initialIndex;
  const MainNavPage({super.key, this.initialIndex = 0});

  @override
  ConsumerState<MainNavPage> createState() => _MainNavPageState();
}

class _MainNavPageState extends ConsumerState<MainNavPage> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  // 1. Guest mode pages (Storefront called Home, Categories, Cart, Wishlist, Account)
  final List<Widget> _guestPages = const [
    ShopPage(),        // 0: Home
    CategoriesPage(),  // 1: Categories
    CartPage(),        // 2: Cart
    FavoritesPage(),   // 3: Wishlist
    ProfilePage(),     // 4: Account
  ];

  // 2. Logged-in member pages (Original app layout)
  final List<Widget> _memberPages = const [
    HomePage(),          // 0: Home
    ShopPage(),          // 1: Shop
    OrdersPage(),        // 2: Orders
    TrackDeliveryPage(), // 3: Delivery
    ProfilePage(),       // 4: Profile
  ];

  @override
  Widget build(BuildContext context) {
    // Actively run global customer order monitor (polling + socket listener)
    ref.watch(customerOrderMonitorProvider);

    // Reset index to 0 whenever auth state changes (guest ↔ logged-in)
    ref.listen<AsyncValue>(authProvider, (previous, next) {
      final wasLoggedIn = previous?.valueOrNull != null;
      final nowLoggedIn = next.valueOrNull != null;
      if (wasLoggedIn != nowLoggedIn) {
        setState(() {
          _selectedIndex = 0;
        });
      }
    });

    // Listen for external tab-switch requests (e.g. from wallet "Shop & Pay")
    ref.listen<int>(selectedNavIndexProvider, (_, next) {
      if (_selectedIndex != next) {
        setState(() => _selectedIndex = next);
      }
    });

    final user = ref.watch(authProvider).valueOrNull;
    final isLoggedIn = user != null;
    final pages = isLoggedIn ? _memberPages : _guestPages;

    if (_selectedIndex >= pages.length) {
      _selectedIndex = 0;
    }

    final cartCount = ref.watch(cartProvider.notifier).totalItems;

    return Scaffold(
      body: pages[_selectedIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: isLoggedIn ? AppColors.primary : const Color(0xFFF68B1E),
        unselectedItemColor: AppColors.textHint,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 11),

        items: isLoggedIn
            // Logged-in Member Navigation
            ? const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.shopping_bag_outlined),
                  activeIcon: Icon(Icons.shopping_bag),
                  label: 'Shop',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.receipt_long_outlined),
                  activeIcon: Icon(Icons.receipt_long),
                  label: 'Orders',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.local_shipping_outlined),
                  activeIcon: Icon(Icons.local_shipping),
                  label: 'Delivery',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ]
            // Guest Navigation (Jumia-style eCommerce)
            : [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.grid_view_outlined),
                  activeIcon: Icon(Icons.grid_view),
                  label: 'Categories',
                ),
                BottomNavigationBarItem(
                  icon: Badge(
                    label: Text('$cartCount'),
                    isLabelVisible: cartCount > 0,
                    child: const Icon(Icons.shopping_cart_outlined),
                  ),
                  activeIcon: Badge(
                    label: Text('$cartCount'),
                    isLabelVisible: cartCount > 0,
                    child: const Icon(Icons.shopping_cart),
                  ),
                  label: 'Cart',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.favorite_border),
                  activeIcon: Icon(Icons.favorite),
                  label: 'Wishlist',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Account',
                ),
              ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChefBemsChatPage()),
          );
        },
        backgroundColor: Colors.white,
        elevation: 6,
        shape: const CircleBorder(),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 2),
          ),
          child: const Padding(
            padding: EdgeInsets.all(2.0),
            child: CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage: AssetImage('assets/images/chef_bems.png'),
              radius: 24,
            ),
          ),
        ),
      ),
    );
  }
}