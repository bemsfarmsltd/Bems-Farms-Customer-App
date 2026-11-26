class Product {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final String category;
  final String unit;
  final String description;
  final double rating;
  final int reviewCount;
  final bool isOnDeal;
  final Map<String, String> nutritionalInfo;
  final int stock;
  final bool availableForSale;

  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.category,
    required this.unit,
    required this.description,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.isOnDeal = false,
    this.nutritionalInfo = const {},
    this.stock = 0,
    this.availableForSale = true,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      price: parseDouble(json['price']),
      imageUrl: json['image_url'] ?? json['imageUrl'] ?? '',
      category: (json['category'] is String && (json['category'] as String).isNotEmpty)
          ? json['category']
          : (json['category_name'] ?? (json['category'] is Map ? json['category']['name'] : null) ?? 'PRODUCE').toString(),
      unit: json['unit'] ?? 'kg',
      description: json['description'] ?? '',
      rating: parseDouble(json['rating'] ?? json['avg_rating']),
      reviewCount: parseInt(json['review_count'] ?? json['reviewCount']),
      isOnDeal: json['is_on_deal'] ?? json['isOnDeal'] ?? json['is_featured'] ?? false,
      stock: parseInt(json['stock_quantity'] ?? json['stock'] ?? 999),
      availableForSale: json['available_for_sale'] ?? true,
      nutritionalInfo: (json['nutritional_info'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v.toString())) ??
          {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'imageUrl': imageUrl,
      'category': category,
      'unit': unit,
      'description': description,
      'rating': rating,
      'reviewCount': reviewCount,
      'isOnDeal': isOnDeal,
      'stock': stock,
      'availableForSale': availableForSale,
      'nutritionalInfo': nutritionalInfo,
    };
  }

  Product copyWith({
    String? id,
    String? name,
    double? price,
    String? imageUrl,
    String? category,
    String? unit,
    String? description,
    double? rating,
    int? reviewCount,
    bool? isOnDeal,
    Map<String, String>? nutritionalInfo,
    int? stock,
    bool? availableForSale,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      description: description ?? this.description,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      isOnDeal: isOnDeal ?? this.isOnDeal,
      nutritionalInfo: nutritionalInfo ?? this.nutritionalInfo,
      stock: stock ?? this.stock,
      availableForSale: availableForSale ?? this.availableForSale,
    );
  }

  bool get isOutOfStock => stock <= 0 || !availableForSale;

  String get formattedPrice {
    final formatted = price.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return '₦$formatted / $unit';
  }
}

class ProductReview {
  final String id;
  final String productId;
  final String userId;
  final String userName;
  final double rating;
  final String comment;
  final DateTime createdAt;

  const ProductReview({
    required this.id,
    required this.productId,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory ProductReview.fromJson(Map<String, dynamic> json) {
    String parsedName = '';
    final userObj = json['user'] ?? json['customer'] ?? json['author'] ?? json['reviewer'];
    if (userObj is Map) {
      final first = userObj['first_name']?.toString() ?? '';
      final last = userObj['last_name']?.toString() ?? '';
      final combined = '$first $last'.trim();
      parsedName = userObj['name']?.toString() ??
          userObj['full_name']?.toString() ??
          (combined.isNotEmpty ? combined : null) ??
          userObj['username']?.toString() ??
          '';
    } else if (userObj is String && userObj.isNotEmpty) {
      parsedName = userObj;
    }

    if (parsedName.isEmpty) {
      parsedName = json['user_name']?.toString() ??
          json['userName']?.toString() ??
          json['customer_name']?.toString() ??
          json['reviewer_name']?.toString() ??
          json['name']?.toString() ??
          json['author_name']?.toString() ??
          '';
    }

    if (parsedName.trim().isEmpty) {
      parsedName = 'Customer';
    }

    return ProductReview(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userName: parsedName,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      comment: json['comment'] ?? '',
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
