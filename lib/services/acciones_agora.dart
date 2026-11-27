import 'dart:convert';

import '../models/productividad_data.dart';
import 'herramientas_service.dart';
import 'historial_rueda_service.dart';
import 'tasks_service.dart';

enum TipoAccionAgora { notaRueda, valorRueda, tarea }

class AccionAgora {
  const AccionAgora._(this.tipo, this.destino, this.texto);

  final TipoAccionAgora tipo;
  final String destino;
  final String texto;

  static const _marca = '[[ACCION_NEUROPLAN]]';

  static String get instrucciones =>
      '''
HERRAMIENTAS DE NEUROPLAN
Si la persona acaba de expresar que quiere guardar una nota, cambiar una valoración o crear una tarea, puedes proponer una acción. Solo utiliza datos que ella haya dado. Pregunta si falta el pilar o el cuadrante. Presenta la acción como propuesta y espera la confirmación que ofrece la app. No afirmes que ya guardaste nada.
Añade como máximo una acción, en la última línea, sin Markdown, después de tu respuesta normal. Formatos exactos:
$_marca {"tipo":"nota_rueda","destino":"Familia","texto":"Reservar una tarde para compartir"}
$_marca {"tipo":"valor_rueda","destino":"Familia","texto":"4"}
$_marca {"tipo":"tarea","destino":"importanteNoUrgente","texto":"Practicar inglés"}
Pilares válidos: ${pilaresRuedaVida.join(', ')}.
Cuadrantes válidos: ${TasksService.cuadrantesSincronizados.keys.join(', ')}.
Una nota registra un objetivo o avance. No cambia una valoración de la rueda.
Para proponer valor_rueda, la persona debe indicar explícitamente qué pilar quiere valorar y un entero del 0 al 10. El valor debe aparecer como texto numérico, sin unidades. No deduzcas un número de una conversación ni de una nota. Solo puedes proponer una valoración si la rueda inicial ya está confirmada.
''';

  static ({String mensaje, AccionAgora? accion}) interpretar(String respuesta) {
    final lineas = respuesta.trimRight().split('\n');
    final candidatas = lineas.where(
      (linea) => linea.trimLeft().startsWith(_marca),
    );
    final mensaje = lineas
        .where((linea) => !linea.trimLeft().startsWith(_marca))
        .join('\n')
        .trim();
    if (candidatas.length != 1 || candidatas.single != lineas.last) {
      return (mensaje: mensaje, accion: null);
    }
    final contenido = candidatas.single
        .trimLeft()
        .substring(_marca.length)
        .trim();
    if (contenido.length > 1500) return (mensaje: mensaje, accion: null);

    Object? json;
    try {
      json = jsonDecode(contenido);
    } on FormatException {
      return (mensaje: mensaje, accion: null);
    }
    if (json is! Map<String, dynamic> || json.length != 3) {
      return (mensaje: mensaje, accion: null);
    }
    final destino = json['destino'];
    final texto = json['texto'];
    if (destino is! String || texto is! String || texto.trim().isEmpty) {
      return (mensaje: mensaje, accion: null);
    }
    final tipo = switch (json['tipo']) {
      'nota_rueda'
          when pilaresRuedaVida.contains(destino) && texto.length <= 500 =>
        TipoAccionAgora.notaRueda,
      'valor_rueda'
          when pilaresRuedaVida.contains(destino) &&
              RegExp(r'^(?:[0-9]|10)$').hasMatch(texto.trim()) =>
        TipoAccionAgora.valorRueda,
      'tarea'
          when TasksService.cuadrantesSincronizados.containsKey(destino) &&
              texto.length <= 160 =>
        TipoAccionAgora.tarea,
      _ => null,
    };
    return (
      mensaje: mensaje,
      accion: tipo == null ? null : AccionAgora._(tipo, destino, texto.trim()),
    );
  }

  String get titulo => switch (tipo) {
    TipoAccionAgora.notaRueda => 'Guardar nota en $destino',
    TipoAccionAgora.valorRueda => 'Actualizar $destino a $texto/10',
    TipoAccionAgora.tarea =>
      'Crear tarea · ${TasksService.cuadrantesSincronizados[destino]}',
  };

  Future<void> guardar({required bool Function() cuentaVigente}) async {
    switch (tipo) {
      case TipoAccionAgora.notaRueda:
        final datos = await HerramientasService.cargar();
        if (!cuentaVigente()) throw StateError('La sesión cambió.');
        await HistorialRuedaService.registrarAvance(
          pilar: destino,
          nota: texto,
          cicloId: HerramientasService.cicloActivo(datos)?.id,
        );
      case TipoAccionAgora.valorRueda:
        final datos = await HerramientasService.cargar();
        final diagnostico = datos.diagnosticoConversacional;
        if (!cuentaVigente() ||
            diagnostico == null ||
            !diagnostico.confirmado) {
          throw StateError('La rueda inicial debe estar confirmada.');
        }
        final anteriores = Map<String, int>.of(diagnostico.valoresConfirmados);
        final nuevos = {...anteriores, destino: int.parse(texto)};
        await HistorialRuedaService.registrarValoraciones(
          anteriores: anteriores,
          nuevos: nuevos,
          cicloId: HerramientasService.cicloActivo(datos)?.id,
        );
        if (!cuentaVigente()) throw StateError('La sesión cambió.');
        diagnostico.valoresConfirmados = nuevos;
        await HerramientasService.guardar(datos);
      case TipoAccionAgora.tarea:
        await TasksService.instance.cargar();
        if (!cuentaVigente()) throw StateError('La sesión cambió.');
        await TasksService.instance.agregar(texto, destino);
    }
  }
}
