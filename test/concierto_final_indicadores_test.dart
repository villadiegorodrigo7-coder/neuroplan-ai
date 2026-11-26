import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuroplan_ai/models/entrada_diario.dart';
import 'package:neuroplan_ai/models/productividad_data.dart';
import 'package:neuroplan_ai/screens/concierto_final_screen.dart';
import 'package:neuroplan_ai/services/concierto_final_service.dart';

void main() {
  testWidgets('Vista previa desde el dia 16 no ofrece cierre ni lee el futuro',
      (tester) async {
    final ciclo = CicloNeuroplan(
      id: 'vista-previa', fechaInicio: '2026-11-01', duracionDias: 30,
    );
    final registro = EntradaDiario(
      id: 'registro', fecha: '2026-11-16',
      semaforo: 'atencion', energia: 3, estado: 4,
    );
    final snapshot = ConciertoFinalSnapshot(
      ciclo: ciclo,
      esVistaPrevia: true,
      fechaHasta: '2026-11-16',
      diarios: [registro], tareas: [], agenda: [], habitos: [],
      evaluaciones: [], conversaciones: [],
      historialActividades: [],
      historialActividadesDisponible: false,
      historialActividadesConsultado: false,
    );
    await tester.binding.setSurfaceSize(const Size(390, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: ConciertoFinalScreen(snapshot: snapshot),
    ));
    expect(find.text('Mi recorrido · Vista previa'), findsOneWidget);
    expect(find.text('Reflexionar con Ágora'), findsNothing);
    expect(find.text('Por vivir'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('concierto-dia-16')));
    await tester.tap(find.byKey(const ValueKey('concierto-dia-16')));
    await tester.pump();
    expect(find.text('Día 16 · 2026-11-16'), findsOneWidget);
    expect(find.text('Energía: 3/5'), findsOneWidget);
    expect(ciclo.estado, 'activo');
    expect(ciclo.conciertoFinalCompletado, false);
  });

  testWidgets('El Concierto Final consulta el día sin alterar los registros',
      (tester) async {
    final primero = EntradaDiario(
      id: 'uno', fecha: '2026-11-01', semaforo: 'bien',
      energia: 4, estado: 5,
    );
    final segundo = EntradaDiario(
      id: 'dos', fecha: '2026-11-02', semaforo: 'riesgo',
      energia: 2,
    );
    final ciclo = CicloNeuroplan(
      id: 'prueba', fechaInicio: '2026-11-01',
      duracionDias: 30,
    );
    final snapshot = ConciertoFinalSnapshot(
      ciclo: ciclo,
      diarios: [primero, segundo],
      tareas: [],
      agenda: [],
      habitos: [],
      evaluaciones: [],
      conversaciones: [],
      historialActividades: [],
      historialActividadesDisponible: false,
      historialActividadesConsultado: false,
    );
    await tester.binding.setSurfaceSize(const Size(390, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: ConciertoFinalScreen(snapshot: snapshot),
    ));
    expect(find.text('Los colores de tu ciclo'), findsOneWidget);
    expect(find.text('Día 1 · 2026-11-01'), findsOneWidget);
    expect(find.textContaining('Prioridad:'), findsNothing);
    expect(find.textContaining('Reflexión:'), findsNothing);
    expect(find.text('Energía: 4/5'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('concierto-dia-2')));
    await tester.tap(find.byKey(const ValueKey('concierto-dia-2')));
    await tester.pump();

    expect(find.text('Día 2 · 2026-11-02'), findsOneWidget);
    expect(find.text('Desafío'), findsWidgets);
    expect(find.textContaining('Prioridad:'), findsNothing);
    expect(find.text('Energía: 2/5'), findsOneWidget);
    expect(primero.energia, 4);
    expect(segundo.semaforo, 'riesgo');
    expect(ciclo.estado, 'activo');
    expect(ciclo.conciertoFinalCompletado, isFalse);
  });
}
