import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/entrada_diario.dart';
import 'diario_store.dart';

/// Recordatorio de Mi diario, dentro de la app.
///
/// Sirve para invitar con calma, a la hora que la persona elija, a marcar su
/// semáforo del día. Solo se muestra mientras la app está abierta. No hay
/// culpa ni rachas: se puede apagar y un día sin registrar no es un error.
/// La configuración queda en este dispositivo.
class RecordatorioDiario extends ChangeNotifier {
  RecordatorioDiario._();
  static final RecordatorioDiario instance = RecordatorioDiario._();

  static const String _kActivo = 'recordatorio_activo';
  static const String _kMinutos = 'recordatorio_minutos';
  static const String _kDescartado = 'recordatorio_descartado';

  bool _cargado = false;
  bool _activo = false;
  int _minutos = 18 * 60 + 30; // 6:30 p. m.
  String _descartado = '';

  bool get activo => _activo;
  TimeOfDay get hora => TimeOfDay(hour: _minutos ~/ 60, minute: _minutos % 60);

  Future<void> cargar() async {
    if (_cargado) return;
    try {
      final p = await SharedPreferences.getInstance();
      _activo = p.getBool(_kActivo) ?? false;
      _minutos = p.getInt(_kMinutos) ?? _minutos;
      _descartado = p.getString(_kDescartado) ?? '';
    } catch (_) {
      // Si no se puede leer, queda apagado.
    }
    _cargado = true;
    notifyListeners();
  }

  Future<void> activar(bool valor) async {
    _activo = valor;
    notifyListeners();
    await _guardar();
  }

  Future<void> cambiarHora(TimeOfDay t) async {
    _minutos = t.hour * 60 + t.minute;
    // Si cambió la hora, el aviso de hoy vuelve a quedar disponible.
    _descartado = '';
    notifyListeners();
    await _guardar();
  }

  /// "Ahora no": no se vuelve a avisar hoy.
  Future<void> descartarHoy() async {
    _descartado = EntradaDiario.claveFecha(DateTime.now());
    notifyListeners();
    await _guardar();
  }

  /// ¿Toca mostrar la invitación ahora mismo?
  bool debeAvisar() {
    if (!_cargado || !_activo) return false;
    final store = DiarioStore.instance;
    if (!store.listo) return false;
    final ahora = DateTime.now();
    if (ahora.hour * 60 + ahora.minute < _minutos) return false;
    final hoy = EntradaDiario.claveFecha(ahora);
    if (_descartado == hoy) return false;
    final entrada = store.de(hoy);
    if (entrada != null && entrada.semaforo.isNotEmpty) return false;
    return true;
  }

  Future<void> _guardar() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kActivo, _activo);
      await p.setInt(_kMinutos, _minutos);
      await p.setString(_kDescartado, _descartado);
    } catch (_) {
      // No es grave: se vuelve a intentar con el próximo cambio.
    }
  }
}
