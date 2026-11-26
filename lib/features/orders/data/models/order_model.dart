enum OrderStatus { processing, shipped, delivered, cancelled, tracking }

extension OrderStatusX on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.processing:
        return 'Packaging';
      case OrderStatus.shipped:
        return 'In Transit';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.tracking:
        return 'Tracking';
    }
  }

  /// Maps the raw string coming from the API (or mock) to the enum.
  static OrderStatus fromString(String value) {
    switch (value.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_')) {
      case 'shipped':
      case 'in_transit':
      case 'en_route':
      case 'enroute':
      case 'picked_up':
      case 'pickedup':
      case 'on_the_way':
      case 'dispatched':
      case 'arrived':
      case 'driver_arrived':
        return OrderStatus.shipped;
      case 'delivered':
      case 'completed':
        return OrderStatus.delivered;
      case 'cancelled':
      case 'canceled':
      case 'failed':
        return OrderStatus.cancelled;
      case 'tracking':
        return OrderStatus.tracking;
      default:
        return OrderStatus.processing;
    }
  }
}

class OrderItem {
  final String productId;
  final String name;
  final String imageUrl;
  final String unit;
  final int quantity;
  final double price;

  const OrderItem({
    required this.productId,
    required this.name,
    required this.imageUrl,
    required this.unit,
    required this.quantity,
    required this.price,
  });

  double get subtotal => price * quantity;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['product_id']?.toString() ?? '',
      name: json['name'] ?? '',
      imageUrl: json['image_url'] ?? json['imageUrl'] ?? json['image'] ?? json['product_image'] ?? '',
      unit: json['unit'] ?? 'kg',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'name': name,
        'image_url': imageUrl,
        'unit': unit,
        'quantity': quantity,
        'price': price,
      };
}

class Order {
  final String id;
  final OrderStatus status;
  final List<OrderItem> items;
  final double deliveryFee;
  final String paymentMethod;
  final String deliveryAddress;
  final DateTime createdAt;
  final Map<String, dynamic>? rawJson;

  const Order({
    required this.id,
    required this.status,
    required this.items,
    required this.deliveryFee,
    this.paymentMethod = 'cod',
    required this.deliveryAddress,
    required this.createdAt,
    this.rawJson,
  });

  double get subtotal => items.fold(0, (sum, i) => sum + i.subtotal);
  double get total => subtotal + deliveryFee;

  String get formattedTotal {
    final formatted = total.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return '₦$formatted';
  }

  String get shortId => id.startsWith('#') ? id : '#$id';
  String get orderNumber => id.startsWith('#') ? id.substring(1) : id;

  String? get driverName {
    if (rawJson?['driver_name'] != null && rawJson!['driver_name'].toString().isNotEmpty) {
      return rawJson!['driver_name'].toString();
    }
    if (rawJson?['courier_name'] != null && rawJson!['courier_name'].toString().isNotEmpty) {
      return rawJson!['courier_name'].toString();
    }
    if (rawJson?['assigned_driver'] != null && rawJson!['assigned_driver'].toString().isNotEmpty) {
      return rawJson!['assigned_driver'].toString();
    }
    final d = rawJson?['driver'] ?? rawJson?['courier'] ?? rawJson?['delivery']?['driver'];
    if (d is String && d.isNotEmpty) return d;
    if (d is Map) {
      final name = d['name'] ?? d['full_name'] ?? d['username'];
      if (name != null && name.toString().isNotEmpty) return name.toString();
      final first = d['first_name']?.toString() ?? '';
      final last = d['last_name']?.toString() ?? '';
      final combined = '$first $last'.trim();
      if (combined.isNotEmpty) return combined;
    }
    final delivDriver = rawJson?['delivery']?['driver_name'];
    if (delivDriver != null && delivDriver.toString().isNotEmpty) return delivDriver.toString();
    return null;
  }

  String? get driverPhone {
    if (rawJson?['driver_phone'] != null && rawJson!['driver_phone'].toString().isNotEmpty) {
      return rawJson!['driver_phone'].toString();
    }
    if (rawJson?['courier_phone'] != null && rawJson!['courier_phone'].toString().isNotEmpty) {
      return rawJson!['courier_phone'].toString();
    }
    final d = rawJson?['driver'] ?? rawJson?['courier'] ?? rawJson?['delivery']?['driver'];
    if (d is Map) {
      final p = d['phone'] ?? d['phone_number'] ?? d['telephone'] ?? d['mobile'];
      if (p != null && p.toString().isNotEmpty) return p.toString();
    }
    final delivPhone = rawJson?['delivery']?['driver_phone'];
    if (delivPhone != null && delivPhone.toString().isNotEmpty) return delivPhone.toString();
    return null;
  }

  String? get driverAvatar {
    if (rawJson?['driver_avatar'] != null && rawJson!['driver_avatar'].toString().isNotEmpty) {
      return rawJson!['driver_avatar'].toString();
    }
    final d = rawJson?['driver'] ?? rawJson?['courier'] ?? rawJson?['delivery']?['driver'];
    if (d is Map) {
      return d['avatar_url']?.toString() ?? d['avatar']?.toString() ?? d['photo']?.toString();
    }
    return null;
  }

  String? get driverVehicle {
    if (rawJson?['driver_vehicle'] != null && rawJson!['driver_vehicle'].toString().isNotEmpty) {
      return rawJson!['driver_vehicle'].toString();
    }
    final d = rawJson?['driver'] ?? rawJson?['courier'] ?? rawJson?['delivery']?['driver'];
    if (d is Map) {
      final type = d['vehicle_type']?.toString() ?? d['vehicle']?.toString() ?? 'Courier Fleet';
      final plate = d['vehicle_plate']?.toString() ?? '';
      return plate.isNotEmpty ? '$type ($plate)' : type;
    }
    return null;
  }

