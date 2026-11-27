import 'package:flutter_test/flutter_test.dart';
import 'package:neuroplan_ai/services/acciones_agora.dart';
import 'package:neuroplan_ai/services/historial_rueda_service.dart';
import 'package:neuroplan_ai/services/tasks_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const nota =
      '[[ACCION_NEUROPLAN]] {"tipo":"nota_rueda","destino":"Familia","texto":"Reservé una tarde"}';
  const tarea =
      '[[ACCION_NEUROPLAN]] {"tipo":"tarea","destino":"importanteNoUrgente","texto":"Practicar inglés"}';

  test('Acepta una sola propuesta válida al final del mensaje', () {
    final propuesta = AccionAgora.interpretar(
      'Puedo guardar el avance.\n$nota',
    );
    expect(propuesta.mensaje, 'Puedo guardar el avance.');
    expect(propuesta.accion?.tipo, TipoAccionAgora.notaRueda);
    expect(AccionAgora.interpretar('$nota\n$tarea').accion, isNull);
    expect(AccionAgora.interpretar('$nota\nTexto posterior').accion, isNull);
    expect(
      AccionAgora.interpretar(nota.replaceFirst('Familia', 'Inventado')).accion,
      isNull,
    );
    expect(
      AccionAgora.interpretar(tarea.replaceFirst('importanteNoUrgente', 'otro'))
          .accion,
      isNull,
    );
  });

  test('Escribe en las herramientas solo al ejecutar una propuesta', () async {
    SharedPreferences.setMockInitialValues({});
    final supabase = await Supabase.initialize(
      url: 'https://example.com',
      anonKey: 'prueba',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
    );
    addTearDown(supabase.dispose);

    final guardarNota = AccionAgora.interpretar(nota).accion!;
    final crearTarea = AccionAgora.interpretar(tarea).accion!;
    expect(await HistorialRuedaService.cargar(), isEmpty);
    await expectLater(
      guardarNota.guardar(cuentaVigente: () => false),
      throwsStateError,
    );
    expect(await HistorialRuedaService.cargar(), isEmpty);
    await guardarNota.guardar(cuentaVigente: () => true);
    await crearTarea.guardar(cuentaVigente: () => true);

    final registro = (await HistorialRuedaService.cargar()).single;
    expect(registro.pilar, 'Familia');
    expect(registro.valor, isNull);
    expect(registro.nota, 'Reservé una tarde');
    final guardada = TasksService.instance.tasks.single;
    expect(guardada.title, 'Practicar inglés');
    expect(guardada.cuadrante, 'importanteNoUrgente');
  });
}
