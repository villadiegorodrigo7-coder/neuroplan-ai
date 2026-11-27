import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuroplan_ai/models/chat_conversation.dart';
import 'package:neuroplan_ai/screens/chat_screen.dart';
import 'package:neuroplan_ai/services/chat_history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('Oculta seguimientos automáticos sin borrar conversaciones', (
    tester,
  ) async {
    ChatConversation conversacion(
      String id,
      String titulo,
      String role,
      String contenido,
    ) => ChatConversation(
      id: id,
      title: titulo,
      createdAt: DateTime(2026, 11, 20),
      messages: [ChatMessageData(role: role, content: contenido)],
    );

    const revision = 'Revisión semanal · semana 2';
    const habitos = 'Seguimiento de hábitos · 2026-11-20';
    final guardadas = [
      conversacion('revision', revision, 'model', 'Revisión automática'),
      conversacion('habitos', habitos, 'model', 'Seguimiento automático'),
      conversacion(
        'personal',
        habitos,
        'user',
        'Quiero organizar mi práctica de inglés.',
      ),
    ];
    SharedPreferences.setMockInitialValues({
      'agora_chat_activo_local': 'revision',
      'chat_conversations': jsonEncode(
        guardadas.map((chat) => chat.toJson()).toList(),
      ),
    });
    await tester.runAsync(
      () => Supabase.initialize(
        url: 'https://example.com',
        anonKey: 'prueba',
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false,
          detectSessionInUri: false,
        ),
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: ChatScreen()));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Revisión automática'), findsNothing);
    expect(
      find.text('Quiero organizar mi práctica de inglés.'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Historial'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text(revision), findsNothing);
    expect(find.text(habitos), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    expect(find.text('Aún no tienes conversaciones.'), findsOneWidget);
    expect(
      (await ChatHistoryService.loadConversations()).map((chat) => chat.id),
      unorderedEquals(['revision', 'habitos']),
    );
  });
}
