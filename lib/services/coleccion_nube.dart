import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Colección de elementos (tareas, eventos, conversaciones...) que se guarda
/// SIEMPRE en el dispositivo y, si hay sesión, se sincroniza con una tabla de
/// Supabase. Es la misma idea "local primero" que usa CuadernilloService.
///
/// Cómo funciona:
///  * Cada cuenta tiene su propia copia local (la clave lleva el id de usuario),
///    así que dos cuentas en el mismo dispositivo no se mezclan.
///  * [guardar] recibe la lista completa, detecta qué cambió (comparando con lo
///    último que se guardó) y solo sube lo modificado y borra lo eliminado.
///  * Si no hay internet, los cambios quedan pendientes (se guardan en el
///    dispositivo) y se suben en la siguiente oportunidad.
///  * [cargar] baja lo de la nube y lo mezcla: lo pendiente local gana; para lo
///    demás manda la nube (así se ven los cambios hechos desde otro dispositivo).
///  * La primera vez que una cuenta nueva entra y no tiene datos, se importa lo
///    que existía antes en este dispositivo (la clave "legacy", sin cuenta).
///
/// Todas las operaciones van en una cola: nunca se pisan entre sí.
class ColeccionNube<T> {
  ColeccionNube({
    required this.tabla,
    required this.claveLocal,
    required this.idDe,
    required this.aJson,
    required this.deJson,
    required this.aFila,
    required this.deFila,
    this.claveLegacy,
  });

  /// Tabla de Supabase.
  final String tabla;

  /// Prefijo de la copia local (se le agrega el id de usuario).
  final String claveLocal;

  /// Clave antigua (sin cuenta) de la que se importan datos una sola vez.
  final String? claveLegacy;

  final String Function(T item) idDe;

  /// Formato local (el mismo que ya usaba la app).
  final Map<String, dynamic> Function(T item) aJson;
  final T Function(Map<String, dynamic> json) deJson;

  /// Formato de la tabla en Supabase.
  final Map<String, dynamic> Function(T item, String uid) aFila;
  final T Function(Map<String, dynamic> fila) deFila;

  static SupabaseClient get _db => Supabase.instance.client;
  static String? get _uid => _db.auth.currentUser?.id;

  // ---- claves de almacenamiento local, por usuario
  String _kDatos(String uid) => '${claveLocal}__$uid';
  String _kSucias(String uid) => '${claveLocal}__${uid}__sucias';
  String _kBorradas(String uid) => '${claveLocal}__${uid}__borradas';
  String _kMigrado(String uid) => '${claveLocal}__${uid}__migrado';

  /// Última foto conocida (id -> json) para detectar qué cambió.
  Map<String, String> _foto = {};
  String? _uidFoto;

  // ---- cola de operaciones
  Future<void> _cola = Future.value();

