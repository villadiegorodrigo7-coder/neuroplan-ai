import '../models/agenda_event.dart';
import 'coleccion_nube.dart';

/// Eventos de la agenda: se guardan en el dispositivo (por cuenta) y se
/// sincronizan con la tabla "eventos_agenda" de Supabase.
/// Los eventos antiguos guardados sin cuenta ('agenda_events') se importan
/// una sola vez a la primera cuenta que entre.
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
      // Se guarda en UTC para que la hora sea la misma en cualquier dispositivo.
      'fecha': e.date.toUtc().toIso8601String(),
    },
    deFila: (f) => AgendaEvent(
      id: f['id'] as String,
      title: f['titulo'] as String,
      date: DateTime.parse(f['fecha'] as String).toLocal(),
    ),
  );

  static Future<List<AgendaEvent>> cargar() => _col.cargar();

  static Future<void> guardar(List<AgendaEvent> eventos) =>
      _col.guardar(eventos);
}
