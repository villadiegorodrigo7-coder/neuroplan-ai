import '../models/agenda_event.dart';
import 'coleccion_nube.dart';

/// Eventos de agenda con hora de inicio, cierre y patrón de repetición.
class AgendaService {
  static final ColeccionNube<AgendaEvent> _col = ColeccionNube<AgendaEvent>(
    tabla: 'eventos_agenda',
    claveLocal: 'agenda_cache',
    claveLegacy: 'agenda_events',
    idDe: (e) => e.id,
    aJson: (e) => e.toJson(),
    deJson: AgendaEvent.fromJson,
    aFila: (e, uid) => {
      'id': e.id,
      'user_id': uid,
      'titulo': e.title,
      'fecha': e.date.toUtc().toIso8601String(),
      'fecha_fin': e.endDate.toUtc().toIso8601String(),
      'frecuencia': e.frecuencia,
      'dias_semana': e.diasSemana,
      'aviso': e.aviso,
    },
    deFila: (f) {
      final inicio = DateTime.parse(f['fecha'] as String).toLocal();
      return AgendaEvent(
        id: f['id'] as String,
        title: f['titulo'] as String,
        date: inicio,
        endDate: f['fecha_fin'] == null
            ? inicio.add(const Duration(hours: 1))
            : DateTime.parse(f['fecha_fin'] as String).toLocal(),
        frecuencia: f['frecuencia'] as String? ?? 'unica',
        diasSemana: (f['dias_semana'] as List<dynamic>?)
                ?.map((e) => e as int)
                .toList() ??
            <int>[],
        aviso: (f['aviso'] as bool?) ?? false,
      );
    },
  );

  static Future<List<AgendaEvent>> cargar() => _col.cargar();
  static Future<void> guardar(List<AgendaEvent> eventos) =>
      _col.guardar(eventos);
}
