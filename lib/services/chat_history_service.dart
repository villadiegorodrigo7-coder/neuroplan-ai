import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_conversation.dart';

class ChatHistoryService {
  static const String _storageKey = 'chat_conversations';

  static Future<List<ChatConversation>> loadConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return [];
    final List<dynamic> decoded = jsonDecode(raw);
    final list = decoded.map((e) => ChatConversation.fromJson(e)).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  static Future<void> saveConversations(List<ChatConversation> conversations) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(conversations.map((c) => c.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  static Future<ChatConversation> createConversation() async {
    return ChatConversation(
      id: const Uuid().v4(),
      title: 'Nueva conversación',
      createdAt: DateTime.now(),
    );
  }

  static String buildTitle(String firstMessage) {
    final trimmed = firstMessage.trim();
    if (trimmed.length <= 40) return trimmed;
    return '${trimmed.substring(0, 40)}...';
  }
}
