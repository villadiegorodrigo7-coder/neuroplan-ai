import 'dart:convert';

import '../models/productividad_data.dart';

class ContextoDiagnosticoRueda {
  static const _marca = '[[CONTEXTO_RUEDA]]';
  static const _cierre = '[[DIAGNOSTICO_COMPLETO]]';

  static String get instrucciones =>
      '''
Durante el diagnóstico inicial, actualiza el contexto de la rueda a medida que la persona comparte información. En cada respuesta, si encuentras un detalle relevante nuevo, añade una sola línea técnica con hasta tres citas breves de mensajes de la persona. Puedes recuperar un detalle relevante de mensajes anteriores que aún no figure en el contexto guardado. No copies palabras de Ágora ni completes las citas. Conserva únicamente detalles que expliquen cómo vive ese pilar o qué quiere cambiar. Omite la línea si no hay detalles útiles, si la persona pide que no los guardes o si estás atendiendo una situación urgente.
Usa únicamente estos pilares: ${pilaresRuedaVida.join(', ')}.
Formato exacto, en una sola línea, sin Markdown y después de la respuesta conversacional:
$_marca [{"pilar":"Familia","cita":"quiero pasar más tiempo con mi familia"}]
La cita debe ser un fragmento literal de lo que realmente escribió o dictó la persona, de hasta 220 caracteres. No incluyas puntuaciones ni interpretaciones. Si corresponde indicar que terminó el diagnóstico, deja $_cierre en una línea posterior a la de contexto.
''';

  static ({String mensaje, Map<String, List<String>> notas}) extraer(
    String respuesta,
    Iterable<String> mensajesUsuario,
  ) {
    final lineas = respuesta.split('\n');
    final candidatas = lineas.where(
      (linea) => linea.trimLeft().startsWith(_marca),
    );
    final mensaje = lineas
        .where((linea) => !linea.trimLeft().startsWith(_marca))
        .join('\n')
        .trim();
    final notas = <String, List<String>>{};
    if (candidatas.length != 1) return (mensaje: mensaje, notas: notas);

    final json = candidatas.single.trimLeft().substring(_marca.length).trim();
    if (json.length > 1500) return (mensaje: mensaje, notas: notas);
    Object? datos;
    try {
      datos = jsonDecode(json);
    } on FormatException {
      return (mensaje: mensaje, notas: notas);
    }
    if (datos is! List || datos.length > 3)
      return (mensaje: mensaje, notas: notas);
    final originales = mensajesUsuario.map(_normalizar).toList();
    for (final dato in datos) {
      if (dato is! Map<String, dynamic> || dato.length != 2) continue;
      final pilar = dato['pilar'];
      final cita = dato['cita'];
      if (pilar is! String ||
          !pilaresRuedaVida.contains(pilar) ||
          cita is! String)
        continue;
      final fragmento = _normalizar(cita);
      if (fragmento.length < 8 ||
          fragmento.length > 220 ||
          !originales.any((original) => original.contains(fragmento))) {
        continue;
      }
      final lista = notas.putIfAbsent(pilar, () => []);
      if (!lista.contains(fragmento)) lista.add(fragmento);
    }
    return (mensaje: mensaje, notas: notas);
  }

  static String _normalizar(String texto) =>
      texto.trim().replaceAll(RegExp(r'\s+'), ' ');
}
