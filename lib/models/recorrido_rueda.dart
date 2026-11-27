import 'entrada_diario.dart';
import 'productividad_data.dart';
import 'registro_rueda.dart';

class RecorridoPilar {
  RecorridoPilar({
    required this.pilar,
    this.inicio,
    this.ultimo,
    List<RegistroRueda> notas = const [],
  }) : notas = List.unmodifiable(notas);

  final String pilar;
  final RegistroRueda? inicio;
  final RegistroRueda? ultimo;
  final List<RegistroRueda> notas;

  int? get cambio => inicio?.valor == null || ultimo?.valor == null
      ? null
      : ultimo!.valor! - inicio!.valor!;

  static List<RecorridoPilar> delCiclo(
    Iterable<RegistroRueda> registros, {
    required String cicloId,
    required String desde,
    required String hasta,
  }) {
    final porPilar = <String, List<RegistroRueda>>{};
    for (final registro in registros) {
      final fecha = EntradaDiario.claveFecha(registro.fecha.toLocal());
      if (fecha.compareTo(hasta) > 0) continue;
      if (registro.tipo == 'avance' &&
          (fecha.compareTo(desde) < 0 ||
              (registro.cicloId != null && registro.cicloId != cicloId))) {
        continue;
      }
      (porPilar[registro.pilar] ??= []).add(registro);
    }

    final resultado = <RecorridoPilar>[];
    for (final pilar in pilaresRuedaVida) {
      final registros = porPilar[pilar];
      if (registros == null) continue;
      registros.sort((a, b) {
        final fecha = a.fecha.compareTo(b.fecha);
        if (fecha != 0) return fecha;
        if (a.tipo == 'inicio' && b.tipo != 'inicio') return -1;
        if (b.tipo == 'inicio' && a.tipo != 'inicio') return 1;
        return a.id.compareTo(b.id);
      });
      final valores = registros.where((registro) => registro.valor != null);
      final antes = valores.where(
        (registro) =>
            EntradaDiario.claveFecha(registro.fecha.toLocal())
                .compareTo(desde) <
            0,
      );
      final durante = valores.where(
        (registro) =>
            EntradaDiario.claveFecha(registro.fecha.toLocal())
                    .compareTo(desde) >=
                0 &&
            (registro.cicloId == null || registro.cicloId == cicloId),
      );
      final inicio = antes.lastOrNull ?? durante.firstOrNull;
      final ultimo = durante.lastOrNull;
      resultado.add(
        RecorridoPilar(
          pilar: pilar,
          inicio: inicio,
          ultimo: ultimo?.id == inicio?.id ? null : ultimo,
          notas: registros
              .where((registro) => registro.tipo == 'avance')
              .toList(),
        ),
      );
    }
    return resultado;
  }
}
