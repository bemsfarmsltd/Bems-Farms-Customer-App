import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bems_farms/core/constants/app_colors.dart';
import 'package:bems_farms/features/ai/presentation/providers/ai_providers.dart';
import 'package:bems_farms/features/ai/data/models/ai_conversation.dart';
import 'package:bems_farms/features/auth/presentation/providers/auth_providers.dart';
import 'package:bems_farms/core/services/notification_service.dart';

class ChefBemsChatPage extends ConsumerStatefulWidget {
  const ChefBemsChatPage({super.key});

  @override
  ConsumerState<ChefBemsChatPage> createState() => _ChefBemsChatPageState();
}

class _ChefBemsChatPageState extends ConsumerState<ChefBemsChatPage> {
  final _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<AiMessage> _messages = [];
  bool _isLoading = false;
  String? _currentConversationId;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// Extracts the assistant's reply text from the various response shapes.
  String _extractReply(Map response) {
    String replyContent = "I received a response but couldn't parse it.";

    final data = response['data'];

    if (response['message'] is String) {
      replyContent = response['message'] as String;
    } else if (response['reply'] is String) {
      replyContent = response['reply'] as String;
    } else if (data is Map && data['message'] != null) {
      replyContent = data['message'].toString();
    } else if (response['content'] is String) {
      replyContent = response['content'] as String;
    } else if (data is String) {
      replyContent = data;
    }

    return replyContent;
  }

  /// Extracts a conversation/session id from the various response shapes.
  String? _extractId(Map response) {
    String? extractedId;

    if (response.containsKey('session_id')) {
      extractedId = response['session_id']?.toString();
    } else if (response.containsKey('conversation_id')) {
      extractedId = response['conversation_id']?.toString();
    } else if (response.containsKey('id')) {
      extractedId = response['id']?.toString();
    } else if (response.containsKey('_id')) {
      extractedId = response['_id']?.toString();
    } else if (response['data'] is Map) {
      final dataMap = response['data'] as Map;
      extractedId = dataMap['session_id']?.toString() ??
          dataMap['conversation_id']?.toString() ??
          dataMap['id']?.toString() ??
          dataMap['_id']?.toString();
      if (extractedId == null && dataMap['conversation'] is Map) {
        final conv = dataMap['conversation'] as Map;
        extractedId = conv['_id']?.toString() ?? conv['id']?.toString();
      }
    }

    return extractedId;
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(AiMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: 'user',
        content: text,
        createdAt: DateTime.now(),
      ));
      _messageController.clear();
      _isLoading = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    // Generate a session ID client-side if this is a new chat, exactly like the web frontend does!
    if (_currentConversationId == null) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final randomStr = Random().nextInt(1000000).toRadixString(36);
      _currentConversationId = 'session_${timestamp}_$randomStr';

