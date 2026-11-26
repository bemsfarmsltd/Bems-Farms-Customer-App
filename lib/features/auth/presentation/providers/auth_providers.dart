import 'package:bems_farms/features/cart/presentation/providers/cart_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/auth_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/token_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(tokenStorage: ref.read(tokenStorageProvider));
});

class AuthNotifier extends AsyncNotifier<AuthUser?> {
  @override
  Future<AuthUser?> build() async {
    final repo = ref.read(authRepositoryProvider);
    final isLoggedIn = await repo.isLoggedIn();
    if (isLoggedIn) {
      try {
        return await repo.getProfile();
      } catch (e) {
        // Token might be expired or invalid
        await repo.logout();
        return null;
      }
    }
    return null;
  }


  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      final profile = await ref.read(authRepositoryProvider).getProfile();
      try {
        await ref.read(cartProvider.notifier).syncGuestCartToServer();
        await ref.read(cartProvider.notifier).refreshServerCart();
      } catch (_) {}
      return profile;
    });
  }

  Future<void> signInWithApple() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signInWithApple();
      final profile = await ref.read(authRepositoryProvider).getProfile();
      try {
        await ref.read(cartProvider.notifier).syncGuestCartToServer();
        await ref.read(cartProvider.notifier).refreshServerCart();
      } catch (_) {}
      return profile;
    });
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(authRepositoryProvider)
          .login(email: email, password: password);
      // Fetch full profile to get all fields like preferences, address, etc.
      final profile = await ref.read(authRepositoryProvider).getProfile();
      try {
        await ref.read(cartProvider.notifier).syncGuestCartToServer();
        await ref.read(cartProvider.notifier).refreshServerCart();
      } catch (_) {}
      return profile;
    });
  }

  Future<void> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    String? address,
    String? city,
    String? stateStr,
    double? latitude,
    double? longitude,
    String? postalCode,
    dynamic preferences,
  }) async {
    state = const AsyncLoading();
    try {
      await ref.read(authRepositoryProvider).register(
            name: name,
            email: email,
            phone: phone,
            password: password,
            address: address,
            city: city,
            state: stateStr,
            latitude: latitude,
            longitude: longitude,
            postalCode: postalCode,
            preferences: preferences,
          );
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> verifyEmail({required String email, required String code}) async {
    state = const AsyncLoading();
    try {
      await ref.read(authRepositoryProvider).verifyEmail(email: email, code: code);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? gender,
    String? idNumber,
    String? taxId,
    String? taxCountry,
    String? address,
    String? state,
  }) async {
    this.state = const AsyncLoading();
    this.state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      await repo.updateProfile(
        name: name,
        email: email,
        phone: phone,
        gender: gender,
        idNumber: idNumber,
        taxId: taxId,
        taxCountry: taxCountry,
        address: address,
        state: state,
      );
      return await repo.getProfile();
    });
  }

  Future<void> updateAvatar(String avatarUrl) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      await repo.updateAvatar(avatarUrl);
      return await repo.getProfile();
    });
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await ref.read(authRepositoryProvider).changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
  }

  Future<void> forgotPassword(String email) async {
    await ref.read(authRepositoryProvider).forgotPassword(email);
  }

  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    await ref.read(authRepositoryProvider).resetPassword(
          token: token,
          password: password,
        );
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
  }
}

final authProvider =
    AsyncNotifierProvider<AuthNotifier, AuthUser?>(AuthNotifier.new);
