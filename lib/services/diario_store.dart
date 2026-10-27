import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/entrada_diario.dart';
import 'diario_service.dart';

/// Estado compartido de Mi diario.
///
/// El Perfil, la Etapa 4, el mes y el chat usan esta misma lista. Así ninguna
/// pantalla guarda una copia vieja encima de lo que escribió otra.
class DiarioStore extends ChangeNotifier {
  DiarioStore._();
  static final DiarioStore instance = DiarioStore._();

  final List<EntradaDiario> _entradas = [];
  // Días que alguien ya empezó a mirar pero todavía están vacíos. Se guardan
  // aquí para que todas las pantallas reciban la MISMA entrada del mismo día.
  final Map<String, EntradaDiario> _nuevas = {};

  String? _uidCargado;
  Future<void>? _carga;
  bool _listo = false;
  Timer? _debounce;

  bool get listo => _listo;
  List<EntradaDiario> get entradas => List<EntradaDiario>.unmodifiable(_entradas);

  String? get _uid => Supabase.instance.client.auth.currentUser?.id;

  /// Carga la lista de la cuenta actual (una vez por cuenta). Si cambia la
  /// cuenta, se descarta lo anterior y se vuelve a cargar.
  Future<void> cargar() {
    final actual = _uid;
    if (_carga == null || actual != _uidCargado) {
      _debounce?.cancel();
      _debounce = null;
      _uidCargado = actual;
      _entradas.clear();
      _nuevas.clear();
      _listo = false;
      _carga = _cargarInterno();
      notifyListeners();
    }
    return _carga!;
  }

  Future<void> _cargarInterno() async {
    try {
      final lista = await DiarioService.cargar();
      _entradas
        ..clear()
        ..addAll(lista);
    } catch (e) {
      debugPrint('DiarioStore: error al cargar: $e');
    }
    _listo = true;
    notifyListeners();
  }

  EntradaDiario? de(String fecha) {
    for (final e in _entradas) {
      if (e.fecha == fecha) return e;
    }
    return null;
  }

  /// La entrada de [fecha]; si todavía no existe, una vacía que no se guarda
  /// hasta que alguien escriba algo en ella.
  EntradaDiario obtenerOCrear(String fecha) {
    final existente = de(fecha);
    if (existente != null) return existente;
    return _nuevas.putIfAbsent(
      fecha,
      () => EntradaDiario(id: EntradaDiario.idPara(_uid ?? '', fecha), fecha: fecha),
    );
  }

  /// Avisa que una entrada cambió: actualiza la lista y programa el guardado
  /// (queda en el dispositivo y se sube a la nube en segundo plano).
  void cambio(EntradaDiario e) {
    if (!e.tieneAlgo) {
      _entradas.remove(e);
      _nuevas[e.fecha] = e;
    } else if (!_entradas.contains(e)) {
      _entradas.add(e);
      _nuevas.remove(e.fecha);
    }
    notifyListeners();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), guardarYa);
  }

  Future<void> guardarYa() async {
    _debounce?.cancel();
    _debounce = null;
    try {
      await DiarioService.guardar(List<EntradaDiario>.of(_entradas));
    } catch (_) {
      // Queda guardado en el dispositivo; se reintenta más tarde.
    }
  }
}
