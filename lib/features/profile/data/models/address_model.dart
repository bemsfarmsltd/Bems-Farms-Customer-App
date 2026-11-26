class Address {
  final String id;
  final String label;
  final String street;
  final String city;
  final String state;
  final bool isDefault;
  final String recipientName;
  final String phone;
  final String postalCode;
  final bool isVerified;
  final double? latitude;
  final double? longitude;

  Address({
    required this.id,
    required this.label,
    required this.street,
    required this.city,
    required this.state,
    this.isDefault = false,
    this.recipientName = '',
    this.phone = '',
    this.postalCode = '',
    this.isVerified = false,
    this.latitude,
    this.longitude,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    final lat = double.tryParse(
      json['latitude']?.toString() ??
      json['lat']?.toString() ??
      json['delivery_lat']?.toString() ??
      '',
    );
    final lng = double.tryParse(
      json['longitude']?.toString() ??
      json['lng']?.toString() ??
      json['delivery_lng']?.toString() ??
      '',
    );
    final hasValidGps = (lat != null && lat != 0.0) && (lng != null && lng != 0.0);
    final isExplicitlyVerified = _parseBool(json['is_verified']) ||
        _parseBool(json['isVerified']) ||
        _parseBool(json['gps_verified']) ||
        _parseBool(json['verified']);

    return Address(
      id: json['id']?.toString() ?? '',
      label: json['label'] ?? '',
      street: json['street']?.toString() ??
          json['address']?.toString() ??
          json['street_address']?.toString() ??
          json['address_line_1']?.toString() ??
          '',
      city: json['city']?.toString() ?? json['lga']?.toString() ?? '',
      state: json['state'] ?? '',
      isDefault: json['is_default'] ?? json['isDefault'] ?? false,
      recipientName: json['recipient_name'] ?? json['recipientName'] ?? json['name'] ?? '',
      phone: json['phone'] ?? json['phone_number'] ?? '',
      postalCode: json['postal_code']?.toString() ?? json['postalCode']?.toString() ?? '',
      isVerified: isExplicitlyVerified || hasValidGps,
      latitude: lat,
      longitude: lng,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'street': street,
      'city': city,
      'state': state,
      'is_default': isDefault,
      'recipient_name': recipientName,
      'recipientName': recipientName,
      'phone': phone,
      'phone_number': phone,
      'postal_code': postalCode,
      'postalCode': postalCode,
      'is_verified': isVerified,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  Address copyWith({
    String? id,
    String? label,
    String? street,
    String? city,
    String? state,
    bool? isDefault,
    String? recipientName,
    String? phone,
    String? postalCode,
    bool? isVerified,
    double? latitude,
    double? longitude,
  }) {
    return Address(
      id: id ?? this.id,
      label: label ?? this.label,
      street: street ?? this.street,
      city: city ?? this.city,
      state: state ?? this.state,
      isDefault: isDefault ?? this.isDefault,
      recipientName: recipientName ?? this.recipientName,
      phone: phone ?? this.phone,
      postalCode: postalCode ?? this.postalCode,
      isVerified: isVerified ?? this.isVerified,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value == true || value == 1 || value == '1' || value == 'true' || value == 'True') return true;
    return false;
  }
}
