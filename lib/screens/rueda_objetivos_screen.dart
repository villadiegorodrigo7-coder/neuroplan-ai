import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/entrada_diario.dart';
import '../models/objetivo_rueda.dart';
import '../services/herramientas_service.dart';
import '../widgets/estilo_rueda.dart';
import '../widgets/radar_diagnostico_painter.dart';

class RuedaObjetivosScreen extends StatefulWidget {
  const RuedaObjetivosScreen({super.key});

  @override
  State<RuedaObjetivosScreen> createState() => _RuedaObjetivosScreenState();
}

class _RuedaObjetivosScreenState extends State<RuedaObjetivosScreen> {
  late Future<HerramientasData> _datos = HerramientasService.cargar();
  bool _guardando = false;

  Future<void> _editar({ObjetivoRueda? objetivo, required Color color}) async {
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
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: color,
                      thumbColor: color,
                      inactiveTrackColor: color.withValues(alpha: .20),
                    ),
                    child: Slider(
                      value: (valor ?? 0).toDouble(),
                      min: 0,
                      max: 10,
                      divisions: 10,
                      onChanged: (numero) =>
                          actualizar(() => valor = numero.round()),
                    ),
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

  Widget _radar(List<ObjetivoRueda> objetivos, List<Color> colores) {
    final valorados = objetivos
        .where((objetivo) => objetivo.valor != null)
        .length;
    return Container(
      width: double.infinity,
      decoration: decoracionRadarRueda(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
      child: objetivos.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 26),
              child: Column(
                children: [
                  Icon(
                    Icons.track_changes_rounded,
                    color: Color(0xFFC0A7FF),
                    size: 40,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Agrega el primer objetivo que quieras trabajar.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Semantics(
                  image: true,
                  label:
                      'Radar de objetivos. $valorados de ${objetivos.length} con avance registrado.',
                  child: SizedBox(
                    height: 280,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: RadarDiagnosticoPainter(
                        values: objetivos
                            .map((o) => (o.valor ?? 0).toDouble())
                            .toList(),
                        labels: objetivos.map((o) => o.nombre).toList(),
                        axisColors: colores,
                        fontFamily: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.fontFamily,
                        missingIndices: {
                          for (var i = 0; i < objetivos.length; i++)
                            if (objetivos[i].valor == null) i,
                        },
                        color: const Color(0xFF9B75FF),
                        textColor: Colors.white,
                      ),
                    ),
                  ),
                ),
                Text(
                  '$valorados de ${objetivos.length} con avance registrado',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
    );
  }

  Widget _filaObjetivo(ObjetivoRueda objetivo, Color color) {
    final valor = objetivo.valor;
    final tema = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: tema.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: .25)),
      ),
      child: ExpansionTile(
        key: ValueKey(objetivo.id),
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: Icon(Icons.circle, size: 11, color: color),
        title: Text(
          objetivo.nombre,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5, bottom: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(objetivo.meta, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: ExcludeSemantics(
                      child: LinearProgressIndicator(
                        value: (valor ?? 0) / 10,
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(4),
                        color: color,
                        backgroundColor: color.withValues(alpha: .18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    label: valor == null
                        ? 'Avance por valorar'
                        : 'Avance: $valor de 10',
                    excludeSemantics: true,
                    child: Text(
                      valor == null ? '—' : '$valor/10',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Revisar el ${objetivo.fechaMeta}',
            style: tema.textTheme.bodySmall,
          ),
          if (objetivo.avances.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Por valorar'),
            ),
          for (final avance in objetivo.avances.reversed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_valor(avance)),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _guardando
                  ? null
                  : () => _editar(objetivo: objetivo, color: color),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Editar o registrar avance'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          final colores = List.generate(
            objetivos.length,
            (indice) => coloresRueda[indice % coloresRueda.length],
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _radar(objetivos, colores),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: _guardando
                              ? null
                              : () => _editar(
                                  color:
                                      coloresRueda[objetivos.length %
                                          coloresRueda.length],
                                ),
                          icon: const Icon(Icons.add),
                          label: const Text('Agregar objetivo'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (var i = 0; i < objetivos.length; i++)
                        _filaObjetivo(objetivos[i], colores[i]),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
