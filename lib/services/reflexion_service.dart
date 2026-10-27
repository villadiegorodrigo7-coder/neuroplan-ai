import 'package:flutter/foundation.dart';

/// Puente entre Mi diario y el chat: "Reflexionar con Ágora".
///
/// Quien pulsa el botón pide una reflexión para una fecha. La navegación
/// principal cambia a la pestaña del chat y el chat abre la conversación.
class ReflexionService {
  ReflexionService._();
  static final ReflexionService instance = ReflexionService._();

  /// Sube cada vez que alguien pide una reflexión.
  final ValueNotifier<int> senal = ValueNotifier<int>(0);

  String? _fechaPendiente;

  void solicitar(String fecha) {
    _fechaPendiente = fecha;
    senal.value++;
  }

  /// Devuelve la fecha pedida (una sola vez) y la borra.
  String? consumir() {
    final f = _fechaPendiente;
    _fechaPendiente = null;
    return f;
  }
}
