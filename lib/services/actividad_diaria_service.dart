import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Registro histórico independiente de los elementos editables de Agenda y Hábitos.
/// Los eventos son append-only: borrar el elemento original no borra su rastro.
class ActividadDiariaService {
  static const String _tabla = 'historial_actividades';

  static Future<void> registrar({
    required String origen,
    required String origenId,
    required String titulo,
    required String accion,
    required DateTime fecha,
    String? bloque,
    Map<String, dynamic>? detalles,
  }) async {
    try {
      final db = Supabase.instance.client;
      final uid = db.auth.currentUser?.id;
      if (uid == null) return;
      final dia = DateTime(fecha.year, fecha.month, fecha.day);
      await db.from(_tabla).insert({
        'user_id': uid,
        'origen': origen,
        'origen_id': origenId,
        'titulo': titulo,
        'accion': accion,
        'fecha': '${dia.year.toString().padLeft(4, '0')}-${dia.month.toString().padLeft(2, '0')}-${dia.day.toString().padLeft(2, '0')}',
        'bloque': bloque,
        'detalles': detalles ?? <String, dynamic>{},
      });
    } catch (e) {
      debugPrint('ActividadDiariaService: no se pudo registrar: $e');
    }
  }
}
