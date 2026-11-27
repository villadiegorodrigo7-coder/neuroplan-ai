import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuroplan_ai/models/productividad_data.dart';
import 'package:neuroplan_ai/models/entrada_diario.dart';
import 'package:neuroplan_ai/screens/rueda_objetivos_screen.dart';
import 'package:neuroplan_ai/services/herramientas_service.dart';
import 'package:neuroplan_ai/widgets/radar_diagnostico_painter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('Guarda un objetivo propio desde el día 16 del primer ciclo', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() async {
      await Supabase.initialize(
        url: 'https://example.com',
        anonKey: 'prueba',
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false,
          detectSessionInUri: false,
        ),
      );
      final hoy = DateTime.now();
      final inicio = DateTime(hoy.year, hoy.month, hoy.day - 15);
      await HerramientasService.guardar(
        HerramientasData(
          ciclos: [
            CicloNeuroplan(
              id: 'primero',
              fechaInicio: EntradaDiario.claveFecha(inicio),
            ),
          ],
        ),
      );
    });
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: RuedaObjetivosScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar objetivo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Inglés');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Completar cuatro conversaciones.',
    );
    await tester.pumpAndSettle();
    final guardar = find.text('Guardar objetivo');
    await tester.ensureVisible(guardar);
    await tester.tap(guardar);
    await tester.pumpAndSettle();
    expect(find.text('Guardar objetivo'), findsNothing);
    expect(find.text('Inglés'), findsOneWidget);
    final radar = find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint && widget.painter is RadarDiagnosticoPainter,
    );
    expect(radar, findsOneWidget);
    final pintor =
        tester.widget<CustomPaint>(radar).painter! as RadarDiagnosticoPainter;
    expect(pintor.labels, ['Inglés']);
    expect(pintor.missingIndices, {0});
    expect(pintor.axisColors, hasLength(1));

    final datos = await HerramientasService.cargar();
    final objetivo = datos.objetivosRueda.single;
    expect(objetivo.nombre, 'Inglés');
    expect(objetivo.meta, 'Completar cuatro conversaciones.');
    expect(objetivo.valor, isNull);
  });
}
