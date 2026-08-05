import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cuadernillo_data.dart';

/// Servicio encargado de guardar y leer los datos del
/// Cuadernillo NEUROPLAN usando shared_preferences.
class CuadernilloService {
  static const String _storageKey = 'cuadernillo_neuroplan_data';

  /// Guarda el CuadernilloData completo en el dispositivo.
  static Future<void> guardar(CuadernilloData data) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = data.toJsonString();
    await prefs.setString(_storageKey, jsonString);
  }

  /// Carga el CuadernilloData guardado.
  /// Si no existe nada todavía, devuelve un CuadernilloData vacío
  /// (con todos los valores por defecto).
  static Future<CuadernilloData> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);

    if (jsonString == null || jsonString.isEmpty) {
      return CuadernilloData();
    }

    try {
      return CuadernilloData.fromJsonString(jsonString);
    } catch (e) {
      // Si el dato guardado está corrupto o cambió de formato,
      // devolvemos uno nuevo en vez de romper la app.
      return CuadernilloData();
    }
  }

  /// Borra todos los datos del Cuadernillo (por si el usuario
  /// quiere reiniciar el proceso desde cero).
  static Future<void> borrarTodo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  /// Verifica rápidamente si el usuario ya tiene datos guardados
  /// (útil para mostrar "Continuar" vs "Empezar" en la pantalla).
  static Future<bool> tieneDatosGuardados() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    return jsonString != null && jsonString.isNotEmpty;
  }
}
