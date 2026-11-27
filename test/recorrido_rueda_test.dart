import 'package:flutter_test/flutter_test.dart';
import 'package:neuroplan_ai/models/objetivo_rueda.dart';
import 'package:neuroplan_ai/models/productividad_data.dart';
import 'package:neuroplan_ai/models/recorrido_rueda.dart';
import 'package:neuroplan_ai/services/concierto_final_service.dart';
import 'package:neuroplan_ai/services/herramientas_service.dart';
import 'package:neuroplan_ai/services/historial_rueda_service.dart';

void main() {
  test(
    'Compara valores del ciclo y excluye avances posteriores o de otro ciclo',
    () {
      RegistroRueda registro(
        String dia,
        String tipo, {
        int? valor,
        String? ciclo,
      }) => RegistroRueda(
        id: '$dia-$tipo-${ciclo ?? ''}',
        pilar: 'Familia',
        fecha: DateTime.parse(dia),
        tipo: tipo,
        valor: valor,
        nota: valor == null ? 'Compartimos una tarde.' : '',
        cicloId: ciclo,
      );

      final historial = [
        registro('2026-10-31', 'inicio', valor: 2),
        registro('2026-11-09', 'valoracion', valor: 4, ciclo: 'segundo'),
        registro('2026-11-10', 'avance', ciclo: 'segundo'),
        registro('2026-11-13', 'avance', ciclo: 'otro'),
        registro('2026-12-01', 'valoracion', valor: 8, ciclo: 'segundo'),
      ];
      final durante = RecorridoPilar.delCiclo(
        historial,
        cicloId: 'segundo',
        desde: '2026-11-01',
        hasta: '2026-11-30',
      ).single;
      expect(durante.inicio?.valor, 2);
      expect(durante.ultimo?.valor, 4);
      expect(durante.cambio, 2);
      expect(durante.notas, hasLength(1));
      final concierto = ConciertoFinalSnapshot(
        ciclo: CicloNeuroplan(id: 'segundo', fechaInicio: '2026-11-01'),
        recorridoRueda: [durante],
        diarios: [],
        tareas: [],
        agenda: [],
        habitos: [],
        evaluaciones: [],
        conversaciones: [],
        historialActividades: [],
        historialActividadesDisponible: false,
        historialActividadesConsultado: false,
      );
      expect(
        concierto.contextoParaAgora,
        contains('Familia: partida 2, última dentro del período 4'),
      );
      expect(concierto.contextoParaAgora, contains('Compartimos una tarde.'));

      final sinValorNuevo = RecorridoPilar.delCiclo(
        historial,
        cicloId: 'segundo',
        desde: '2026-11-01',
        hasta: '2026-11-08',
      ).single;
      expect(sinValorNuevo.ultimo, isNull);
      expect(sinValorNuevo.cambio, isNull);
    },
  );

  test('Rueda de Objetivos y vista previa se habilitan juntas el día 16', () {
    final ciclo = CicloNeuroplan(id: 'primero', fechaInicio: '2026-11-01');
    final datos = HerramientasData(ciclos: [ciclo]);
    final dia15 = DateTime(2026, 11, 15, 23, 59);
    final dia16 = DateTime(2026, 11, 16);

    expect(datos.puedeCrearRuedaObjetivos(dia15), isFalse);
    expect(ciclo.puedeVerVistaPreviaConcierto(dia15), isFalse);
    expect(datos.puedeCrearRuedaObjetivos(dia16), isTrue);
    expect(ciclo.puedeVerVistaPreviaConcierto(dia16), isTrue);
    expect(ciclo.periodoCompletado(dia16), isFalse);
    expect(ciclo.puedeVerVistaPreviaConcierto(DateTime(2026, 11, 30)), isTrue);
    expect(ciclo.puedeVerVistaPreviaConcierto(DateTime(2026, 12, 1)), isFalse);
    expect(ciclo.periodoCompletado(DateTime(2026, 12, 1)), isTrue);
    ciclo
      ..estado = 'cerrado'
      ..conciertoFinalCompletado = true;
    datos.ciclos.add(CicloNeuroplan(id: 'segundo', fechaInicio: '2026-12-01'));
    expect(datos.puedeCrearRuedaObjetivos(DateTime(2026, 12, 1)), isTrue);
  });

  test('Conserva objetivos y avances al serializar', () {
    final datos = HerramientasData();
    datos.objetivosRueda.add(
      ObjetivoRueda(
        id: 'ingles',
        nombre: 'Inglés',
        meta: 'Completar cuatro prácticas de conversación.',
        fechaMeta: '2026-12-31',
        avances: [
          AvanceObjetivo(
            fecha: DateTime(2026, 12, 1),
            valor: 3,
            nota: 'Primera práctica.',
          ),
        ],
      ),
    );
    final recuperado = HerramientasData.fromJson(datos.toJson());
    expect(recuperado.objetivosRueda.single.valor, 3);
    expect(
      recuperado.objetivosRueda.single.avances.single.nota,
      'Primera práctica.',
    );
    expect(HerramientasData.fromJson({}).objetivosRueda, isEmpty);
  });
}
