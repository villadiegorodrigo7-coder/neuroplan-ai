import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuroplan_ai/models/chat_conversation.dart';
import 'package:neuroplan_ai/models/productividad_data.dart';
import 'package:neuroplan_ai/screens/chat_screen.dart';
import 'package:neuroplan_ai/services/herramientas_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Retoma el Concierto Final y confirma el cierre desde Ágora',
      (tester) async {
    final ciclo = CicloNeuroplan(id: 'ciclo-1', fechaInicio: '2025-01-01');
    final conversacion = ChatConversation(
      id: 'concierto-1',
      title: 'Concierto Final',
      createdAt: DateTime(2025, 2, 1),
      messages: [
        ChatMessageData(
            role: 'system', content: 'CONCIERTO_FINAL_CICLO:ciclo-1'),
        // Las versiones anteriores podían guardar esta marca sin ID.
        ChatMessageData(
          role: 'system',
          content: 'CONCIERTO_FINAL_CIERRE_DISPONIBLE:',
        ),
        ChatMessageData(role: 'model', content: 'Reconociste tu constancia.'),
      ],
    );
    SharedPreferences.setMockInitialValues({
      'chat_conversations': jsonEncode([conversacion.toJson()]),
    });

    await tester.runAsync(() async {
      await Supabase.initialize(
        url: 'https://example.com',
        anonKey: 'prueba',
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false,
          detectSessionInUri: false,
        ),
      );
      await HerramientasService.guardar(HerramientasData(ciclos: [ciclo]));
    });

    await tester.binding.setSurfaceSize(const Size(360, 680));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: ChatScreen()));
    await tester.pump(const Duration(milliseconds: 350));

    final cerrar = find.text('Cerrar mi ciclo');
    expect(cerrar, findsOneWidget);
    expect(find.text('Reconociste tu constancia.'), findsOneWidget);

    await tester.tap(cerrar);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Todavía no'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(cerrar, findsOneWidget);

    await tester.tap(cerrar);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Sí, cerrar ciclo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Ciclo cerrado · Disponible en tu historial'),
        findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Reconociste tu constancia.'), findsOneWidget);

    final guardado = await HerramientasService.cargar();
    expect(guardado.ciclos.single.estado, 'cerrado');
    expect(guardado.ciclos.single.conciertoFinalCompletado, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const MaterialApp(home: ChatScreen()));
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      find.text('Ciclo cerrado · Disponible en tu historial'),
      findsOneWidget,
    );
    expect(cerrar, findsNothing);
  });
}