  bool get hasDriver => driverName != null && driverName!.isNotEmpty;
  bool get isDriverAssigned => hasDriver || rawJson?['driver_id'] != null || rawJson?['courier_id'] != null || rawJson?['assigned_driver_id'] != null;

  String get estimatedDeliveryTime {
    final eta = rawJson?['estimated_delivery_time'] ?? 
                rawJson?['delivery_eta'] ?? 
                rawJson?['eta'];
    if (eta != null && eta.toString().isNotEmpty) return eta.toString();
    if (status == OrderStatus.delivered) return 'Delivered';
    if (status == OrderStatus.shipped) return 'Today by 2:00 PM';
    return 'Tomorrow by 2:00 PM';
  }

  double? get deliveryLat => double.tryParse(rawJson?['delivery_lat']?.toString() ?? '');
  double? get deliveryLng => double.tryParse(rawJson?['delivery_lng']?.toString() ?? '');
  double? get hubLat => double.tryParse(rawJson?['hub_lat']?.toString() ?? '');
  double? get hubLng => double.tryParse(rawJson?['hub_lng']?.toString() ?? '');
  double? get driverLat => double.tryParse(rawJson?['driver_lat']?.toString() ?? '');
  double? get driverLng => double.tryParse(rawJson?['driver_lng']?.toString() ?? '');
  String? get receiptUrl => rawJson?['receipt_url']?.toString() ?? rawJson?['invoice_url']?.toString();

  bool get isDriverArrived {
    final ds = rawJson?['delivery_status']?.toString().toLowerCase();
    final st = rawJson?['status']?.toString().toLowerCase();
    return ds == 'arrived' || st == 'arrived' || ds == 'driver_arrived' || rawJson?['arrived_at'] != null;
  }

  bool get isCustomerConfirmed {
    final cc = rawJson?['customer_confirmed'];
    return cc == true || cc == 1 || cc == 'true' || rawJson?['confirmed_at'] != null;
  }

  bool get isInTransit {
    if (status == OrderStatus.shipped || status == OrderStatus.tracking) return true;
    final ds = rawJson?['delivery_status']?.toString().toLowerCase().trim();
    final st = rawJson?['status']?.toString().toLowerCase().trim();
    return ds == 'en_route' || ds == 'picked_up' || ds == 'in_transit' || ds == 'on_the_way' || ds == 'arrived' ||
           st == 'en_route' || st == 'picked_up' || st == 'in_transit' || st == 'on_the_way' || st == 'arrived';
  }

  bool get isDelivered {
    if (status == OrderStatus.delivered) return true;
    final ds = rawJson?['delivery_status']?.toString().toLowerCase().trim();
    final st = rawJson?['status']?.toString().toLowerCase().trim();
    return ds == 'delivered' || ds == 'completed' || st == 'delivered' || st == 'completed';
  }

  /// Returns a copy of this order with a new status (for mock state transitions).
  Order copyWith({OrderStatus? status}) {
    return Order(
      id: id,
      status: status ?? this.status,
      items: items,
      deliveryFee: deliveryFee,
      paymentMethod: paymentMethod,
      deliveryAddress: deliveryAddress,
      createdAt: createdAt,
      rawJson: rawJson,
    );
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List<dynamic>? ?? [])
        .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
        .toList();
    
    double explicitFee = double.tryParse(json['delivery_fee']?.toString() ?? json['deliveryFee']?.toString() ?? json['shipping_fee']?.toString() ?? '0') ?? 0.0;
    
    if (explicitFee == 0.0 && json['total'] != null) {
      final total = double.tryParse(json['total']?.toString() ?? '0') ?? 0.0;
      final discount = double.tryParse(json['discount_amount']?.toString() ?? '0') ?? 0.0;
      final subtotal = itemsList.fold(0.0, (sum, i) => sum + i.subtotal);
      if (total > 0) {
        explicitFee = total + discount - subtotal;
        if (explicitFee < 0) explicitFee = 0.0; // sanity check
      }
    }

    final rawDeliveryStatus = (json['delivery_status'] ?? json['deliveryStatus'])?.toString().trim();
    final rawOrderStatus = (json['status'] ?? json['order_status'])?.toString().trim();

    OrderStatus resolvedStatus;
    if (rawDeliveryStatus != null && rawDeliveryStatus.isNotEmpty && rawDeliveryStatus.toLowerCase() != 'pending') {
      resolvedStatus = OrderStatusX.fromString(rawDeliveryStatus);
      if (resolvedStatus == OrderStatus.processing && rawOrderStatus != null && rawOrderStatus.isNotEmpty) {
        resolvedStatus = OrderStatusX.fromString(rawOrderStatus);
      }
    } else {
      resolvedStatus = OrderStatusX.fromString(rawOrderStatus ?? 'processing');
    }

    return Order(
      id: json['id']?.toString() ?? json['order_ref']?.toString() ?? '',
      status: resolvedStatus,
      items: itemsList,
      deliveryFee: explicitFee,
      paymentMethod: json['payment_method']?.toString() ?? json['paymentMethod']?.toString() ?? 'cod',
      deliveryAddress: json['delivery_address']?.toString() ?? json['address']?.toString() ?? json['shippingAddress']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      rawJson: json,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'status': status.label.toLowerCase(),
        'items': items.map((e) => e.toJson()).toList(),
        'delivery_fee': deliveryFee,
        'delivery_address': deliveryAddress,
        'created_at': createdAt.toIso8601String(),
      };
}
