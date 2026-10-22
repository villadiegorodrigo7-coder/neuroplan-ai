import 'dart:async';
import 'package:flutter/foundation.dart';

/// Agrupa cambios rápidos en una sola acción diferida.
/// Cada llamada a [run] reinicia el temporizador; la acción solo se
/// ejecuta cuando pasan [delay] sin nuevos cambios.
class Debouncer {
  final Duration delay;
  Timer? _timer;
  VoidCallback? _pendiente;

  Debouncer({this.delay = const Duration(milliseconds: 600)});

  /// Programa [accion], cancelando la programada anteriormente.
  void run(VoidCallback accion) {
    _timer?.cancel();
    _pendiente = accion;
    _timer = Timer(delay, _ejecutar);
  }

  void _ejecutar() {
    final accion = _pendiente;
    _pendiente = null;
    _timer = null;
    accion?.call();
  }

  /// Si hay un cambio pendiente, lo ejecuta de inmediato.
  /// Llamar antes de [dispose] para no perder el último cambio.
  void flush() {
    if (_timer?.isActive ?? false) {
      _timer!.cancel();
      _ejecutar();
    }
  }

  /// Cancela cualquier ejecución pendiente (usar en dispose()).
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _pendiente = null;
  }
}
