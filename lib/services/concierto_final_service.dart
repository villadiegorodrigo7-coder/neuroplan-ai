import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/agenda_event.dart';
import '../models/chat_conversation.dart';
import '../models/entrada_diario.dart';
import '../models/productividad_data.dart';
import '../models/task.dart';
import 'agenda_store.dart';
import 'chat_history_service.dart';
import 'diario_store.dart';
import 'herramientas_service.dart';
import 'tasks_service.dart';

/// Fotografía de solo lectura de un ciclo ya completado.
/// No cierra el ciclo, no modifica registros y no genera interpretaciones.
class ConciertoFinalSnapshot {
  final CicloNeuroplan ciclo;
  final List<EntradaDiario> diarios;
  final List<Task> tareas;
  final List<AgendaOcurrenciaSnapshot> agenda;
  final List<HabitoRegistroSnapshot> habitos;
  final List<EvaluacionBloque> evaluaciones;
  final List<ChatConversation> conversaciones;
  final List<Map<String, dynamic>> historialActividades;
  final bool historialActividadesDisponible;
  final bool historialActividadesConsultado;
  final bool conversacionesConFechaIndividual;

  ConciertoFinalSnapshot({
    required this.ciclo,
    required List<EntradaDiario> diarios,
    required List<Task> tareas,
    required List<AgendaOcurrenciaSnapshot> agenda,
    required List<HabitoRegistroSnapshot> habitos,
    required List<EvaluacionBloque> evaluaciones,
    required List<ChatConversation> conversaciones,
    required List<Map<String, dynamic>> historialActividades,
    required this.historialActividadesDisponible,
    required this.historialActividadesConsultado,
    this.conversacionesConFechaIndividual = false,
  })  : diarios = List.unmodifiable(diarios),
        tareas = List.unmodifiable(tareas),
        agenda = List.unmodifiable(agenda),
        habitos = List.unmodifiable(habitos),
        evaluaciones = List.unmodifiable(evaluaciones),
        conversaciones = List.unmodifiable(conversaciones),
        historialActividades = List.unmodifiable(historialActividades);

  int get diasConDiario => diarios.where((e) => e.tieneAlgo).length;
  int get diasConEnergia => diarios.where((e) => e.energia > 0).length;
  int get diasConEstado => diarios.where((e) => e.estado > 0).length;
  int get tareasCompletadas => tareas.where((t) => t.done).length;
  int get tareasPendientesRegistradas => tareas.where((t) => !t.done).length;
  int get compromisosCumplidos => agenda.where((e) => e.cumplida).length;
  int get compromisosMarcadosNoCumplidos =>
      agenda.where((e) => e.marcada && !e.cumplida).length;
  int get compromisosSinMarca => agenda.where((e) => !e.marcada).length;
  int get registrosHabitos => habitos.length;

