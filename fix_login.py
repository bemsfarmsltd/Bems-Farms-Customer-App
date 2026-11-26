import re

file_login = r'C:\Users\XPS\Downloads\bems_farms_final\bems_farms_final\lib\features\auth\presentation\pages\login_page.dart'
file_register = r'C:\Users\XPS\Downloads\bems_farms_final\bems_farms_final\lib\features\auth\presentation\pages\register_page.dart'

social_logic_login = """  Future<void> _handleSocialLogin(String provider) async {
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
  }"""

social_logic_register = social_logic_login.replace('_showError', "ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.error,))")

for file_path, new_logic in [(file_login, social_logic_login), (file_register, social_logic_register)]:
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Regex to find the old _handleSocialLogin function
    pattern = re.compile(r'void _handleSocialLogin\(String provider\)\s*\{.*?\n  \}', re.DOTALL)
    
    content = pattern.sub(new_logic, content)
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)

print("Done replacing.")
