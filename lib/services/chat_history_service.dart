import 'package:uuid/uuid.dart';

import '../models/chat_conversation.dart';
import 'coleccion_nube.dart';

/// Historial de conversaciones con Ágora: se guarda en el dispositivo (por
/// cuenta) y se sincroniza con la tabla "conversaciones" de Supabase. Cada
/// conversación es una fila; sus mensajes viajan juntos en la columna
/// "mensajes" (jsonb).
/// Las conversaciones antiguas guardadas sin cuenta ('chat_conversations')
/// se importan una sola vez a la primera cuenta que entre.
class ChatHistoryService {
  static final ColeccionNube<ChatConversation> _col =
      ColeccionNube<ChatConversation>(
    tabla: 'conversaciones',
    claveLocal: 'chat_cache',
    claveLegacy: 'chat_conversations',
    idDe: (c) => c.id,
    aJson: (c) => c.toJson(),
    deJson: ChatConversation.fromJson,
    aFila: (c, uid) => {
      'id': c.id,
      'user_id': uid,
      'titulo': c.title,
      'creada_en': c.createdAt.toUtc().toIso8601String(),
      'mensajes': c.messages.map((m) => m.toJson()).toList(),
    },
    deFila: (f) => ChatConversation(
      id: f['id'] as String,
      title: f['titulo'] as String,
      createdAt: DateTime.parse(f['creada_en'] as String).toLocal(),
      messages: ((f['mensajes'] as List?) ?? const [])
          .map((m) => ChatMessageData.fromJson(Map<String, dynamic>.from(m as Map)))
          .toList(),
    ),
  );

  static Future<List<ChatConversation>> loadConversations() async {
    final list = await _col.cargar();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  static Future<void> saveConversations(
      List<ChatConversation> conversations) {
    return _col.guardar(conversations);
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