  /// Síntesis estructurada y prudente que Ágora recibe como contexto.
  /// Los registros originales permanecen intactos; esto no es una evaluación.
  String get contextoParaAgora {
    final salida = StringBuffer()
      ..writeln('CONCIERTO FINAL · RECORRIDO DEL CICLO')
      ..writeln('Período: ${ciclo.fechaInicio} a ${ciclo.fechaFin ?? 'sin fecha final'}.')
      ..writeln('Duración prevista: ${ciclo.duracionDias} días.')
      ..writeln('Estos datos son registros disponibles, no una medida del valor ni del esfuerzo de la persona.')
      ..writeln('Días con diario: $diasConDiario. Registros de energía: $diasConEnergia. Registros de estado emocional: $diasConEstado.')
      ..writeln('Tareas completadas: $tareasCompletadas. Tareas pendientes registradas: $tareasPendientesRegistradas.')
      ..writeln('Ocurrencias de agenda cumplidas: $compromisosCumplidos. Marcadas como no cumplidas: $compromisosMarcadosNoCumplidos. Sin marca: $compromisosSinMarca.')
      ..writeln('Registros de hábitos: $registrosHabitos. Evaluaciones de bloques: ${evaluaciones.length}.')
      ..writeln('Historial de actividad: ${!historialActividadesConsultado ? 'no consultado' : (historialActividadesDisponible ? 'disponible' : 'no disponible')}.');
    if (diarios.isNotEmpty) {
      salida.writeln('REGISTROS DEL DIARIO:');
      for (final e in diarios.where((e) => e.tieneAlgo).take(20)) {
        final partes = <String>[];
        if (e.prioridad.trim().isNotEmpty) partes.add('prioridad: ${e.prioridad}');
        if (e.semaforo.trim().isNotEmpty) partes.add('semáforo: ${e.semaforo}');
        if (e.energia > 0) partes.add('energía: ${e.energia}');
        if (e.estado > 0) partes.add('estado: ${e.estado}');
        if (e.reflexion.trim().isNotEmpty) partes.add('reflexión: ${e.reflexion}');
        if (e.notas.trim().isNotEmpty) partes.add('notas: ${e.notas}');
        if (partes.isNotEmpty) salida.writeln('- ${e.fecha}: ${partes.join('; ')}');
      }
    }
    if (tareas.isNotEmpty) {
      salida.writeln('TAREAS REGISTRADAS:');
      for (final t in tareas.take(40)) {
        salida.writeln('- ${t.fecha}: ${t.done ? 'completada' : 'pendiente registrada'} · ${t.title}');
      }
    }
    if (agenda.isNotEmpty) {
      salida.writeln('AGENDA:');
      for (final a in agenda.take(40)) {
        final estado = !a.marcada ? 'sin marca' : (a.cumplida ? 'cumplida' : 'marcada como no cumplida');
        salida.writeln('- ${a.fecha}: ${a.titulo} · $estado');
      }
    }
    if (habitos.isNotEmpty) {
      salida.writeln('HÁBITOS:');
      for (final h in habitos.take(40)) {
        salida.writeln('- ${h.fecha}: ${h.nombre} (${h.tipo}) · ${h.realizado ? 'registro realizado' : 'registro no realizado'}');
      }
    }
    if (evaluaciones.isNotEmpty) {
      salida.writeln('EVALUACIONES DE BLOQUES:');
      for (final e in evaluaciones.take(20)) {
        final bloque = e.bloque == 'manana' ? 'mañana' : e.bloque;
        final detalles = <String>[];
        if (e.porQueDiaSalioAsi.trim().isNotEmpty) detalles.add('por qué: ${e.porQueDiaSalioAsi}');
        if (e.comoSalieronActividades.trim().isNotEmpty) detalles.add('actividades: ${e.comoSalieronActividades}');
        if (e.satisfaccion > 0) detalles.add('satisfacción declarada: ${e.satisfaccion}/5');
        if (e.porQueSatisfaccion.trim().isNotEmpty) detalles.add('motivo: ${e.porQueSatisfaccion}');
        salida.writeln('- ${e.fecha}, $bloque: ${detalles.join('; ')}');
      }
    }
    if (conversaciones.isNotEmpty) {
      salida.writeln('CONVERSACIONES CREADAS DURANTE EL CICLO (los mensajes no tienen fecha individual; no se puede asegurar que todos se escribieran dentro del período):');
      var incluidos = 0;
      for (final c in conversaciones) {
        for (final m in c.messages.where((m) => m.role == 'user')) {
          if (incluidos >= 16) break;
          final texto = m.content.trim().replaceAll(RegExp(r'\s+'), ' ');
          if (texto.isNotEmpty) {
            salida.writeln('- ${c.title}: ${texto.length > 220 ? '${texto.substring(0, 220)}…' : texto}');
            incluidos++;
          }
        }
        if (incluidos >= 16) break;
      }
    }
    if (historialActividadesDisponible && historialActividades.isNotEmpty) {
      salida.writeln('TRAZA DE ACTIVIDAD:');
      for (final a in historialActividades.take(30)) {
        final fecha = (a['fecha'] ?? '').toString();
        final accion = (a['accion'] ?? '').toString();
        final titulo = (a['titulo'] ?? '').toString();
        salida.writeln('- $fecha: ${accion.isEmpty ? 'actividad' : accion}${titulo.isEmpty ? '' : ' · $titulo'}');
      }
    }
    salida.writeln('CRITERIOS DE LECTURA: un día sin registro significa ausencia de información, no incumplimiento. Una tarea pendiente no define a la persona. Distingue los hechos registrados de cualquier interpretación. No inventes datos ni atribuyas causas. No emitas una nota ni un diagnóstico. Haz una sola pregunta a la vez y deja que la persona corrija cualquier lectura.');
    return salida.toString();
  }
}

