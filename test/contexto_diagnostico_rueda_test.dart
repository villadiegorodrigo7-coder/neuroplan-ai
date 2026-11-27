import 'package:flutter_test/flutter_test.dart';
import 'package:neuroplan_ai/models/productividad_data.dart';
import 'package:neuroplan_ai/services/contexto_diagnostico_rueda.dart';

void main() {
  test('Recupera citas de la persona y descarta inferencias y pilares desconocidos', () {
    final resultado = ContextoDiagnosticoRueda.extraer(
      '''
Entiendo que quieres pasar más tiempo con tu familia.
[[CONTEXTO_RUEDA]] [{"pilar":"Familia","cita":"quiero pasar más tiempo con mi familia"},{"pilar":"Trabajo","cita":"estoy buscando otro trabajo"},{"pilar":"Inventado","cita":"quiero pasar más tiempo con mi familia"}]
[[DIAGNOSTICO_COMPLETO]]''',
      [
        'quiero pasar más tiempo con mi familia\nlos domingos',
        'Me gustaría organizar mejor mi semana.',
      ],
    );
    expect(resultado.mensaje, contains('Entiendo'));
    expect(resultado.mensaje, isNot(contains('CONTEXTO_RUEDA')));
    expect(resultado.mensaje, contains('DIAGNOSTICO_COMPLETO'));
    expect(resultado.notas, {
      'Familia': ['quiero pasar más tiempo con mi familia'],
    });
  });

  test(
    'Conserva varias notas por pilar sin duplicarlas ni modificar valores',
    () {
      final rueda = DiagnosticoConversacional(
        valoresPropuestos: {'Familia': 2},
        fundamentos: {'Familia': 'Se conversó sobre el tiempo disponible.'},
      );
      const notas = {
        'Familia': ['Quiero compartir los domingos.'],
      };
      expect(rueda.agregarContexto(notas), isTrue);
      expect(rueda.agregarContexto(notas), isFalse);
      expect(
        rueda.agregarContexto({
          'Familia': ['Quiero recuperar las comidas juntos.'],
        }),
        isTrue,
      );

      final guardada = DiagnosticoConversacional.fromJson(rueda.toJson());
      expect(guardada.contextoPorPilar['Familia'], hasLength(2));
      expect(guardada.valoresPropuestos['Familia'], 2);
      expect(guardada.valoresConfirmados, isEmpty);
      expect(guardada.confirmado, isFalse);
      expect(guardada.fundamentos, rueda.fundamentos);
    },
  );
}
