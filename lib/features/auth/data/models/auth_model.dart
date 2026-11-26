class AuthUser {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? gender;
  final String? idNumber;
  final String? taxId;
  final String? taxCountry;
  final String? address;
  final String? city;
  final String? state;
  final String? avatarUrl;
  final dynamic preferences;

  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.gender,
    this.idNumber,
    this.taxId,
    this.taxCountry,
    this.address,
    this.city,
    this.state,
    this.avatarUrl,
    this.preferences,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      gender: json['gender'],
      idNumber: json['id_number'],
      taxId: json['tax_id'],
      taxCountry: json['tax_country'],
      address: json['address'],
      city: json['city'],
      state: json['state'],
      avatarUrl: json['avatar_url'] ?? json['avatar'] ?? json['profile_image'] ?? json['profile_picture'] ?? json['image'],
      preferences: json['preferences'],
    );
  }
}

/// The full response from POST /auth/login and POST /auth/register.
/// Backend must return: { "user": {...}, "token": "eyJ..." }
class AuthResponse {
  final AuthUser user;
  final String token;

  const AuthResponse({required this.user, required this.token});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      token: json['token'] ?? '',
    );
  }
}