/// Una ocurrencia concreta, no el evento recurrente completo.
class AgendaOcurrenciaSnapshot {
  final String eventoId;
  final String titulo;
  final String fecha;
  final bool marcada;
  final bool cumplida;

  const AgendaOcurrenciaSnapshot({
    required this.eventoId,
    required this.titulo,
    required this.fecha,
    required this.marcada,
    required this.cumplida,
  });
}

/// Registro de un hábito en una fecha del ciclo.
class HabitoRegistroSnapshot {
  final String habitoId;
  final String nombre;
  final String tipo;
  final String fecha;
  final bool realizado;

  const HabitoRegistroSnapshot({
    required this.habitoId,
    required this.nombre,
    required this.tipo,
    required this.fecha,
    required this.realizado,
  });
}

/// Prepara la información objetiva del Concierto Final.
/// Esta clase es de solo lectura: la confirmación y el cierre pertenecen
/// a la experiencia posterior, nunca a este servicio.
class ConciertoFinalService {
  ConciertoFinalService._();

  static const String _tablaHistorial = 'historial_actividades';

  static Future<ConciertoFinalSnapshot> preparar({
    required String cicloId,
  }) async {
    final herramientasFuture = HerramientasService.cargar();
    final diariosFuture = DiarioStore.instance.cargar();
    final tareasFuture = TasksService.instance.cargar();
    final agendaFuture = AgendaStore.instance.cargar();
    final conversacionesFuture = ChatHistoryService.loadConversations();

    final herramientas = await herramientasFuture;
    CicloNeuroplan? ciclo;
    for (final candidato in herramientas.ciclos) {
      if (candidato.id == cicloId) {
        ciclo = candidato;
        break;
      }
    }

    if (ciclo == null) {
      throw StateError('No se encontró el ciclo solicitado.');
    }
    if (ciclo.estado != 'activo' || ciclo.conciertoFinalCompletado) {
      throw StateError('Este ciclo no está disponible para un nuevo Concierto Final.');
    }
    if (!ciclo.periodoCompletado(DateTime.now())) {
      throw StateError('El período del ciclo todavía no ha terminado.');
    }

    final inicio = ciclo.inicio;
    final fin = ciclo.fechaFin;
    if (inicio == null || fin == null) {
      throw StateError('El ciclo no tiene un período válido.');
    }

    await Future.wait([
      diariosFuture,
      tareasFuture,
      agendaFuture,
    ]);

    final desde = _clave(inicio);
    final hasta = _clave(fin);

    final diarios = DiarioStore.instance.entradas
        .where((e) => e.fecha.compareTo(desde) >= 0 && e.fecha.compareTo(hasta) <= 0)
        .toList()
      ..sort((a, b) => a.fecha.compareTo(b.fecha));

    final tareas = TasksService.instance.tasks
        .where((t) => t.fecha.isNotEmpty && t.fecha.compareTo(desde) >= 0 && t.fecha.compareTo(hasta) <= 0)
        .toList()
      ..sort((a, b) => a.fecha.compareTo(b.fecha));

    final agenda = _recopilarAgenda(
      AgendaStore.instance.eventos,
      inicio,
      fin,
    );

    final habitos = <HabitoRegistroSnapshot>[];
    for (final habito in herramientas.habitos) {
      for (final registro in habito.registros.entries) {
        if (registro.key.compareTo(desde) < 0 || registro.key.compareTo(hasta) > 0) {
          continue;
        }
        habitos.add(HabitoRegistroSnapshot(
          habitoId: habito.id,
          nombre: habito.nombre,
          tipo: habito.tipo,
          fecha: registro.key,
          realizado: registro.value,
        ));
      }
    }
    habitos.sort((a, b) => a.fecha.compareTo(b.fecha));

    final evaluaciones = herramientas.evaluacionesBloques
        .where((e) => e.fecha.compareTo(desde) >= 0 && e.fecha.compareTo(hasta) <= 0)
        .toList()
      ..sort((a, b) => a.fecha.compareTo(b.fecha));

    final conversaciones = await conversacionesFuture;
    // Los mensajes no tienen marca temporal individual en el modelo actual.
    // Por honestidad, solo se incluyen conversaciones creadas dentro del ciclo;
    // no se afirma que todos sus mensajes pertenezcan a ese período.
    final conversacionesDelCiclo = conversaciones
        .where((c) {
          final fecha = DateTime(c.createdAt.year, c.createdAt.month, c.createdAt.day);
          final primero = DateTime(inicio.year, inicio.month, inicio.day);
          final ultimo = DateTime(fin.year, fin.month, fin.day);
          return !fecha.isBefore(primero) && !fecha.isAfter(ultimo);
        })
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final historial = await _cargarHistorial(desde, hasta);

    return ConciertoFinalSnapshot(
      ciclo: ciclo,
      diarios: diarios,
      tareas: tareas,
      agenda: agenda,
      habitos: habitos,
      evaluaciones: evaluaciones,
      conversaciones: conversacionesDelCiclo,
      historialActividades: historial.registros,
      historialActividadesDisponible: historial.disponible,
      historialActividadesConsultado: historial.consultado,
    );
  }

