import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'package:http/http.dart' as http;
import 'package:bems_farms/core/constants/app_colors.dart';
import 'package:bems_farms/core/network/api_constants.dart';
import 'package:bems_farms/features/auth/presentation/providers/auth_providers.dart';
import 'package:bems_farms/features/auth/data/repositories/token_storage.dart';
import 'package:bems_farms/features/orders/data/models/order_model.dart';
import 'package:bems_farms/features/orders/data/repositories/api_order_repository.dart';
import 'package:bems_farms/features/orders/presentation/pages/order_detail_page.dart';
import 'package:bems_farms/core/services/notification_service.dart';

class SupportChatPage extends ConsumerStatefulWidget {
  final String? initialOrderId;

  const SupportChatPage({super.key, this.initialOrderId});

  @override
  ConsumerState<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends ConsumerState<SupportChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ApiOrderRepository _orderRepo = ApiOrderRepository();
  final TokenStorage _tokenStorage = TokenStorage();

  Future<String> _getToken() async {
    final secureToken = await _tokenStorage.getToken();
    if (secureToken != null && secureToken.isNotEmpty) return secureToken;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('bems_farms_auth_token') ?? prefs.getString('auth_token') ?? '';
  }

  socket_io.Socket? _socket;
  Timer? _pollTimer;
  bool _isLoading = false;
  List<Map<String, dynamic>> _messages = [];
  List<Order> _recentOrders = [];
  bool _isLoadingOrders = false;

  final List<String> _quickActionPills = [
    'Where is my order?',
    'Delivery zones & tariffs',
    'Payment options & COD',
    'Speak to Support Agent',
  ];

