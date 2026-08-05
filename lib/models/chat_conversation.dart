class ChatMessageData {
  final String role;
  final String content;

  ChatMessageData({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};

  factory ChatMessageData.fromJson(Map<String, dynamic> json) =>
      ChatMessageData(role: json['role'], content: json['content']);
}

class ChatConversation {
  final String id;
  String title;
  final DateTime createdAt;
  List<ChatMessageData> messages;

  ChatConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    List<ChatMessageData>? messages,
  }) : messages = messages ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory ChatConversation.fromJson(Map<String, dynamic> json) =>
      ChatConversation(
        id: json['id'],
        title: json['title'],
        createdAt: DateTime.parse(json['createdAt']),
        messages: (json['messages'] as List)
            .map((m) => ChatMessageData.fromJson(m))
            .toList(),
      );
}
