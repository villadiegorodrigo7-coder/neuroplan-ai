import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/cuadernillo_data.dart';
import '../models/entrada_diario.dart';
import '../models/task.dart';
import 'coleccion_nube.dart';
import 'cuadernillo_service.dart';

/// Fuente única de verdad de las tareas.
///
/// La pantalla de Tareas y la Etapa 2 del Cuadernillo usan este servicio.
/// Es necesario porque la pantalla de Tareas vive en un IndexedStack (se
/// queda en memoria): si otra pantalla escribiera directo en
/// SharedPreferences, Tareas no se enteraría y luego lo sobrescribiría.
/// Como es un ChangeNotifier, cualquier cambio refresca la lista al instante.
class TasksService extends ChangeNotifier {
  TasksService._();
  static final TasksService instance = TasksService._();

  static const String origenMatriz = 'eisenhower';

  /// Los 4 cuadrantes de la matriz (en orden), con su etiqueta corta.
  /// La pantalla de Tareas es una réplica de la matriz, así que están
  /// todos, incluido "Elimínalo".
  static const Map<String, String> cuadrantesSincronizados = {
    'urgenteImportante': 'Hazlo ya',
    'importanteNoUrgente': 'Planifícalo',
    'urgenteNoImportante': 'Delégalo',
    'niUrgenteNiImportante': 'Elimínalo',
  };

  static const Uuid _uuid = Uuid();

  /// Persistencia: copia local por cuenta + tabla "tareas" en Supabase.
  /// (Las tareas antiguas guardadas sin cuenta en 'tasks_list' se importan
  /// una sola vez a la primera cuenta que entre.)
  static final ColeccionNube<Task> _col = ColeccionNube<Task>(
    tabla: 'tareas',
    claveLocal: 'tasks_cache',
    claveLegacy: 'tasks_list',
    idDe: (t) => t.id,
    aJson: (t) => t.toJson(),
    deJson: Task.fromJson,
    aFila: (t, uid) => {
      'id': t.id,
      'user_id': uid,
      'titulo': t.title,
      'hecha': t.done,
      'origen': t.origen,
      'cuadrante': t.cuadrante,
      'fecha': t.fecha.isEmpty ? null : t.fecha,
      'bloque': t.bloque.isEmpty ? null : t.bloque,
    },
    deFila: (f) => Task(
      id: f['id'] as String,
      title: f['titulo'] as String,
      done: (f['hecha'] as bool?) ?? false,
      origen: f['origen'] as String?,
      cuadrante: f['cuadrante'] as String?,
      fecha: (f['fecha'] ?? '').toString(),
      bloque: (f['bloque'] ?? '').toString(),
    ),
  );

  final List<Task> _tasks = [];
  Future<void>? _carga;
  String? _uidCargado;
  Future<void> _colaMatriz = Future.value();

  /// Lista actual (solo lectura). Llamar después de [cargar].
  List<Task> get tasks => List.unmodifiable(_tasks);

  /// Carga las tareas de la cuenta actual. Se carga una vez por cuenta:
  /// si cambia el usuario, se descarta lo anterior y se vuelve a cargar,
  /// así una cuenta nunca ve las tareas de otra.
  Future<void> cargar() {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (_carga == null || uid != _uidCargado) {
      _uidCargado = uid;
      _tasks.clear();
      _carga = _cargarInterno();
      _notificar();
    }
    return _carga!;
  }

  Future<void> _cargarInterno() async {
    try {
      final lista = await _col.cargar();
      _tasks
        ..clear()
        ..addAll(lista);
    } catch (e) {
      // Si algo falla se arranca con lista vacía en vez de romper la app.
      debugPrint('TasksService: error al cargar: $e');
    }
    _notificar();
  }

  // ---------------------------------------------------------------
  // Acciones desde la pantalla de Tareas
  // ---------------------------------------------------------------

  /// Agrega una tarea en un cuadrante. Se refleja en la matriz del
  /// Cuadernillo (Etapa 2), porque Tareas es una réplica de esa matriz.
  void agregar(String titulo, String cuadrante) {
    final texto = titulo.trim();
    if (texto.isEmpty || !cuadrantesSincronizados.containsKey(cuadrante)) {
      return;
    }
    _tasks.add(Task(
      id: _uuid.v4(),
      title: texto,
      origen: origenMatriz,
      cuadrante: cuadrante,
    ));
    _notificar();
    unawaited(_guardar());
    unawaited(_modificarMatriz((m) => _listaDe(m, cuadrante).add(texto)));
  }

  /// Asigna un cuadrante a una tarea que no tenía (por ejemplo, las que se
  /// crearon a mano antes de que existiera la clasificación).
  void clasificar(Task task, String cuadrante) {
    if (!cuadrantesSincronizados.containsKey(cuadrante)) return;
    task.origen = origenMatriz;
    task.cuadrante = cuadrante;
    _notificar();
    unawaited(_guardar());
    unawaited(_modificarMatriz((m) => _listaDe(m, cuadrante).add(task.title)));
  }

