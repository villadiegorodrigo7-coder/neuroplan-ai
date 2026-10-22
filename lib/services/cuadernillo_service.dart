import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cuadernillo_data.dart';

/// Guarda y lee el Cuadernillo NEUROPLAN.
///
/// Estrategia "local primero":
///  - Todo guardado se escribe SIEMPRE en shared_preferences (rápido, offline).
///  - Si hay sesión, además se sube a Supabase (tabla `cuadernillos`).
///  - Si la subida falla, queda marcada como pendiente y se reintenta
///    en el siguiente guardar()/cargar().
///  - Conflictos: gana el cambio más reciente (actualizada_en).
///
/// La API pública (guardar, cargar, borrarTodo, tieneDatosGuardados)
/// no cambia, y el JSON de CuadernilloData tampoco.
class CuadernilloService {
  /// Clave original. Se conserva para migrar datos previos a la cuenta.
  static const String _legacyKey = 'cuadernillo_neuroplan_data';
  static const String _tabla = 'cuadernillos';

  static SupabaseClient get _db => Supabase.instance.client;
  static String? get _uid => _db.auth.currentUser?.id;

  static String _dataKey(String? uid) =>
      uid == null ? _legacyKey : '${_legacyKey}_$uid';
  static String _tsKey(String? uid) => '${_dataKey(uid)}_updatedAt';
  static String _pendingKey(String uid) => '${_dataKey(uid)}_pendingSync';

  /// Cola para que las subidas se ejecuten una tras otra, en orden.
  static Future<void> _cola = Future.value();

  // ---------------------------------------------------------------- guardar

  /// Guarda en el dispositivo y, si hay sesión, sincroniza con la nube.
  static Future<void> guardar(CuadernilloData data) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _uid;
    final ahora = DateTime.now().toUtc();

    await prefs.setString(_dataKey(uid), data.toJsonString());
    await prefs.setString(_tsKey(uid), ahora.toIso8601String());

    if (uid == null) return; // sin sesión: solo local

    await prefs.setBool(_pendingKey(uid), true);
    await _encolarSubida(prefs, uid, data.toJson(), ahora);
  }

  static Future<bool> _encolarSubida(SharedPreferences prefs, String uid,
      Map<String, dynamic> json, DateTime ts) {
    final resultado = _cola.then((_) => _subir(prefs, uid, json, ts));
    _cola = resultado.then((_) {});
    return resultado;
  }

  static Future<bool> _subir(SharedPreferences prefs, String uid,
      Map<String, dynamic> json, DateTime ts) async {
    try {
      await _db.from(_tabla).upsert({
        'user_id': uid,
        'datos': json,
        'actualizada_en': ts.toIso8601String(),
      });
      await prefs.setBool(_pendingKey(uid), false);
      return true;
    } catch (_) {
      // Sin red o error temporal: queda pendiente y se reintenta luego.
      return false;
    }
  }

  // ----------------------------------------------------------------- cargar

  /// Carga el cuadernillo. Si no hay nada, devuelve uno vacío.
  static Future<CuadernilloData> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _uid;

    // Sin sesión: comportamiento original (solo local).
    if (uid == null) {
      return _leer(prefs, _legacyKey) ?? CuadernilloData();
    }

    final local = _leer(prefs, _dataKey(uid));
    final localTs = DateTime.tryParse(prefs.getString(_tsKey(uid)) ?? '');
    final pendiente = prefs.getBool(_pendingKey(uid)) ?? false;

    // Leer la nube.
    Map<String, dynamic>? fila;
    try {
      fila = await _db
          .from(_tabla)
          .select('datos, actualizada_en')
          .eq('user_id', uid)
          .maybeSingle();
    } catch (_) {
      // Sin conexión: seguimos con lo local (o con los datos previos a la cuenta).
      return local ?? _leer(prefs, _legacyKey) ?? CuadernilloData();
    }

    // 1) La nube aún no tiene nada de este usuario.
    if (fila == null) {
      final origen = local ?? _leer(prefs, _legacyKey);
      if (origen == null) return CuadernilloData();

      // MIGRACIÓN: datos locales previos a la cuenta -> nube.
      final ahora = DateTime.now().toUtc();
      await prefs.setString(_dataKey(uid), origen.toJsonString());
      await prefs.setString(_tsKey(uid), ahora.toIso8601String());
      final ok = await _encolarSubida(prefs, uid, origen.toJson(), ahora);
      if (ok) await prefs.remove(_legacyKey); // ya está a salvo en la nube
      return origen;
    }

    // 2) Hay datos en la nube.
    final nubeTs = DateTime.tryParse('${fila['actualizada_en']}')?.toUtc();
    final nube = _desdeMapa(fila['datos']);

    final localGana = local != null &&
        (pendiente ||
            (localTs != null && nubeTs != null && localTs.isAfter(nubeTs)));

    if (localGana) {
      await _encolarSubida(
          prefs, uid, local.toJson(), localTs ?? DateTime.now().toUtc());
      return local;
    }

    if (nube != null) {
      await prefs.setString(_dataKey(uid), nube.toJsonString());
      await prefs.setString(
          _tsKey(uid), (nubeTs ?? DateTime.now().toUtc()).toIso8601String());
      await prefs.setBool(_pendingKey(uid), false);
      return nube;
    }

    return local ?? CuadernilloData();
  }

  // ------------------------------------------------------------ utilidades

  static CuadernilloData? _leer(SharedPreferences prefs, String key) {
    final s = prefs.getString(key);
    if (s == null || s.isEmpty) return null;
    try {
      return CuadernilloData.fromJsonString(s);
    } catch (_) {
      return null; // dato corrupto: no rompemos la app
    }
  }

  static CuadernilloData? _desdeMapa(dynamic data) {
    if (data is! Map || data.isEmpty) return null;
    try {
      return CuadernilloData.fromJson(Map<String, dynamic>.from(data));
    } catch (_) {
      return null;
    }
  }

  /// Borra los datos locales y, si hay sesión, también los de la nube.
  static Future<void> borrarTodo() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _uid;
    await prefs.remove(_legacyKey);
    if (uid != null) {
      await prefs.remove(_dataKey(uid));
      await prefs.remove(_tsKey(uid));
      await prefs.remove(_pendingKey(uid));
      try {
        await _db.from(_tabla).delete().eq('user_id', uid);
      } catch (_) {}
    }
  }

  /// ¿Hay datos guardados en este dispositivo para el usuario actual?
  static Future<bool> tieneDatosGuardados() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _uid;
    final s = prefs.getString(_dataKey(uid)) ??
        (uid != null ? prefs.getString(_legacyKey) : null);
    return s != null && s.isNotEmpty;
  }
}
