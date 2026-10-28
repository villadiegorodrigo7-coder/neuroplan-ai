import 'dart:ui' show Color;

// ---------------------------------------------------------------------
// Semáforo NeuroPlan: los tres estados y sus definiciones, tal como las
// escribe el cuadernillo del método.
// ---------------------------------------------------------------------

const Color kColorBien = Color(0xFF34D399);
const Color kColorAtencion = Color(0xFFFBBF24);
const Color kColorRiesgo = Color(0xFFFB7185);

const List<String> kSemaforos = ['bien', 'atencion', 'riesgo'];
const List<String> kNombresSemaforo = ['Bien', 'Atención', 'Riesgo'];
const List<String> kDefinicionesSemaforo = [
  'Cumpliste tu prioridad del día y te sentiste con energía razonable.',
  'Avanzaste parcialmente o el día se sintió más difícil de lo normal.',
  'El día se desorganizó. No pasa nada: regístralo y sigue.',
];

const List<String> kNivelesEnergia = ['Muy baja', 'Baja', 'Media', 'Alta', 'Muy alta'];
const List<String> kNivelesEstado = ['Muy bajo', 'Bajo', 'Neutral', 'Bueno', 'Muy bueno'];

Color? colorDeSemaforo(String s) {
  switch (s) {
    case 'bien':
      return kColorBien;
    case 'atencion':
      return kColorAtencion;
    case 'riesgo':
      return kColorRiesgo;
  }
  return null;
}

String nombreDeSemaforo(String s) {
  final i = kSemaforos.indexOf(s);
  return i < 0 ? '' : kNombresSemaforo[i];
}

// ---------------------------------------------------------------------
// Notas y entradas del diario
// ---------------------------------------------------------------------

class NotaDiario {
  final String id;
  String texto;
  final DateTime creada;

  /// Si la nota tiene un recordatorio, es el identificador del evento de la
  /// Agenda donde está programado. Vacío = sin recordatorio.
  String agendaId;

  NotaDiario({
    required this.id,
    required this.texto,
    DateTime? creada,
    this.agendaId = '',
  }) : creada = creada ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'texto': texto,
        'creada': creada.toUtc().toIso8601String(),
        'agendaId': agendaId,
      };

  factory NotaDiario.fromJson(Map<String, dynamic> j) => NotaDiario(
        id: (j['id'] ?? '').toString(),
        texto: (j['texto'] ?? '').toString(),
        creada: DateTime.tryParse((j['creada'] ?? '').toString())?.toLocal(),
        agendaId: (j['agendaId'] ?? '').toString(),
      );
}

/// Un día del diario. Hay una por persona y por fecha.
class EntradaDiario {
  /// "persona_fecha". La base de datos exige este formato.
  final String id;

  /// Fecha local de la persona, como "2026-10-24".
  final String fecha;

  String prioridad;

  /// '' (sin marcar), 'bien', 'atencion' o 'riesgo'.
  String semaforo;

  /// 0 = sin marcar; 1 a 5.
  int energia;

  /// 0 = sin marcar; 1 a 5.
  int estado;

  String reflexion;
  List<NotaDiario> notas;

  EntradaDiario({
    required this.id,
    required this.fecha,
    this.prioridad = '',
    this.semaforo = '',
    this.energia = 0,
    this.estado = 0,
    this.reflexion = '',
    List<NotaDiario>? notas,
  }) : notas = notas ?? [];

  static String claveFecha(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String idPara(String uid, String fecha) => '${uid}_$fecha';

  /// Una entrada vacía no se guarda.
  bool get tieneAlgo =>
      prioridad.isNotEmpty ||
      semaforo.isNotEmpty ||
      energia > 0 ||
      estado > 0 ||
      reflexion.isNotEmpty ||
      notas.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'fecha': fecha,
        'prioridad': prioridad,
        'semaforo': semaforo,
        'energia': energia,
        'estado': estado,
        'reflexion': reflexion,
        'notas': notas.map((n) => n.toJson()).toList(),
      };

  factory EntradaDiario.fromJson(Map<String, dynamic> j) => EntradaDiario(
        id: (j['id'] ?? '').toString(),
        fecha: (j['fecha'] ?? '').toString(),
        prioridad: (j['prioridad'] ?? '').toString(),
        semaforo: (j['semaforo'] ?? '').toString(),
        energia: (j['energia'] as num?)?.toInt() ?? 0,
        estado: (j['estado'] as num?)?.toInt() ?? 0,
        reflexion: (j['reflexion'] ?? '').toString(),
        notas: ((j['notas'] as List?) ?? const [])
            .map((n) => NotaDiario.fromJson(Map<String, dynamic>.from(n as Map)))
            .toList(),
      );

  /// Fila para la tabla "diario" de Supabase.
  Map<String, dynamic> aFila(String uid) => {
        'id': id,
        'user_id': uid,
        'fecha': fecha,
        'prioridad': prioridad,
        'semaforo': semaforo.isEmpty ? null : semaforo,
        'energia': energia == 0 ? null : energia,
        'estado': estado == 0 ? null : estado,
        'reflexion': reflexion,
        'notas': notas.map((n) => n.toJson()).toList(),
      };

  factory EntradaDiario.deFila(Map<String, dynamic> f) => EntradaDiario(
        id: f['id'] as String,
        fecha: f['fecha'].toString(),
        prioridad: (f['prioridad'] ?? '').toString(),
        semaforo: (f['semaforo'] ?? '').toString(),
        energia: (f['energia'] as num?)?.toInt() ?? 0,
        estado: (f['estado'] as num?)?.toInt() ?? 0,
        reflexion: (f['reflexion'] ?? '').toString(),
        notas: ((f['notas'] as List?) ?? const [])
            .map((n) => NotaDiario.fromJson(Map<String, dynamic>.from(n as Map)))
            .toList(),
      );
}
