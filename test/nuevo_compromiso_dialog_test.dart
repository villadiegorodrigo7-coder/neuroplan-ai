import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuroplan_ai/models/agenda_event.dart';
import 'package:neuroplan_ai/widgets/nuevo_compromiso_dialog.dart';

void main() {
  testWidgets('Valida y devuelve un compromiso recurrente', (tester) async {
    AgendaEvent? resultado;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  resultado = await showDialog<AgendaEvent>(
                    context: context,
                    builder: (_) => NuevoCompromisoDialog(
                      fechaInicial: DateTime(2026, 11, 25),
                    ),
                  );
                },
                child: const Text('Abrir'),
              ),
            );
          },
        ),
      ),
    );
    final guardar = find.widgetWithText(FilledButton, 'Guardar');
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(guardar).onPressed, isNull);
    await tester.enterText(find.byType(TextField), '  Caminata  ');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(guardar).onPressed, isNotNull);
    await tester.tap(find.text('Una sola vez'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Días seleccionados').last);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(guardar).onPressed, isNull);
    await tester.tap(find.widgetWithText(FilterChip, 'Lun'));
    await tester.pumpAndSettle();
    await tester.tap(guardar);
    await tester.pumpAndSettle();
    expect(resultado?.title, 'Caminata');
    expect(resultado?.frecuencia, 'personalizada');
    expect(resultado?.diasSemana, [1]);
    expect(resultado?.duracion, const Duration(hours: 1));
  });
}