  static List<AgendaOcurrenciaSnapshot> _recopilarAgenda(
    List<AgendaEvent> eventos,
    DateTime inicio,
    DateTime fin,
  ) {
    final resultado = <AgendaOcurrenciaSnapshot>[];
    for (var dia = DateTime(inicio.year, inicio.month, inicio.day);
        !dia.isAfter(fin);
        dia = dia.add(const Duration(days: 1))) {
      for (final evento in eventos) {
        if (!evento.ocurreEl(dia)) continue;
        final clave = evento.claveOcurrencia(dia);
        final marcada = evento.cumplimientos.containsKey(clave);
        final cumplida = evento.cumplimientos[clave] == true;
        resultado.add(AgendaOcurrenciaSnapshot(
          eventoId: evento.id,
          titulo: evento.title,
          fecha: clave,
          marcada: marcada,
          cumplida: cumplida,
        ));
      }
    }
    resultado.sort((a, b) => a.fecha.compareTo(b.fecha));
    return resultado;
  }

  static Future<_ResultadoHistorial> _cargarHistorial(
    String desde,
    String hasta,
  ) async {
    final db = Supabase.instance.client;
    final uid = db.auth.currentUser?.id;
    if (uid == null) {
      return const _ResultadoHistorial(
        registros: [],
        disponible: false,
        consultado: false,
      );
    }

    try {
      final respuesta = await db
          .from(_tablaHistorial)
          .select()
          .eq('user_id', uid)
          .gte('fecha', desde)
          .lte('fecha', hasta);
      final registros = List<Map<String, dynamic>>.from(respuesta);
      registros.sort((a, b) =>
          (a['fecha'] ?? '').toString().compareTo((b['fecha'] ?? '').toString()));
      return _ResultadoHistorial(
        registros: registros,
        disponible: true,
        consultado: true,
      );
    } catch (error, stackTrace) {
      debugPrint('ConciertoFinalService: no se pudo leer el historial: $error');
      debugPrintStack(stackTrace: stackTrace);
      return const _ResultadoHistorial(
        registros: [],
        disponible: false,
        consultado: true,
      );
    }
  }

  static String _clave(DateTime fecha) =>
      '${fecha.year.toString().padLeft(4, '0')}-'
      '${fecha.month.toString().padLeft(2, '0')}-'
      '${fecha.day.toString().padLeft(2, '0')}';
}

class _ResultadoHistorial {
  final List<Map<String, dynamic>> registros;
  final bool disponible;
  final bool consultado;

  const _ResultadoHistorial({
    required this.registros,
    required this.disponible,
    required this.consultado,
  });
}
