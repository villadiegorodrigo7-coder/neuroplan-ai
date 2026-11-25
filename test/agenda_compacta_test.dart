import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuroplan_ai/screens/agenda_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('Agenda compacta abre jornadas y conserva el formulario', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
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
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: AgendaScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Vista semanal'), findsOneWidget);
    expect(find.text('Agregar tarea de la matriz'), findsNothing);
    await tester.ensureVisible(find.text('Mañana'));
    await tester.tap(find.text('Mañana'));
    await tester.pumpAndSettle();
    expect(find.text('Agregar tarea de la matriz'), findsOneWidget);
    await tester.tap(find.text('Mañana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vista semanal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mes'));
    await tester.pumpAndSettle();
    expect(find.text('Vista mensual'), findsOneWidget);
    final organizar = find.text('Organizar mi día');
    await tester.scrollUntilVisible(
      organizar,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(organizar);
    await tester.pumpAndSettle();
    await tester.tap(organizar);
    await tester.pumpAndSettle();
    expect(find.text('Nuevo compromiso'), findsOneWidget);
  });
}
