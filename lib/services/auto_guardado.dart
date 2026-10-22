import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../models/cuadernillo_data.dart';
import 'cuadernillo_service.dart';

/// Motivo por el que se está sincronizando/guardando. Permite que cada
/// pantalla decida qué hacer (por ejemplo, confirmar o no un texto que el
/// usuario escribió pero todavía no agregó a una lista).
enum MotivoGuardado {
  /// Pasó el tiempo de espera después de un cambio (guardado automático).
  debounce,

  /// El usuario pulsó "Guardar y salir" o "Finalizar".
  explicito,

  /// La app/pestaña pasó a segundo plano (o se está cerrando el navegador).
  segundoPlano,

  /// La pantalla se está cerrando (dispose). No se debe llamar setState.
  cierre,
}

/// Guardado automático con "debounce" para el Cuadernillo.
///
/// Uso típico dentro de un State:
///
/// ```dart
/// late final AutoGuardado _auto = AutoGuardado(
///   obtenerDatos: () => _data,
///   sincronizar: (motivo) { /* copiar controllers -> modelo */ },
/// );
///
/// // tras cada cambio del usuario:
/// _auto.programar();
///
/// @override
/// void dispose() {
///   _auto.dispose();          // cancela el timer Y guarda lo pendiente
///   controller.dispose();     // después de _auto.dispose()
///   super.dispose();
/// }
/// ```
///
/// Qué garantiza:
///  * Muchos cambios seguidos => una sola escritura (cada [retraso]).
///  * Nunca hay dos escrituras simultáneas; si llegan cambios mientras se
///    guarda, se hace una escritura más al terminar.
///  * Al cerrar la pantalla o pasar la app a segundo plano se guarda lo
///    pendiente de inmediato (así no se pierde el último cambio).
///  * No toca la estructura JSON de [CuadernilloData].
class AutoGuardado extends WidgetsBindingObserver {
  AutoGuardado({
    required this.obtenerDatos,
    this.sincronizar,
    this.retraso = const Duration(milliseconds: 700),
  }) {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Devuelve el modelo en memoria que se debe persistir.
  final CuadernilloData Function() obtenerDatos;

  /// Se llama justo antes de cada escritura para copiar lo que hay en los
  /// TextEditingController al modelo.
  final void Function(MotivoGuardado motivo)? sincronizar;

  /// Tiempo de espera desde el último cambio (500-800 ms recomendado).
  final Duration retraso;

  Timer? _timer;
  Future<void>? _enCurso;
  bool _pendiente = false;
  bool _liberado = false;

  /// Hay cambios sin escribir en disco.
  bool get hayPendientes => _pendiente;

  /// Llamar después de CADA cambio hecho por el usuario.
  void programar() {
    if (_liberado) return;
    _pendiente = true;
    _timer?.cancel();
    _timer = Timer(retraso, () => _ejecutar(MotivoGuardado.debounce));
  }

  /// Guarda ya (sin esperar el debounce) y completa cuando termina.
  /// Úsalo en "Guardar y salir" / "Finalizar".
  Future<void> guardarAhora({
    MotivoGuardado motivo = MotivoGuardado.explicito,
  }) {
    if (_liberado) return Future.value();
    _pendiente = true;
    _timer?.cancel();
    return _ejecutar(motivo);
  }

  Future<void> _ejecutar(MotivoGuardado motivo) {
    _timer?.cancel();
    // Si ya hay una escritura en curso, el bucle de _correr volverá a
    // revisar _pendiente al terminar, así que reutilizamos ese Future.
    return _enCurso ??= _correr(motivo).whenComplete(() => _enCurso = null);
  }

  Future<void> _correr(MotivoGuardado motivo) async {
    while (_pendiente) {
      _pendiente = false;
      try {
        sincronizar?.call(motivo);
        await CuadernilloService.guardar(obtenerDatos());
      } catch (e) {
        // Un fallo de almacenamiento no debe romper la pantalla.
        // Se deja el cambio como pendiente para reintentarlo en el
        // próximo cambio y se sale del bucle para no ciclar.
        debugPrint('AutoGuardado: error al guardar: $e');
        _pendiente = true;
        return;
      }
    }
  }

  /// Guardar al pasar a segundo plano: en web esto cubre cambiar de
  /// pestaña o cerrar el navegador (visibilitychange).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _pendiente) {
      guardarAhora(motivo: MotivoGuardado.segundoPlano);
    }
  }

  /// Cancela el timer, deja de observar el ciclo de vida y, si había
  /// cambios sin escribir, los guarda de inmediato (sin await).
  ///
  /// Llamar ANTES de liberar los TextEditingController.
  void dispose() {
    if (_liberado) return;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);

    if (_pendiente) {
      _pendiente = false;
      try {
        sincronizar?.call(MotivoGuardado.cierre);
        // Escritura "fire and forget": no depende del widget, solo del
        // modelo en memoria, así que es seguro aunque la pantalla muera.
        unawaited(
          CuadernilloService.guardar(obtenerDatos()).catchError((Object e) {
            debugPrint('AutoGuardado: error al guardar al cerrar: $e');
          }),
        );
      } catch (e) {
        debugPrint('AutoGuardado: error al cerrar: $e');
      }
    }
    _liberado = true;
  }
}
