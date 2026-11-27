import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/entrada_diario.dart';
import '../models/objetivo_rueda.dart';
import '../services/herramientas_service.dart';
import '../widgets/radar_diagnostico_painter.dart';

class RuedaObjetivosScreen extends StatefulWidget {
  const RuedaObjetivosScreen({super.key});

  @override
  State<RuedaObjetivosScreen> createState() => _RuedaObjetivosScreenState();
}

class _RuedaObjetivosScreenState extends State<RuedaObjetivosScreen> {
  late Future<HerramientasData> _datos = HerramientasService.cargar();
  bool _guardando = false;

  Future<void> _editar([ObjetivoRueda? objetivo]) async {
    var nombre = objetivo?.nombre ?? '';
    var meta = objetivo?.meta ?? '';
    var fecha =
        DateTime.tryParse(objetivo?.fechaMeta ?? '') ??
        DateTime.now().add(const Duration(days: 30));
    var valor = objetivo?.valor;
    var nota = '';
    final nuevo = await showDialog<ObjetivoRueda>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, actualizar) => AlertDialog(
          title: Text(objetivo == null ? 'Nuevo objetivo' : 'Editar objetivo'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    initialValue: nombre,
                    maxLength: 40,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del objetivo',
                    ),
                    onChanged: (texto) => actualizar(() => nombre = texto),
                  ),
                  TextFormField(
                    initialValue: meta,
                    maxLength: 240,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '¿Qué significa llegar a 10?',
                    ),
                    onChanged: (texto) => actualizar(() => meta = texto),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      'Revisar el ${EntradaDiario.claveFecha(fecha)}',
                    ),
                    onPressed: () async {
                      final elegida = await showDatePicker(
                        context: context,
                        initialDate: fecha,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (elegida != null && context.mounted) {
                        actualizar(() => fecha = elegida);
                      }
                    },
                  ),
                  Text(
                    valor == null ? 'Avance por valorar' : 'Avance: $valor/10',
                  ),
                  Slider(
                    value: (valor ?? 0).toDouble(),
                    min: 0,
                    max: 10,
                    divisions: 10,
                    onChanged: (numero) =>
                        actualizar(() => valor = numero.round()),
                  ),
                  if (valor == null)
                    TextButton(
                      onPressed: () => actualizar(() => valor = 0),
                      child: const Text('Registrar 0/10'),
                    ),
                  TextField(
                    maxLength: 240,
                    decoration: const InputDecoration(
                      labelText: 'Nota del avance',
                    ),
                    onChanged: (texto) => actualizar(() => nota = texto),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed:
                  nombre.trim().isEmpty ||
                      meta.trim().isEmpty ||
                      (valor == null && nota.trim().isNotEmpty)
                  ? null
                  : () {
                      final avances = [...?objetivo?.avances];
                      final medida = valor;
                      if (medida != null &&
                          (medida != objetivo?.valor ||
                              nota.trim().isNotEmpty)) {
                        avances.add(
                          AvanceObjetivo(
                            fecha: DateTime.now(),
                            valor: medida,
                            nota: nota.trim(),
                          ),
                        );
                      }
                      Navigator.pop(
                        dialogContext,
                        ObjetivoRueda(
                          id: objetivo?.id ?? const Uuid().v4(),
                          nombre: nombre.trim(),
                          meta: meta.trim(),
                          fechaMeta: EntradaDiario.claveFecha(fecha),
                          avances: avances,
                        ),
                      );
                    },
              child: const Text('Guardar objetivo'),
            ),
          ],
        ),
      ),
    );
    if (nuevo == null || !mounted) return;
    setState(() => _guardando = true);
    try {
      final datos = await HerramientasService.cargar();
      if (!mounted || !datos.puedeCrearRuedaObjetivos(DateTime.now())) return;
      final indice = datos.objetivosRueda.indexWhere(
        (item) => item.id == nuevo.id,
      );
      if (indice < 0) {
        datos.objetivosRueda.add(nuevo);
      } else {
        datos.objetivosRueda[indice] = nuevo;
      }
      await HerramientasService.guardar(datos);
      if (mounted) setState(() => _datos = Future.value(datos));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar el objetivo.')),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  String _valor(AvanceObjetivo avance) =>
      '${EntradaDiario.claveFecha(avance.fecha.toLocal())} · ${avance.valor}/10'
      '${avance.nota.isEmpty ? '' : ' · ${avance.nota}'}';

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Rueda de Objetivos')),
      body: FutureBuilder<HerramientasData>(
        future: _datos,
        builder: (context, estado) {
          if (estado.hasError) {
            return const Center(child: Text('No se pudo cargar la rueda.'));
          }
          final datos = estado.data;
          if (datos == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!datos.puedeCrearRuedaObjetivos(DateTime.now())) {
            return const Center(
              child: Text('Disponible desde el día 16 del método.'),
            );
          }
          final objetivos = datos.objetivosRueda;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              if (objetivos.isEmpty)
                const Text('Agrega el primer objetivo que quieras trabajar.'),
              if (objetivos.length >= 3)
                SizedBox(
                  height: 280,
                  child: CustomPaint(
                    painter: RadarDiagnosticoPainter(
                      values: objetivos
                          .map((o) => (o.valor ?? 0).toDouble())
                          .toList(),
                      labels: objetivos
                          .map(
                            (o) => o.nombre.length > 17
                                ? '${o.nombre.substring(0, 16)}…'
                                : o.nombre,
                          )
                          .toList(),
                      missingIndices: {
                        for (var i = 0; i < objetivos.length; i++)
                          if (objetivos[i].valor == null) i,
                      },
                      color: colores.primary,
                      textColor: colores.onSurface,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              for (final objetivo in objetivos)
                Card(
                  child: ExpansionTile(
                    title: Text(objetivo.nombre),
                    subtitle: Text(
                      '${objetivo.valor == null ? 'Por valorar' : '${objetivo.valor}/10'} · Revisar el ${objetivo.fechaMeta}',
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(objetivo.meta),
                      for (final avance in objetivo.avances.reversed)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(_valor(avance)),
                        ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _guardando
                              ? null
                              : () => _editar(objetivo),
                          child: const Text('Editar o registrar avance'),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _guardando ? null : () => _editar(),
                icon: const Icon(Icons.add),
                label: const Text('Agregar objetivo'),
              ),
            ],
          );
        },
      ),
    );
  }
}
