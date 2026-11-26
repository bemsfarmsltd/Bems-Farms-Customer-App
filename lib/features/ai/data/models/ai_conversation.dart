class AiMessage {
  final String id;
  final String role;
  final String content;
  final DateTime? createdAt;

  AiMessage({
    required this.id,
    required this.role,
    required this.content,
    this.createdAt,
  });

  factory AiMessage.fromJson(Map<String, dynamic> json) {
    return AiMessage(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      role: json['role']?.toString() ?? 'user',
      content: json['content']?.toString() ?? '',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'content': content,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}

class AiConversation {
  final String id;
  final String title;
  final String botType;
  final DateTime? createdAt;
  final List<AiMessage> messages;

  AiConversation({
    required this.id,
    required this.title,
    required this.botType,
    this.createdAt,
    this.messages = const [],
  });

  factory AiConversation.fromJson(Map<String, dynamic> json) {
    return AiConversation(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'New Chat',
      botType: json['bot_type']?.toString() ?? 'chef',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      messages: (json['messages'] as List<dynamic>?)
              ?.map((e) => AiMessage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'bot_type': botType,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      'messages': messages.map((e) => e.toJson()).toList(),
    };
  }
}