  @override
  void initState() {
    super.initState();
    _fetchRecentOrders();
    _fetchMessages();
    _initSocket();

    _messageController.addListener(_onTextChanged);

    // Heartbeat polling every 4 seconds to keep chat synchronized
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) _fetchMessages(silent: true);
    });

    // If initial order was supplied, pre-fill or mention it
    if (widget.initialOrderId != null && widget.initialOrderId!.isNotEmpty) {
      _messageController.text = '@${widget.initialOrderId} ';
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _socket?.disconnect();
    _socket?.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _messageController.text;
    if (text.endsWith('@') || text.endsWith('/')) {
      _showOrderPickerModal();
    }
  }

  Future<void> _fetchRecentOrders() async {
    setState(() => _isLoadingOrders = true);
    try {
      final orders = await _orderRepo.getMyOrders();
      if (mounted) {
        setState(() {
          _recentOrders = orders;
          _isLoadingOrders = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingOrders = false);
    }
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final token = await _getToken();

      final headers = token.isNotEmpty
          ? ApiConstants.authHeaders(token)
          : ApiConstants.defaultHeaders();

      http.Response response;
      try {
        response = await http.get(
          Uri.parse('${ApiConstants.baseUrl}/support/messages'),
          headers: headers,
        );
      } catch (_) {
        response = await http.get(
          Uri.parse('${ApiConstants.baseUrl}/customer/support/messages'),
          headers: headers,
        );
      }

      debugPrint('SUPPORT FETCH STATUS: ${response.statusCode}');
      debugPrint('SUPPORT FETCH BODY: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List? msgs;
        if (data is Map && data['messages'] is List) {
          msgs = data['messages'];
        } else if (data is Map && data['data'] is List) {
          msgs = data['data'];
        } else if (data is List) {
          msgs = data;
        }

        if (msgs != null && mounted) {
          final hadChanges = msgs.length != _messages.length;
          if (hadChanges && _messages.isNotEmpty && msgs.length > _messages.length) {
            final lastMsg = msgs.last;
            if (lastMsg is Map) {
              final sender = (lastMsg['sender_type'] ?? lastMsg['sender'] ?? lastMsg['sender_role'] ?? lastMsg['role'] ?? '').toString().toLowerCase();
              final text = (lastMsg['message'] ?? lastMsg['text'] ?? '').toString();
              if (sender != 'user' && sender != 'customer' && text.isNotEmpty) {
                CustomerNotificationService.showChatNotification(
                  sender: 'Support Desk \u{1F4AC}',
                  message: text,
                  chatType: 'support',
                );
              }
            }
          }
          setState(() {
            _messages = List<Map<String, dynamic>>.from(msgs!);
            _isLoading = false;
          });
          if (hadChanges) _scrollToBottom();
        }
      } else {
        debugPrint('SUPPORT FETCH FAILED: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Failed to fetch messages: $e');
    } finally {
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  void _initSocket() async {
    try {
      final token = await _getToken();

      _socket = socket_io.io(
        'https://api.bemsfarms.com',
        socket_io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .setAuth({'token': token})
            .enableAutoConnect()
            .build(),
      );

      _socket?.onConnect((_) {
        debugPrint('Connected to unified support chat socket');
      });

      _socket?.on('chatMessage', (data) {
        if (mounted && data != null && data is Map) {
          final msgMap = Map<String, dynamic>.from(data);
          setState(() {
            _messages.add(msgMap);
          });
          _scrollToBottom();

          final sender = (msgMap['sender'] ?? msgMap['sender_role'] ?? '').toString().toLowerCase();
          final text = (msgMap['message'] ?? msgMap['text'] ?? '').toString();
          if (sender != 'user' && sender != 'customer' && text.isNotEmpty) {
            CustomerNotificationService.showChatNotification(
              sender: 'Support Agent',
              message: text,
              chatType: 'support',
            );
          }
        }
      });

      _socket?.onDisconnect((_) => debugPrint('Disconnected from support chat'));
    } catch (e) {
      debugPrint('Support socket init error: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? customText]) async {
    final text = customText ?? _messageController.text.trim();
    if (text.isEmpty) return;

    if (customText == null) {
      _messageController.clear();
    }

    final user = ref.read(authProvider).value;
    final userName = user?.name ?? 'You';

    final tempMsg = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'sender_type': 'customer',
      'message': text,
      'user_name': userName,
      'created_at': DateTime.now().toIso8601String(),
    };

    setState(() {
      _messages.add(tempMsg);
    });
    _scrollToBottom();

    // Send to backend
    try {
      final token = await _getToken();
      final headers = token.isNotEmpty
          ? ApiConstants.authHeaders(token)
          : ApiConstants.defaultHeaders();

      final body = jsonEncode({
        'message': text,
        'order_id': null,
        'delivery_id': null,
        'enable_ai': true,
      });

      http.Response response;
      try {
        response = await http.post(
          Uri.parse('${ApiConstants.baseUrl}/support/messages'),
          headers: headers,
          body: body,
        );
      } catch (_) {
        response = await http.post(
          Uri.parse('${ApiConstants.baseUrl}/customer/support/messages'),
          headers: headers,
          body: body,
        );
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _fetchMessages(silent: true);
      } else {
        debugPrint('Support message failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Support send error: $e');
    }
  }

  void _showOrderPickerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.alternate_email, color: AppColors.primary, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Attach Recent Order',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Text(
                  'Select an order to mention in your support message:',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
              const Divider(height: 16),
              Expanded(
                child: _isLoadingOrders
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : _recentOrders.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                const Text('No recent orders found', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                const Text('You have not placed any orders yet.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: _recentOrders.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final order = _recentOrders[index];
                              return InkWell(
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _attachOrderToText(order.id);
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.local_shipping_outlined, color: AppColors.primary, size: 22),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              order.shortId,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              order.items.isNotEmpty
                                                  ? order.items.map((e) => e.name).take(2).join(', ')
                                                  : 'Produce order',
                                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(order.status).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              order.status.label,
                                              style: TextStyle(
                                                color: _getStatusColor(order.status),
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            order.formattedTotal,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _attachOrderToText(String orderId) {
    String currentText = _messageController.text;
    // Replace trailing @ or /
    if (currentText.endsWith('@') || currentText.endsWith('/')) {
      currentText = currentText.substring(0, currentText.length - 1);
    }
    if (currentText.isNotEmpty && !currentText.endsWith(' ')) {
      currentText += ' ';
    }
    currentText += '@$orderId ';
    _messageController.text = currentText;
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: _messageController.text.length),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.processing:
        return Colors.orange;
      case OrderStatus.shipped:
      case OrderStatus.tracking:
        return Colors.blue;
      case OrderStatus.delivered:
        return const Color(0xFF2E7D32);
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;
    final userName = user?.name ?? 'Customer';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Column(
          children: [
            Text('Order & Support', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: Color(0xFF00E676), size: 8),
                SizedBox(width: 4),
                Text('Typically replies in minutes', style: TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => _fetchMessages(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    children: [
                      // BEMS AI ASSISTANT Greeting Card
                      _buildAiWelcomeCard(userName),

                      const SizedBox(height: 16),

                      // Message Bubbles
                      ..._messages.map((msg) => _buildMessageBubble(msg)),
                    ],
                  ),
          ),

          // Quick Action Suggestion Pills
          _buildQuickActionPills(),

          // Input Bar with @ button
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildAiWelcomeCard(String userName) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Support Avatar
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
            ],
          ),
          child: const Center(
            child: Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 22),
          ),
        ),
        const SizedBox(width: 12),
        // Welcome Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16).copyWith(topLeft: const Radius.circular(4)),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BEMS SUPPORT TEAM',
                  style: TextStyle(
                    color: Color(0xFF78909C),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Hello $userName! 👋 Welcome to Bems Farms Customer Support.',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
                const SizedBox(height: 10),
                const Text(
                  'You can ask about tracking, delivery fees, return requests, or type "@" or "/" to reference any of your recent orders!',
                  style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final senderType = (msg['sender_type'] ?? msg['sender'] ?? msg['sender_role'] ?? msg['role'])?.toString().toLowerCase() ?? 'customer';
    final isCustomer = senderType == 'customer' || senderType == 'user' || senderType == 'client';
    final messageText = (msg['message'] ?? msg['text'] ?? msg['content'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isCustomer ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isCustomer) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Center(
                child: Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 18),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isCustomer ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: isCustomer ? const Radius.circular(0) : const Radius.circular(16),
                  topLeft: !isCustomer ? const Radius.circular(0) : const Radius.circular(16),
                ),
                border: isCustomer ? null : Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: _buildRichMessageContent(messageText, isCustomer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRichMessageContent(String text, bool isCustomer) {
    // Check if contains @ORD
    final orderRegex = RegExp(r'(@[A-Za-z0-9_-]+)');
    final matches = orderRegex.allMatches(text);

    if (matches.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          color: isCustomer ? Colors.white : Colors.black87,
          fontSize: 14,
          height: 1.3,
        ),
      );
    }

    final spans = <InlineSpan>[];
    int lastIndex = 0;

    for (final m in matches) {
      if (m.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, m.start),
          style: TextStyle(color: isCustomer ? Colors.white : Colors.black87, fontSize: 14),
        ));
      }

      final tag = m.group(0)!;
      final orderRef = tag.replaceAll('@', '');

      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => OrderDetailPage(orderId: orderRef)),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isCustomer ? Colors.white24 : AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isCustomer ? Colors.white70 : AppColors.primary,
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inventory_2, size: 12, color: isCustomer ? Colors.white : AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  tag,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isCustomer ? Colors.white : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ));

      lastIndex = m.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: TextStyle(color: isCustomer ? Colors.white : Colors.black87, fontSize: 14),
      ));
    }

    return Text.rich(TextSpan(children: spans));
  }

  Widget _buildQuickActionPills() {
    return Container(
      height: 48,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _quickActionPills.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final pill = _quickActionPills[index];
          return ActionChip(
            label: Text(pill),
            labelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E3A2B),
            ),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.green.shade200),
            ),
            onPressed: () => _sendMessage(pill),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Dedicated @ Attachment Button
            GestureDetector(
              onTap: _showOrderPickerModal,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: const Center(
                  child: Text(
                    '@',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Input Text Field
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type question... Use @ or / to attach order',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 10),

            // Send Button with Up Arrow
            GestureDetector(
              onTap: () => _sendMessage(),
              child: Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.arrow_upward, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
