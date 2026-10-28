import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/agenda_event.dart';
import 'agenda_store.dart';

/// Decide qué evento de la Agenda hay que recordar ahora.
///
/// Un evento con aviso se recuerda cuando llega su hora, siempre que la app
/// esté abierta. Ya no se vuelve a recordar después de pulsar "Listo" ni
/// cuando pasaron más de 12 horas. "Aplazar" lo vuelve a mostrar más tarde.
class AgendaAvisos extends ChangeNotifier {
  AgendaAvisos._();
  static final AgendaAvisos instance = AgendaAvisos._();

  static const String _kVistos = 'agenda_avisos_vistos';
  static const Duration _vigencia = Duration(hours: 12);

  final Set<String> _vistos = {};
  final Map<String, DateTime> _aplazados = {};
  bool _cargado = false;

  Future<void> cargar() async {
    if (_cargado) return;
    try {
      final p = await SharedPreferences.getInstance();
      _vistos.addAll(p.getStringList(_kVistos) ?? const []);
    } catch (_) {
      // Sin datos guardados, se empieza en blanco.
    }
    _cargado = true;
    notifyListeners();
  }

  // Incluye la hora del evento: si la persona la cambia, se vuelve a recordar.
  static String _clave(AgendaEvent e) =>
      '${e.id}|${e.date.toUtc().toIso8601String()}';

  /// El evento más antiguo que toca recordar ahora, o null.
  AgendaEvent? proximoVencido() {
    if (!_cargado || !AgendaStore.instance.listo) return null;
    final ahora = DateTime.now();
    for (final e in AgendaStore.instance.eventos) {
      if (!e.aviso) continue;
      if (e.date.isAfter(ahora)) continue; // todavía no llega
      if (ahora.difference(e.date) > _vigencia) continue; // ya pasó hace mucho
      if (_vistos.contains(_clave(e))) continue;
      final hasta = _aplazados[e.id];
      if (hasta != null && ahora.isBefore(hasta)) continue;
      return e;
    }
    return null;
  }

  Future<void> marcarVisto(AgendaEvent e) async {
    _vistos.add(_clave(e));
    _aplazados.remove(e.id);
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      final lista = _vistos.toList();
      final recorte = lista.length > 200 ? lista.sublist(lista.length - 200) : lista;
      await p.setStringList(_kVistos, recorte);
    } catch (_) {
      // No es grave: a lo sumo se recuerda de nuevo.
    }
  }

  void aplazar(AgendaEvent e, int minutos) {
    _aplazados[e.id] = DateTime.now().add(Duration(minutes: minutos));
    notifyListeners();
  }
}
