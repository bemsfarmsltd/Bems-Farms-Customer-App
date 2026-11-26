import os
file = r'C:\Users\XPS\Downloads\bems_farms_final\bems_farms_final\lib\features\auth\presentation\providers\auth_providers.dart'
content = open(file, 'r', encoding='utf-8').read()

social_methods = """
  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      return await ref.read(authRepositoryProvider).getProfile();
    });
  }

  Future<void> signInWithApple() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signInWithApple();
      return await ref.read(authRepositoryProvider).getProfile();
    });
  }
"""

content = content.replace('  Future<void> login({required String email, required String password}) async {', social_methods + '\n  Future<void> login({required String email, required String password}) async {')
open(file, 'w', encoding='utf-8').write(content)
