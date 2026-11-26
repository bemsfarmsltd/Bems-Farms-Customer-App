import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles all device-level storage for auth and onboarding state.
///
/// JWT token  → flutter_secure_storage (encrypted, uses Keychain/Keystore)
/// Onboarding flag → shared_preferences (just a boolean, no need to encrypt)
class TokenStorage {
  static const _tokenKey = 'bems_farms_auth_token';
  static const _onboardingKey = 'bems_farms_onboarding_done';

  final FlutterSecureStorage _secure;

  TokenStorage({FlutterSecureStorage? storage})
      : _secure = storage ?? const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));

  // ── JWT Token ─────────────────────────────────────────────────────────────

  Future<void> saveToken(String token) async {
    await _secure.write(key: _tokenKey, value: token);
  }

  /// Returns the token, or null if not logged in.
  Future<String?> getToken() async {
    return await _secure.read(key: _tokenKey);
  }

  Future<void> deleteToken() async {
    await _secure.delete(key: _tokenKey);
  }

  Future<bool> hasToken() async {
    final token = await _secure.read(key: _tokenKey);
    return token != null && token.isNotEmpty;
  }

  // ── Onboarding flag ───────────────────────────────────────────────────────

  /// Returns true if the user has already completed onboarding.
  Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingKey) ?? false;
  }

  /// Call this once the user taps "Get Started" on the onboarding screen.
  Future<void> markOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
  }
}
