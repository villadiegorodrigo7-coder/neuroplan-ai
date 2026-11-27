import 'package:flutter_test/flutter_test.dart';
import 'package:neuroplan_ai/services/historial_rueda_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'conserva el punto de partida y registra cambios y notas por separado',
    () async {
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

      await HistorialRuedaService.registrarValoraciones(
        anteriores: {'Familia': 2},
        nuevos: {'Familia': 4},
        cicloId: 'ciclo-2',
      );
      await HistorialRuedaService.registrarValoraciones(
        anteriores: {'Familia': 4},
        nuevos: {'Familia': 4},
        cicloId: 'ciclo-2',
      );
      await HistorialRuedaService.registrarAvance(
        pilar: 'Familia',
        nota: 'Reservé tiempo para compartir.',
        cicloId: 'ciclo-2',
      );

      final historial = await HistorialRuedaService.cargar();
      expect(historial, hasLength(3));
      expect(historial.singleWhere((r) => r.tipo == 'inicio').valor, 2);
      final cambio = historial.singleWhere((r) => r.tipo == 'valoracion');
      expect(cambio.valor, 4);
      expect(cambio.cicloId, 'ciclo-2');
      final nota = historial.singleWhere((r) => r.tipo == 'avance');
      expect(nota.valor, isNull);
      expect(nota.nota, 'Reservé tiempo para compartir.');
    },
  );
}
