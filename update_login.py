import os
file = r'C:\Users\XPS\Downloads\bems_farms_final\bems_farms_final\lib\features\auth\presentation\pages\login_page.dart'
content = open(file, 'r', encoding='utf-8').read()

social_logic = """
  Future<void> _handleSocialLogin(String provider) async {
    if (provider == 'Google') {
      await ref.read(authProvider.notifier).signInWithGoogle();
    } else if (provider == 'Apple') {
      await ref.read(authProvider.notifier).signInWithApple();
    }

    if (!mounted) return;

    final authState = ref.read(authProvider);
    authState.when(
      data: (user) async {
        if (user != null) {
          final hasSeenOnboarding = await TokenStorage().hasSeenOnboarding();
          if (!mounted) return;
          if (hasSeenOnboarding) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MainNavPage()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const OnboardingPage()),
            );
          }
        }
      },
      error: (error, _) {
        _showError(error.toString().replaceFirst('Exception: ', ''));
      },
      loading: () {},
    );
  }
"""

old_logic = """  void _handleSocialLogin(String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(' Sign-In will be connected by the backend team!'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }"""

content = content.replace(old_logic, social_logic)
open(file, 'w', encoding='utf-8').write(content)
