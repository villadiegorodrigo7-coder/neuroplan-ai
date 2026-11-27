import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuroplan_ai/models/entrada_diario.dart';
import 'package:neuroplan_ai/models/productividad_data.dart';
import 'package:neuroplan_ai/models/task.dart';
import 'package:neuroplan_ai/screens/concierto_final_screen.dart';
import 'package:neuroplan_ai/services/concierto_final_service.dart';

void main() {
  testWidgets('La Rueda compara las valoraciones inicial y actual sin cerrar el ciclo',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final inicial = <String, int>{'Salud': 7, 'Familia': 4};
    final ciclo = CicloNeuroplan(
      id: 'diagnostico', fechaInicio: '2026-11-01', duracionDias: 30);
    final snapshot = ConciertoFinalSnapshot(
      ciclo: ciclo, esVistaPrevia: true,
      fechaHasta: '2026-11-20',
      valoresRuedaInicial: inicial,
      valoresRuedaActual: const {'Salud': 6, 'Familia': 4},
      ruedaInicialHistorica: true,
      diarios: [], tareas: [], agenda: [], habitos: [],
      evaluaciones: [], conversaciones: [], historialActividades: [],
      historialActividadesDisponible: false,
      historialActividadesConsultado: false,
    );
    inicial['Salud'] = 1;
    expect(snapshot.valoresRuedaInicial['Salud'], 7);
    expect(() => snapshot.valoresRuedaInicial['Salud'] = 9, throwsUnsupportedError);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: ConciertoFinalScreen(snapshot: snapshot),
    ));
    final tarjeta = find.byKey(const ValueKey('concierto-rueda-inicial'));
    await tester.scrollUntilVisible(tarjeta, 210,
      scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(tarjeta);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('concierto-radar-inicial')), findsOneWidget);
    expect(find.byKey(const ValueKey('concierto-radar-actual')), findsOneWidget);
    expect(find.textContaining('1 dimensiones con cambios registrados'),
      findsOneWidget);
    await tester.tap(tarjeta);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('concierto-radar-real')), findsOneWidget);
    expect(find.text('Inicial'), findsWidgets);
    expect(find.text('Actual'), findsWidgets);
    expect(find.text('7/10'), findsOneWidget);
    expect(find.text('6/10'), findsOneWidget);
    expect(find.text('14/10'), findsNothing);
    expect(ciclo.estado, 'activo');
    expect(ciclo.conciertoFinalCompletado, isFalse);
  });

  testWidgets('Sin diagnóstico confirmado no inventa datos de la Rueda',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final snapshot = ConciertoFinalSnapshot(
      ciclo: CicloNeuroplan(id: 'sin-diagnostico',
        fechaInicio: '2026-11-01', duracionDias: 30),
      esVistaPrevia: true, fechaHasta: '2026-11-20',
      diarios: [], tareas: [], agenda: [], habitos: [],
      evaluaciones: [], conversaciones: [], historialActividades: [],
      historialActividadesDisponible: false,
      historialActividadesConsultado: false,
    );
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: ConciertoFinalScreen(snapshot: snapshot),
    ));
    final tarjeta = find.byKey(const ValueKey('concierto-rueda-inicial'));
    await tester.scrollUntilVisible(tarjeta, 180,
      scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('No hay dimensiones confirmadas'), findsOneWidget);
    expect(find.byKey(const ValueKey('concierto-radar-inicial')), findsNothing);
    await tester.tap(tarjeta);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('concierto-radar-real')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('El recorrido mantiene el diseño en un móvil angosto',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ciclo = CicloNeuroplan(
      id: 'movil', fechaInicio: '2026-11-01', duracionDias: 30,
    );
    final snapshot = ConciertoFinalSnapshot(
      ciclo: ciclo, esVistaPrevia: true, fechaHasta: '2026-11-16',
      diarios: [EntradaDiario(
        id: 'dato', fecha: '2026-11-02',
        semaforo: 'bien', energia: 4, estado: 2)],
      tareas: [], agenda: [], evaluaciones: [], conversaciones: [],
      habitos: List.generate(8, (i) => HabitoRegistroSnapshot(
        habitoId: 'habito', nombre: 'Practicar', tipo: 'incorporar',
        fecha: '2026-11-${(i + 1).toString().padLeft(2, '0')}',
        realizado: i.isEven,
      )),
      historialActividades: [], historialActividadesDisponible: false,
      historialActividadesConsultado: false,
    );
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: ConciertoFinalScreen(snapshot: snapshot),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (var i = 0; i < 6; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(ciclo.estado, 'activo');
  });

  testWidgets('El recorrido abre detalles visuales al tocarlos sin editar registros',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ciclo = CicloNeuroplan(
      id: 'visual', fechaInicio: '2026-11-01', duracionDias: 30,
    );
    final diario = EntradaDiario(
      id: 'dia1', fecha: '2026-11-01',
      semaforo: 'bien', energia: 4, estado: 3,
    );
    final tarea = Task(id: 't1', title: 'Revisar apuntes',
      fecha: '2026-11-01', done: true);
    final snapshot = ConciertoFinalSnapshot(
      ciclo: ciclo, diarios: [diario], tareas: [tarea],
      agenda: [const AgendaOcurrenciaSnapshot(
        eventoId: 'ev1', titulo: 'Clase de música',
        fecha: '2026-11-01', marcada: true, cumplida: true)],
      habitos: [const HabitoRegistroSnapshot(
        habitoId: 'h1', nombre: 'Practicar', tipo: 'incorporar',
        fecha: '2026-11-01', realizado: true)],
      evaluaciones: [], conversaciones: [], historialActividades: [],
      historialActividadesDisponible: false,
      historialActividadesConsultado: false,
    );
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: ConciertoFinalScreen(snapshot: snapshot),
    ));

    final anillo = find.byKey(const ValueKey('concierto-anillo-interactivo'));
    await tester.ensureVisible(anillo);
    await tester.pumpAndSettle();
    final rect = tester.getRect(anillo);
    await tester.tapAt(rect.topCenter + const Offset(7, 25));
    await tester.pumpAndSettle();
    expect(find.text('Día 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('concierto-toggle-partitura')),
      findsOneWidget);
    final detalle = find.byKey(const ValueKey('concierto-detalle-dia'));
    await tester.scrollUntilVisible(detalle, 180,
      scrollable: find.byType(Scrollable).first);
    expect(find.descendant(of: detalle, matching: find.text('Día 1 · 2026-11-01')),
      findsOneWidget);
    expect(find.descendant(of: detalle, matching: find.text('Bien')), findsOneWidget);
    expect(diario.energia, 4);

    final ritmo = find.byKey(const ValueKey('concierto-toggle-ritmo'));
    final desplazamiento = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    ).position;
    desplazamiento.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(ritmo, 120,
      scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(ritmo);
    await tester.pumpAndSettle();
    await tester.tap(ritmo);
    await tester.pumpAndSettle();
    expect(find.text('Ocultar'), findsOneWidget);
    expect(find.text('1 registros'), findsNWidgets(2));

    final acciones = find.byKey(const ValueKey('concierto-toggle-acciones'));
    await tester.scrollUntilVisible(acciones, 180,
      scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(acciones);
    await tester.pumpAndSettle();
    await tester.tap(acciones);
    await tester.pumpAndSettle();
    expect(find.text('Revisar apuntes'), findsOneWidget);
    expect(find.text('Clase de música'), findsOneWidget);
    expect(ciclo.estado, 'activo');
    expect(ciclo.conciertoFinalCompletado, isFalse);
  });

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
    expect(find.text('Mi recorrido'), findsOneWidget);
    expect(find.byKey(const ValueKey('concierto-portada-premium')),
      findsOneWidget);
    expect(find.text('Vista previa'), findsOneWidget);
    expect(find.text('Reflexionar con Ágora'), findsNothing);
    expect(find.textContaining('por vivir'), findsOneWidget);
    final desplegar = find.byKey(const ValueKey('concierto-toggle-partitura'));
    await tester.ensureVisible(desplegar);
    await tester.pumpAndSettle();
    await tester.tap(desplegar);
    await tester.pumpAndSettle();
    final dia16 = find.byKey(const ValueKey('concierto-dia-16'));
    await tester.scrollUntilVisible(dia16, 210,
      scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(dia16);
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
    expect(find.text('Cada día tiene su propio color.'), findsOneWidget);
    // El nuevo recorrido abre el último día: seleccionamos el primero.
    final desplegar = find.byKey(const ValueKey('concierto-toggle-partitura'));
    await tester.ensureVisible(desplegar);
    await tester.pumpAndSettle();
    await tester.tap(desplegar);
    await tester.pumpAndSettle();
    final dia1 = find.byKey(const ValueKey('concierto-dia-1'));
    await tester.ensureVisible(dia1);
    await tester.pumpAndSettle();
    await tester.tap(dia1);
    await tester.pump();
    expect(find.text('Día 1 · 2026-11-01'), findsOneWidget);
    expect(find.textContaining('Prioridad:'), findsNothing);
    expect(find.textContaining('Reflexión:'), findsNothing);
    expect(find.text('Energía: 4/5'), findsOneWidget);

    final dia2 = find.byKey(const ValueKey('concierto-dia-2'));
    await tester.ensureVisible(dia2);
    await tester.pumpAndSettle();
    await tester.tap(dia2);
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