      // Optimistically insert it into the sidebar
      ref
          .read(conversationsProvider('chef').notifier)
          .addLocalConversation(_currentConversationId!, text);
    }

    try {
      final repo = ref.read(aiRepositoryProvider);

      final response =
          await repo.chefChat(text, sessionId: _currentConversationId);

      if (!mounted) return;

      // Declared OUTSIDE setState so it is in scope for the notification below.
      final String replyContent = _extractReply(response);
      final String? extractedId = _extractId(response);

      setState(() {
        _isLoading = false;

        if (extractedId != null && extractedId.isNotEmpty) {
          _currentConversationId = extractedId;
        }

        _messages.add(AiMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          role: 'assistant',
          content: replyContent,
          createdAt: DateTime.now(),
        ));
      });

      // Refresh from backend to sync history state
      ref.read(conversationsProvider('chef').notifier).refresh();

      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

      // Notify customer
      CustomerNotificationService.showChatNotification(
        sender: 'Chef Bems 👨‍🍳',
        message: replyContent,
        chatType: 'chef_bems',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _messages.add(AiMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            role: 'assistant',
            content:
                "Sorry, I encountered an error connecting to my kitchen: $e",
            createdAt: DateTime.now(),
          ));
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    }
  }

  void _loadConversation(String id) async {
    setState(() {
      _currentConversationId = id;
      _messages.clear();
      _isLoading = true;
    });
    Navigator.of(context).pop(); // Close drawer

    try {
      final data = await ref.read(conversationDetailProvider(id).future);
      if (mounted) {
        setState(() {
          final conv = AiConversation.fromJson(data);
          _messages = conv.messages;
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading chat: $e')),
        );
      }
    }
  }

  void _startNewChat() {
    setState(() {
      _currentConversationId = null;
      _messages.clear();
    });
    Navigator.of(context).pop(); // Close drawer
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6), // Off-white cream background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black87),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.amber, width: 1.5),
                color: Colors.white,
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/chef_bems.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.restaurant_menu,
                      color: Colors.orange,
                      size: 20),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Chef Bems',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        child: const Text('CULINARY AI',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const Text(
                    'Bems Farms Farm-to-Table Kitchen Guide',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary),
            onPressed: () {
              // Same as new chat, but accessible directly
              setState(() {
                _currentConversationId = null;
                _messages.clear();
              });
            },
            tooltip: 'New Chat',
          ),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.black87),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
              tooltip: 'Saved Chats',
            ),
          ),
        ],
      ),
      endDrawer: _buildDrawer(),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildWelcomeScreen()
                : _buildMessageList(),
          ),
          if (_messages.isNotEmpty && !_isLoading) _buildSuggestedFollowUps(),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    final conversationsAsync = ref.watch(conversationsProvider('chef'));

    return Drawer(
      backgroundColor: const Color(0xFF163E2B), // Dark green theme for sidebar
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber, // Yellow/Amber button
                  foregroundColor: Colors.black87,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _startNewChat,
                icon: const Icon(Icons.add),
                label: const Text('New Recipe Chat',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'SAVED RECIPE THREADS',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: conversationsAsync.when(
                data: (dataList) {
                  if (dataList.isEmpty) {
                    return const Center(
                        child: Text('No saved threads',
                            style: TextStyle(color: Colors.white54)));
                  }
                  return ListView.builder(
                    itemCount: dataList.length,
                    itemBuilder: (context, index) {
                      final title =
                          dataList[index]['title']?.toString() ?? 'Chat ${index + 1}';
                      final id = dataList[index]['_id']?.toString() ??
                          dataList[index]['id']?.toString() ??
                          '';
                      final isSelected = id == _currentConversationId;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        child: ListTile(
                          leading: const Icon(Icons.chat_bubble_outline,
                              color: Colors.white70, size: 20),
                          title: Text(title,
                              style: const TextStyle(color: Colors.white)),
                          selected: isSelected,
                          selectedTileColor: Colors.white.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          onTap: () => _loadConversation(id),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(
                    child: CircularProgressIndicator(color: Colors.amber)),
                error: (e, _) => Center(
                    child: Text('Error loading threads',
                        style: TextStyle(color: Colors.red[300]))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.amber, width: 2.0),
                  color: Colors.white,
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/chef_bems.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.restaurant_menu,
                        color: Colors.orange,
                        size: 30),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome! I am Chef Bems, your Nigerian culinary and pantry specialist from Bems Farms.',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      SizedBox(height: 16),
                      Text('I can assist you with:'),
                      SizedBox(height: 8),
                      _BulletPoint(
                          'Authentic recipes for any Nigerian soup, stew, rice, or swallow'),
                      _BulletPoint(
                          'Smart meal suggestions based on ingredients in your kitchen'),
                      _BulletPoint(
                          'Healthy weekly Nigerian meal planning and nutrition advice'),
                      _BulletPoint(
                          'Cooking substitutions and stone-free grain preparation'),
                      SizedBox(height: 16),
                      Text('What dish would you like to prepare today?',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    final authState = ref.watch(authProvider);
    final userName = authState.value?.name.isNotEmpty == true
        ? authState.value!.name
        : 'User';
    final userInitial = userName.substring(0, 1).toUpperCase();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(left: 56, top: 8),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final msg = _messages[index];
        final isUser = msg.role == 'user';

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.amber, width: 1.5),
                    color: Colors.white,
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/chef_bems.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.restaurant_menu,
                          color: Colors.orange,
                          size: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: isUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                          bottom: 6.0, left: 4.0, right: 4.0),
                      child: Text(
                        isUser ? userName : 'Chef Bems',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.blueGrey.shade400,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isUser
                            ? const Color(0xFF163E2B)
                            : Colors.white,
                        border: isUser
                            ? null
                            : Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(20).copyWith(
                          topRight: isUser
                              ? const Radius.circular(4)
                              : const Radius.circular(20),
                          topLeft: !isUser
                              ? const Radius.circular(4)
                              : const Radius.circular(20),
                        ),
                      ),
                      child: Text(
                        msg.content,
                        style: TextStyle(
                          color: isUser
                              ? Colors.white
                              : const Color(0xFF2C3E35),
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 12),
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.amber,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    userInitial,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        fontSize: 16),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSuggestedFollowUps() {
    final followUps = [
      'Give me step-by-step cooking instructions',
      'What are the exact portion measurements?',
      'Which side dishes pair best with this?',
      'How long can I store or freeze this meal?'
    ];

    return Container(
      height: 48,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: followUps.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ActionChip(
              backgroundColor: Colors.white,
              side: BorderSide(color: Colors.grey.shade300),
              label:
                  Text(followUps[index], style: const TextStyle(fontSize: 12)),
              onPressed: () {
                _messageController.text = followUps[index];
                _sendMessage();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.camera_alt_outlined, color: Colors.grey),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Visual scan is coming soon!')),
                  );
                },
                tooltip: 'Visual Scan',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText:
                      'Ask Chef Bems how to cook Egusi, Jollof, or scan kitchen items...',
                  hintStyle:
                      TextStyle(color: Colors.grey.shade400, fontSize: 14),
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
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              backgroundColor: Colors.amber.shade100,
              radius: 24,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.amber),
                onPressed: _isLoading ? null : _sendMessage,
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final String text;
  const _BulletPoint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6.0, right: 8.0),
            child: CircleAvatar(radius: 3, backgroundColor: Colors.black54),
          ),
          Expanded(
              child: Text(text, style: const TextStyle(color: Colors.black87))),
        ],
      ),
    );
  }
}