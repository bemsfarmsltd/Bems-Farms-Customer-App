import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class CustomerNotificationService {
  static final CustomerNotificationService _instance = CustomerNotificationService._internal();
  factory CustomerNotificationService() => _instance;
  static CustomerNotificationService get instance => _instance;
  CustomerNotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// Callback when customer taps on a notification
  static void Function(Map<String, dynamic> payload)? onNotificationTapped;

  static Future<void> showDriverArrivedNotification({
    required String orderId,
    String? driverName,
  }) => _instance._showDriverArrivedNotification(orderId: orderId, driverName: driverName);

  static Future<void> showReceiptConfirmedNotification({
    required String orderId,
  }) => _instance._showReceiptConfirmedNotification(orderId: orderId);

  static Future<void> showChatNotification({
    required String sender,
    required String message,
    String chatType = 'support',
  }) => _instance._showChatNotification(sender: sender, message: message, chatType: chatType);

  Future<void> init() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          try {
            final data = jsonDecode(response.payload!) as Map<String, dynamic>;
            onNotificationTapped?.call(data);
          } catch (_) {}
        }
      },
    );

    // Create high-importance notification channel for Android
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'bems_customer_delivery_alerts',
          'Delivery & Courier Alerts',
          description: 'Notifies when your courier reaches your doorstep and when orders update',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'bems_customer_chat_alerts',
          'Chat & Support Messages',
          description: 'Notifies for incoming messages from Customer Support and Chef Bems',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );
      await androidPlugin.requestNotificationsPermission();
    }

    _isInitialized = true;
  }

  Future<void> _showDriverArrivedNotification({
    required String orderId,
    String? driverName,
  }) async {
    await init();

    final cleanId = orderId.startsWith('#') ? orderId : '#$orderId';
    final courier = (driverName != null && driverName.isNotEmpty) ? driverName : 'Your courier';

    const androidDetails = AndroidNotificationDetails(
      'bems_customer_delivery_alerts',
      'Delivery & Courier Alerts',
      channelDescription: 'Doorstep courier arrival notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(''),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id: orderId.hashCode,
      title: 'Your Courier Has Arrived! 📍',
      body: '$courier is at your doorstep with Order $cleanId. Please meet them to receive and inspect your items.',
      notificationDetails: details,
      payload: jsonEncode({
        'type': 'driver_arrived',
        'order_id': orderId,
      }),
    );
  }

  Future<void> _showReceiptConfirmedNotification({
    required String orderId,
  }) async {
    await init();

    final cleanId = orderId.startsWith('#') ? orderId : '#$orderId';

    const androidDetails = AndroidNotificationDetails(
      'bems_customer_delivery_alerts',
      'Delivery & Courier Alerts',
      channelDescription: 'Goods receipt confirmation alerts',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      id: '${orderId}_confirmed'.hashCode,
      title: 'Goods Receipt Confirmed! ✓',
      body: 'Thank you! Order $cleanId has been marked as received. Enjoy your fresh harvest!',
      notificationDetails: details,
      payload: jsonEncode({
        'type': 'receipt_confirmed',
        'order_id': orderId,
      }),
    );
  }

  Future<void> _showChatNotification({
    required String sender,
    required String message,
    String chatType = 'support',
  }) async {
    await init();

    const androidDetails = AndroidNotificationDetails(
      'bems_customer_chat_alerts',
      'Chat & Support Messages',
      channelDescription: 'Notifications for incoming support and Chef Bems chat messages',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(''),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final notificationId = DateTime.now().millisecondsSinceEpoch % 100000;

    await _localNotifications.show(
      id: notificationId,
      title: sender,
      body: message,
      notificationDetails: details,
      payload: jsonEncode({
        'type': 'chat_message',
        'chat_type': chatType,
      }),
    );
  }
}
