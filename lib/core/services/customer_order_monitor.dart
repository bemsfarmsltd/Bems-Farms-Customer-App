import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../features/orders/data/repositories/api_order_repository.dart';
import '../../features/orders/presentation/providers/order_providers.dart';
import 'notification_service.dart';

class CustomerNotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final String type;
  final String orderId;
  bool isRead;

  CustomerNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.type,
    required this.orderId,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'timestamp': timestamp.toIso8601String(),
    'type': type,
    'orderId': orderId,
    'isRead': isRead,
  };

  factory CustomerNotificationItem.fromJson(Map<String, dynamic> json) => CustomerNotificationItem(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    body: json['body'] ?? '',
    timestamp: json['timestamp'] != null ? DateTime.tryParse(json['timestamp']) ?? DateTime.now() : DateTime.now(),
    type: json['type'] ?? '',
    orderId: json['orderId'] ?? '',
    isRead: json['isRead'] ?? false,
  );
}

class CustomerNotificationStore extends ChangeNotifier {
  static final CustomerNotificationStore _instance = CustomerNotificationStore._internal();
  factory CustomerNotificationStore() => _instance;
  CustomerNotificationStore._internal() {
    _loadFromPrefs();
  }

  final List<CustomerNotificationItem> _items = [];
  List<CustomerNotificationItem> get items => List.unmodifiable(_items);
  int get unreadCount => _items.where((i) => !i.isRead).length;

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('customer_notifications_history');
      if (raw != null) {
        final list = (jsonDecode(raw) as List).map((e) => CustomerNotificationItem.fromJson(e)).toList();
        _items.clear();
        _items.addAll(list);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(_items.map((e) => e.toJson()).toList());
      await prefs.setString('customer_notifications_history', raw);
    } catch (_) {}
  }

  void addNotification({
    required String title,
    required String body,
    required String type,
    required String orderId,
  }) {
    final item = CustomerNotificationItem(
      id: '${DateTime.now().millisecondsSinceEpoch}_$orderId',
      title: title,
      body: body,
      timestamp: DateTime.now(),
      type: type,
      orderId: orderId,
    );
    _items.insert(0, item);
    _saveToPrefs();
    notifyListeners();
  }

  void markAllAsRead() {
    for (var item in _items) {
      item.isRead = true;
    }
    _saveToPrefs();
    notifyListeners();
  }

  void clearAll() {
    _items.clear();
    _saveToPrefs();
    notifyListeners();
  }
}

final customerNotificationStoreProvider = ChangeNotifierProvider<CustomerNotificationStore>((ref) {
  return CustomerNotificationStore();
});

final customerOrderMonitorProvider = Provider<CustomerOrderMonitor>((ref) {
  final monitor = CustomerOrderMonitor(ref);
  monitor.start();
  ref.onDispose(() => monitor.dispose());
  return monitor;
});

class CustomerOrderMonitor with WidgetsBindingObserver {
  final Ref _ref;
  final ApiOrderRepository _orderRepo = ApiOrderRepository();
  Timer? _poller;
  io.Socket? _socket;
  final Set<String> _notifiedArrivalOrderIds = {};
  final Set<String> _notifiedInTransitOrderIds = {};

  CustomerOrderMonitor(this._ref);

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _initSocket();
    _checkOrders();
    // 8-second real-time heartbeat for live status updates without user interaction
    _poller?.cancel();
    _poller = Timer.periodic(const Duration(seconds: 8), (_) => _checkOrders());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Instantly refresh when returning from background
      _checkOrders();
    }
  }

  void _initSocket() {
    try {
      _socket?.disconnect();
      _socket?.dispose();
      _socket = io.io(
        'https://api.bemsfarms.com',
        io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .build(),
      );

      _socket?.on('driver_arrived', (data) {
        if (data is Map && data['order_id'] != null) {
          _triggerArrival(data['order_id'].toString(), data['driver_name']?.toString());
        }
        _checkOrders();
      });

      void handleUpdate(dynamic _) {
        _checkOrders();
      }

      _socket?.on('order_status_updated', handleUpdate);
      _socket?.on('delivery_status_updated', handleUpdate);
      _socket?.on('order_updated', handleUpdate);
      _socket?.on('order_assigned', handleUpdate);
      _socket?.on('order_delivered', handleUpdate);
      _socket?.on('driver_location_update', handleUpdate);
    } catch (e) {
      debugPrint('Customer socket error: $e');
    }
  }

  Future<void> _checkOrders() async {
    try {
      // Silently update Riverpod ordersProvider so all order list & detail views re-render live
      _ref.read(ordersProvider.notifier).refreshSilently();
      final orders = await _orderRepo.getMyOrders();
      for (final order in orders) {
        // 1. Driver Arrived Notification
        if (order.isDriverArrived && !_notifiedArrivalOrderIds.contains(order.id)) {
          _triggerArrival(order.id, order.driverName, orderRef: order.shortId);
        }

        // 2. In Transit Notification
        if (order.isInTransit && !order.isDriverArrived && !_notifiedInTransitOrderIds.contains(order.id)) {
          _notifiedInTransitOrderIds.add(order.id);
          CustomerNotificationStore().addNotification(
            title: 'Order In Transit 🚚',
            body: 'Order ${order.shortId} is on the way to your delivery address.',
            type: 'in_transit',
            orderId: order.id,
          );
        }
      }
    } catch (_) {}
  }

  void _triggerArrival(String orderId, String? driverName, {String? orderRef}) {
    if (_notifiedArrivalOrderIds.contains(orderId)) return;
    _notifiedArrivalOrderIds.add(orderId);

    final cleanRef = orderRef ?? '#$orderId';
    final courier = (driverName != null && driverName.isNotEmpty) ? driverName : 'Your courier';

    // Ring real local notification with sound, vibration and banner
    CustomerNotificationService.showDriverArrivedNotification(
      orderId: cleanRef,
      driverName: courier,
    );

    // Save to real notification center
    CustomerNotificationStore().addNotification(
      title: 'Courier Has Arrived! 📍',
      body: '$courier is at your doorstep with Order $cleanRef. Tap to confirm receipt of your goods.',
      type: 'driver_arrived',
      orderId: orderId,
    );
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poller?.cancel();
    _poller = null;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