  /// Lleva una tarea a un bloque del día de hoy ('manana', 'tarde' o 'noche').
  void llevarAHoy(Task task, String bloque) {
    task.fecha = EntradaDiario.claveFecha(DateTime.now());
    task.bloque = bloque;
    _notificar();
    unawaited(_guardar());
  }

  /// Quita la tarea del día (sigue existiendo en su cuadrante).
  void quitarDeHoy(Task task) {
    task.fecha = '';
    task.bloque = '';
    _notificar();
    unawaited(_guardar());
  }

  void alternar(Task task) {
    task.done = !task.done;
    _notificar();
    unawaited(_guardar());
  }

  /// Elimina la tarea. Si venía de la matriz, también la quita de ahí;
  /// si no, la siguiente sincronización la volvería a crear.
  Future<void> eliminar(Task task) async {
    _tasks.removeWhere((t) => t.id == task.id);
    _notificar();
    unawaited(_guardar());
    if (task.origen == origenMatriz && task.cuadrante != null) {
      await _quitarDeMatriz(task);
    }
  }

  Future<void> _quitarDeMatriz(Task task) {
    return _modificarMatriz((m) {
      final lista = _listaDe(m, task.cuadrante!);
      final i = lista.indexWhere((s) => _norm(s) == _norm(task.title));
      if (i >= 0) lista.removeAt(i);
    });
  }

  /// Lee el Cuadernillo, aplica [cambio] a la matriz y lo vuelve a guardar.
  /// Las modificaciones van en cola: dos cambios seguidos (p. ej. agregar
  /// dos tareas rápido) no se pisan entre sí.
  Future<void> _modificarMatriz(void Function(MatrizEisenhower m) cambio) {
    _colaMatriz = _colaMatriz.then((_) async {
      final data = await CuadernilloService.cargar();
      cambio(data.matrizEisenhower);
      await CuadernilloService.guardar(data);
    }).catchError((Object e) {
      debugPrint('TasksService: error al actualizar la matriz: $e');
    });
    return _colaMatriz;
  }

  // ---------------------------------------------------------------
  // Sincronización Matriz de Eisenhower -> Tareas
  // ---------------------------------------------------------------

  /// Hace que las tareas de origen "matriz" coincidan con la matriz:
  ///  * crea las que faltan,
  ///  * quita las pendientes que ya no están en la matriz,
  ///  * conserva las ya completadas (historial) y las creadas a mano.
  /// Es idempotente: llamarla varias veces seguidas no duplica nada.
  Future<void> sincronizarMatriz(MatrizEisenhower matriz) async {
    await cargar();
    var huboCambios = false;

    for (final cuadrante in cuadrantesSincronizados.keys) {
      final deseadas = _listaDe(matriz, cuadrante)
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      // Cuántas tareas de cada título debería haber en este cuadrante.
      final faltan = <String, int>{};
      for (final titulo in deseadas) {
        faltan.update(_norm(titulo), (n) => n + 1, ifAbsent: () => 1);
      }

      // Emparejar las que ya existen; las que sobran quedan como huérfanas.
      final huerfanas = <Task>[];
      for (final t in _tasks
          .where((t) => t.origen == origenMatriz && t.cuadrante == cuadrante)) {
        final clave = _norm(t.title);
        final n = faltan[clave] ?? 0;
        if (n > 0) {
          faltan[clave] = n - 1;
        } else {
          huerfanas.add(t);
        }
      }

      for (final t in huerfanas) {
        if (!t.done) {
          _tasks.removeWhere((x) => x.id == t.id);
          huboCambios = true;
        }
      }

      // Crear las que faltan, respetando el orden de la matriz.
      for (final titulo in deseadas) {
        final clave = _norm(titulo);
        final n = faltan[clave] ?? 0;
        if (n > 0) {
          faltan[clave] = n - 1;
          _tasks.add(Task(
            id: _uuid.v4(),
            title: titulo,
            origen: origenMatriz,
            cuadrante: cuadrante,
          ));
          huboCambios = true;
        }
      }
    }

    if (huboCambios) {
      _notificar();
      await _guardar();
    }
  }

  // ---------------------------------------------------------------
  // Internos
  // ---------------------------------------------------------------

  List<String> _listaDe(MatrizEisenhower m, String cuadrante) {
    switch (cuadrante) {
      case 'urgenteImportante':
        return m.urgenteImportante;
      case 'importanteNoUrgente':
        return m.importanteNoUrgente;
      case 'urgenteNoImportante':
        return m.urgenteNoImportante;
      default:
        return m.niUrgenteNiImportante;
    }
  }

  String _norm(String s) => s.trim().toLowerCase();

  /// Guarda la lista completa: queda en el dispositivo al instante y se
  /// sube a Supabase en segundo plano (solo lo que cambió).
  Future<void> _guardar() => _col.guardar(List<Task>.of(_tasks));

  /// Se avisa en un microtask para no disparar reconstrucciones mientras
  /// el framework está cerrando una pantalla (p. ej. dentro de dispose()).
  void _notificar() => scheduleMicrotask(notifyListeners);
}
