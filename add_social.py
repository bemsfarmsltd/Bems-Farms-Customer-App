import os
file = r'C:\Users\XPS\Downloads\bems_farms_final\bems_farms_final\lib\features\auth\data\repositories\auth_repository.dart'
content = open(file, 'r', encoding='utf-8').read()

import_statement = "import 'package:google_sign_in/google_sign_in.dart';\nimport 'package:sign_in_with_apple/sign_in_with_apple.dart';\n"
content = import_statement + content

social_methods = """
  Future<AuthResponse> signInWithGoogle() async {
    final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email']);
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
      Uri.parse('\/auth/google'),
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
      Uri.parse('\/auth/apple'), // Placeholder
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
"""

content = content.replace('  Future<AuthResponse> login({', social_methods + '\n  Future<AuthResponse> login({')
open(file, 'w', encoding='utf-8').write(content)