  Future<R> _enCola<R>(Future<R> Function() tarea) {
    final completer = Completer<R>();
    _cola = _cola.then((_) async {
      try {
        completer.complete(await tarea());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  // ===================================================================
  // CARGAR
  // ===================================================================

  Future<List<T>> cargar() => _enCola(_cargarInterno);

  Future<List<T>> _cargarInterno() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _uid;

    // Sin sesión: comportamiento original (solo local).
    if (uid == null) {
      return _leerLista(prefs.getString(claveLegacy ?? claveLocal));
    }

    var local = _leerLista(prefs.getString(_kDatos(uid)));
    final sucias = (prefs.getStringList(_kSucias(uid)) ?? <String>[]).toSet();
    final borradas =
        (prefs.getStringList(_kBorradas(uid)) ?? <String>[]).toSet();

    // 1) Leer la nube (null = sin conexión o error).
    List<Map<String, dynamic>>? remotas;
    try {
      final res = await _db.from(tabla).select();
      remotas = List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('ColeccionNube[$tabla]: no se pudo leer la nube: $e');
    }

    // 2) Importar lo que había antes de tener cuenta (una sola vez).
    var huboImportacion = false;
    final yaMigrado = prefs.getBool(_kMigrado(uid)) ?? false;
    if (!yaMigrado &&
        claveLegacy != null &&
        local.isEmpty &&
        (remotas == null || remotas.isEmpty)) {
      final legado = _leerLista(prefs.getString(claveLegacy!));
      if (legado.isNotEmpty) {
        local = legado;
        sucias.addAll(legado.map(idDe));
        huboImportacion = true;
      }
    }
    if (!yaMigrado && (remotas != null || huboImportacion)) {
      await prefs.setBool(_kMigrado(uid), true);
    }

    // 3) Mezclar.
    List<T> resultado;
    if (remotas == null) {
      resultado = local; // sin conexión: seguimos con lo local
    } else {
      final locales = {for (final t in local) idDe(t): t};
      final deLaNube = <String, T>{};
      for (final fila in remotas) {
        try {
          final t = deFila(fila);
          deLaNube[idDe(t)] = t;
        } catch (e) {
          debugPrint('ColeccionNube[$tabla]: fila ilegible: $e');
        }
      }

      final mezclado = <String, T>{};
      for (final e in deLaNube.entries) {
        if (borradas.contains(e.key)) continue; // se borró aquí, falta subirlo
        final localDirty = sucias.contains(e.key) ? locales[e.key] : null;
        mezclado[e.key] = localDirty ?? e.value;
      }
      for (final e in locales.entries) {
        if (mezclado.containsKey(e.key)) continue;
        // Creado aquí y aún sin subir => se conserva.
        // Si no está pendiente y no está en la nube, se borró desde otro
        // dispositivo => se descarta.
        if (sucias.contains(e.key)) mezclado[e.key] = e.value;
      }
      resultado = mezclado.values.toList();
    }

    // 4) Guardar la copia local, actualizar la foto y subir lo pendiente.
    await prefs.setString(_kDatos(uid), _codificar(resultado));
    await prefs.setStringList(_kSucias(uid), sucias.toList());
    await prefs.setStringList(_kBorradas(uid), borradas.toList());
    _foto = {for (final t in resultado) idDe(t): jsonEncode(aJson(t))};
    _uidFoto = uid;

    final ok = await _empujar(prefs, uid);
    if (ok && huboImportacion && claveLegacy != null) {
      await prefs.remove(claveLegacy!); // ya está a salvo en la nube
    }
    return resultado;
  }

  // ===================================================================
  // GUARDAR
  // ===================================================================

  /// Guarda la lista completa. Devuelve en cuanto queda escrita en el
  /// dispositivo; la subida a la nube sigue en segundo plano.
  Future<void> guardar(List<T> actuales) async {
    await _enCola(() => _guardarLocal(actuales));
    unawaited(_enCola(_subirPendientes));
  }

  Future<void> _guardarLocal(List<T> actuales) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _uid;

    if (uid == null) {
      await prefs.setString(claveLegacy ?? claveLocal, _codificar(actuales));
      return;
    }

    // Si por algún motivo no se había cargado, reconstruye la foto desde
    // la copia local de esta cuenta.
    if (_uidFoto != uid) {
      final previos = _leerLista(prefs.getString(_kDatos(uid)));
      _foto = {for (final t in previos) idDe(t): jsonEncode(aJson(t))};
      _uidFoto = uid;
    }

    final sucias = (prefs.getStringList(_kSucias(uid)) ?? <String>[]).toSet();
    final borradas =
        (prefs.getStringList(_kBorradas(uid)) ?? <String>[]).toSet();

    final nueva = {for (final t in actuales) idDe(t): jsonEncode(aJson(t))};

    for (final e in nueva.entries) {
      if (_foto[e.key] != e.value) {
        sucias.add(e.key);
        borradas.remove(e.key);
      }
    }
    for (final id in _foto.keys) {
      if (!nueva.containsKey(id)) {
        borradas.add(id);
        sucias.remove(id);
      }
    }
    _foto = nueva;

    await prefs.setString(_kDatos(uid), _codificar(actuales));
    await prefs.setStringList(_kSucias(uid), sucias.toList());
    await prefs.setStringList(_kBorradas(uid), borradas.toList());
  }

  Future<void> _subirPendientes() async {
    final uid = _uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await _empujar(prefs, uid);
  }

  /// Reintenta subir lo pendiente (por ejemplo, al volver la conexión).
  Future<void> reintentar() => _enCola(_subirPendientes);

  // ===================================================================
  // SUBIDA A LA NUBE
  // ===================================================================

  /// Sube cambios y borrados pendientes. Devuelve true si no queda nada
  /// pendiente. Debe llamarse dentro de la cola.
  Future<bool> _empujar(SharedPreferences prefs, String uid) async {
    final sucias = prefs.getStringList(_kSucias(uid)) ?? <String>[];
    final borradas = prefs.getStringList(_kBorradas(uid)) ?? <String>[];
    if (sucias.isEmpty && borradas.isEmpty) return true;

    final locales = {
      for (final t in _leerLista(prefs.getString(_kDatos(uid)))) idDe(t): t,
    };
    final filas = <Map<String, dynamic>>[
      for (final id in sucias)
        if (locales[id] != null) aFila(locales[id] as T, uid),
    ];

    try {
      if (borradas.isNotEmpty) {
        await _db.from(tabla).delete().inFilter('id', borradas);
      }
      if (filas.isNotEmpty) {
        await _db.from(tabla).upsert(filas);
      }
      // Como todo va en cola, nada cambió mientras tanto: se limpia todo.
      await prefs.setStringList(_kSucias(uid), <String>[]);
      await prefs.setStringList(_kBorradas(uid), <String>[]);
      return true;
    } catch (e) {
      debugPrint('ColeccionNube[$tabla]: no se pudo subir (queda pendiente): $e');
      return false;
    }
  }

  // ===================================================================
  // UTILIDADES
  // ===================================================================

  String _codificar(List<T> lista) =>
      jsonEncode(lista.map((t) => aJson(t)).toList());

  List<T> _leerLista(String? raw) {
    if (raw == null || raw.isEmpty) return <T>[];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final lista = <T>[];
      for (final e in decoded) {
        try {
          lista.add(deJson(Map<String, dynamic>.from(e as Map)));
        } catch (_) {
          // elemento corrupto: se omite sin romper la app
        }
      }
      return lista;
    } catch (_) {
      return <T>[];
    }
  }
}
