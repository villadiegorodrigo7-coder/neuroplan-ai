import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/agenda_event.dart';
import 'agenda_service.dart';

/// Estado compartido de la Agenda.
///
/// La pantalla de la Agenda y Mi diario (que programa recordatorios) usan esta
/// misma lista, para que ninguna guarde una copia vieja encima de la otra.
class AgendaStore extends ChangeNotifier {
  AgendaStore._();
  static final AgendaStore instance = AgendaStore._();

  final List<AgendaEvent> _eventos = [];
  String? _uidCargado;
  Future<void>? _carga;
  bool _listo = false;
  Timer? _debounce;

  bool get listo => _listo;

  /// Los eventos, del más próximo al más lejano.
  List<AgendaEvent> get eventos {
    final copia = List<AgendaEvent>.of(_eventos);
    copia.sort((a, b) => a.date.compareTo(b.date));
    return copia;
  }

  String? get _uid => Supabase.instance.client.auth.currentUser?.id;

  Future<void> cargar() {
    final actual = _uid;
    if (_carga == null || actual != _uidCargado) {
      _debounce?.cancel();
      _debounce = null;
      _uidCargado = actual;
      _eventos.clear();
      _listo = false;
      _carga = _cargarInterno();
      notifyListeners();
    }
    return _carga!;
  }

  Future<void> _cargarInterno() async {
    try {
      final lista = await AgendaService.cargar();
      _eventos
        ..clear()
        ..addAll(lista);
    } catch (e) {
      debugPrint('AgendaStore: error al cargar: $e');
    }
    _listo = true;
    notifyListeners();
  }

  AgendaEvent? porId(String id) {
    for (final e in _eventos) {
      if (e.id == id) return e;
    }
    return null;
  }

  void agregar(AgendaEvent evento) {
    _eventos.add(evento);
    _cambio();
  }

  void eliminar(String id) {
    _eventos.removeWhere((e) => e.id == id);
    _cambio();
  }

  void alternarAviso(String id) {
    final e = porId(id);
    if (e == null) return;
    e.aviso = !e.aviso;
    _cambio();
  }

  void _cambio() {
    notifyListeners();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), guardarYa);
  }

  Future<void> guardarYa() async {
    _debounce?.cancel();
    _debounce = null;
    try {
      await AgendaService.guardar(List<AgendaEvent>.of(_eventos));
    } catch (_) {
      // Queda guardado en el dispositivo; se reintenta más tarde.
    }
  }
}
