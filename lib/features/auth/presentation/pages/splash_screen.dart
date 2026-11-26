import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bems_farms/core/constants/app_colors.dart';
import 'package:bems_farms/features/home/presentation/pages/main_nav_page.dart';
import 'package:bems_farms/features/auth/presentation/pages/login_page.dart';
import 'package:bems_farms/features/auth/presentation/providers/auth_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _decideNextScreen();
  }

  Future<void> _decideNextScreen() async {
    // Check if user is logged in
    final authRepo = ref.read(authRepositoryProvider);
    bool isLoggedIn = false;
    try {
      isLoggedIn = await authRepo.isLoggedIn();
    } catch (e) {
      print('Auth error on splash: ');
      // Fallback to false if secure storage fails to read
    }

    // Delay for visual splash effect
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;

    // Navigate straight to the storefront for both guests and authenticated customers
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainNavPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 300,
              fit: BoxFit.contain,
              // Apply color filter if logo is dark so it is visible on the green primary background
              color: Colors.white,
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              color: Colors.white54,
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}
