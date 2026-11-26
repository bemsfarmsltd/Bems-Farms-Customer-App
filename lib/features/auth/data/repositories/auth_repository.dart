import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/network/api_constants.dart';
import '../models/auth_model.dart';
import 'token_storage.dart';

class AuthRepository {
  final http.Client _client;
  final TokenStorage _tokenStorage;

  AuthRepository({http.Client? client, TokenStorage? tokenStorage})
      : _client = client ?? http.Client(),
        _tokenStorage = tokenStorage ?? TokenStorage();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _tokenStorage.getToken();
    return ApiConstants.authHeaders(token ?? '');
  }


  Future<AuthResponse> signInWithGoogle() async {
    final GoogleSignIn googleSignIn = GoogleSignIn(
      scopes: ['email'],
      serverClientId: '353945421030-k8k917gf7rhi54d05jhb1s476e2tm7v3.apps.googleusercontent.com',
    );
    final GoogleSignInAccount? account = await googleSignIn.signIn();
    
    if (account == null) {
      throw Exception('Google Sign In was cancelled.');
    }
    
    final GoogleSignInAuthentication auth = await account.authentication;
    final String? idToken = auth.idToken;
    
    if (idToken == null) {
      throw Exception('Failed to get Google ID Token.');
    }
    
    final response = await _client.post(
      Uri.parse('${ApiConstants.baseUrl}/auth/google'),
      headers: ApiConstants.defaultHeaders(),
      body: jsonEncode({'credential': idToken}),
    );
    
    _checkStatus(response);
    final authRes = AuthResponse.fromJson(jsonDecode(response.body));
    await _tokenStorage.saveToken(authRes.token);
    return authRes;
  }

  Future<AuthResponse> signInWithApple() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    
    // Fallback if backend does not yet have /api/auth/apple
    final response = await _client.post(
      Uri.parse('${ApiConstants.baseUrl}/auth/apple'), // Placeholder
      headers: ApiConstants.defaultHeaders(),
      body: jsonEncode({
        'credential': credential.identityToken,
        'email': credential.email,
        'given_name': credential.givenName,
        'family_name': credential.familyName,
      }),
    );
    
    _checkStatus(response);
    final authRes = AuthResponse.fromJson(jsonDecode(response.body));
    await _tokenStorage.saveToken(authRes.token);
    return authRes;
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConstants.baseUrl}/auth/login'),
      headers: ApiConstants.defaultHeaders(),
      body: jsonEncode({'email': email, 'password': password}),
    );
    _checkStatus(response);
    final auth = AuthResponse.fromJson(jsonDecode(response.body));
    await _tokenStorage.saveToken(auth.token); // persist token immediately
    return auth;
  }

  Future<void> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    String? address,
    String? city,
    String? state,
    double? latitude,
    double? longitude,
    String? postalCode,
    dynamic preferences,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConstants.baseUrl}/auth/register'),
      headers: ApiConstants.defaultHeaders(),
      body: jsonEncode({
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
        if (address != null) 'address': address,
        if (city != null) 'city': city,
        if (state != null) 'state': state,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (postalCode != null) 'postal_code': postalCode,
        if (postalCode != null) 'postalCode': postalCode,
        if (preferences != null) 'preferences': preferences,
      }),
    );
    _checkStatus(response);
    // Registration doesn't return a token, it requires email verification.
  }

  Future<void> verifyEmail({
    required String email,
    required String code,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConstants.baseUrl}/auth/verify-email'),
      headers: ApiConstants.defaultHeaders(),
      body: jsonEncode({
        'email': email,
        'token': code,
      }),
    );
    _checkStatus(response);
  }

  Future<AuthUser> getProfile() async {
    final response = await _client.get(
      Uri.parse('${ApiConstants.baseUrl}/auth/me'),
      headers: await _authHeaders(),
    );
    _checkStatus(response);
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic> && decoded.containsKey('user')) {
      return AuthUser.fromJson(decoded['user']);
    }
    return AuthUser.fromJson(decoded);
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
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (email != null) body['email'] = email;
    if (phone != null) body['phone'] = phone;
    if (gender != null) body['gender'] = gender;
    if (idNumber != null) body['id_number'] = idNumber;
    if (taxId != null) body['tax_id'] = taxId;
    if (taxCountry != null) body['tax_country'] = taxCountry;
    if (address != null) body['address'] = address;
    if (state != null) body['state'] = state;

    final response = await _client.patch(
      Uri.parse('${ApiConstants.baseUrl}/auth/profile'),
      headers: await _authHeaders(),
      body: jsonEncode(body),
    );
    _checkStatus(response);
  }

  Future<void> updateAvatar(String avatarUrl) async {
    final response = await _client.patch(
      Uri.parse('${ApiConstants.baseUrl}/auth/avatar'),
      headers: await _authHeaders(),
      body: jsonEncode({'avatar_url': avatarUrl}),
    );
    _checkStatus(response);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConstants.baseUrl}/auth/change-password'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );
    _checkStatus(response);
  }

  Future<void> forgotPassword(String email) async {
    final response = await _client.post(
      Uri.parse('${ApiConstants.baseUrl}/auth/forgot-password'),
      headers: ApiConstants.defaultHeaders(),
      body: jsonEncode({'email': email}),
    );
    _checkStatus(response);
  }

  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConstants.baseUrl}/auth/reset-password'),
      headers: ApiConstants.defaultHeaders(),
      body: jsonEncode({
        'token': token,
        'password': password,
      }),
    );
    _checkStatus(response);
  }

  Future<void> logout() async {
    try {
      await _client.post(
        Uri.parse('${ApiConstants.baseUrl}/auth/logout'),
        headers: await _authHeaders(),
      );
    } catch (_) {}
    await _tokenStorage.deleteToken();
  }

  Future<bool> isLoggedIn() => _tokenStorage.hasToken();

  void _checkStatus(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String errorMessage = 'Error ${response.statusCode}: ${response.reasonPhrase}';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body.containsKey('message')) {
          errorMessage = body['message'];
        } else if (body is Map && body.containsKey('detail')) {
          errorMessage = body['detail'];
        }
      } catch (_) {
        // ignore json decode errors
      }
      
      // Handle generic 401 if backend didn't provide a specific message
      if (response.statusCode == 401 && errorMessage.startsWith('Error 401')) {
        if (response.request != null && response.request!.url.path.contains('login')) {
          errorMessage = 'Invalid email or password.';
        } else {
          errorMessage = 'Session expired. Please log in again.';
        }
      }

      // Handle generic 403 if backend/Cloudflare blocked the mobile request
      if (response.statusCode == 403 && errorMessage.startsWith('Error 403')) {
        errorMessage = 'Access blocked by security firewall (403 Forbidden). Switch connection or try again.';
      }
      
      throw Exception(errorMessage);
    }
  }
}

