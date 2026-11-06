import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/entrada_diario.dart';
import '../models/cuadernillo_data.dart';
import '../services/cuadernillo_service.dart';
import '../models/task.dart';
import '../services/diario_store.dart';
import '../services/tasks_service.dart';

/// Mi pulso reúne dos dimensiones complementarias: la experiencia diaria
/// (Mi ritmo) y las intenciones elegidas (Mis intenciones).
class MiPulsoScreen extends StatefulWidget {
  const MiPulsoScreen({super.key});

  @override
  State<MiPulsoScreen> createState() => _MiPulsoScreenState();
}

class _MiPulsoScreenState extends State<MiPulsoScreen> {
  static const Color _sinRegistro = Color(0xFF30384D);
  DateTime _seleccionado = DateTime.now();
  bool _cargando = true;
  bool _ruedaAlFrente = true;
  late DateTime _inicioCiclo;
  CuadernilloData? _cuaderno;

  DateTime get _hoy => DateTime.now();
  DateTime get _inicio => _inicioCiclo;

  List<DateTime> get _dias => List.generate(
        30,
        (i) => _inicio.add(Duration(days: i)),
      );

  String _clave(DateTime d) => EntradaDiario.claveFecha(d);

  @override
  void initState() {
    super.initState();
    DiarioStore.instance.addListener(_actualizar);
    TasksService.instance.addListener(_actualizar);
    _cargar();
  }

  Future<void> _cargar() async {
    await Future.wait([
      DiarioStore.instance.cargar(),
      TasksService.instance.cargar(),
    ]);

    // Mi pulso usa el mismo ciclo de 30 días que la Etapa 4 del cuadernillo.
    final cuadernillo = await CuadernilloService.cargar();
    var fechaInicio = cuadernillo.seguimiento30Dias.fechaInicio;
    if (fechaInicio.isEmpty) {
      final fechas = DiarioStore.instance.entradas.map((e) => e.fecha).toList()
        ..sort();
      fechaInicio = fechas.isNotEmpty
          ? fechas.first
          : EntradaDiario.claveFecha(DateTime.now());
      cuadernillo.seguimiento30Dias.fechaInicio = fechaInicio;
      await CuadernilloService.guardar(cuadernillo);
    }

    final inicio = DateTime.tryParse(fechaInicio) ?? DateTime.now();
    final hoy = DateTime(_hoy.year, _hoy.month, _hoy.day);
    final diferencia = hoy.difference(DateTime(inicio.year, inicio.month, inicio.day)).inDays;
    if (mounted) {
      setState(() {
        _cuaderno = cuadernillo;
        _inicioCiclo = DateTime(inicio.year, inicio.month, inicio.day);
        _seleccionado = _dias[diferencia.clamp(0, 29)];
        _cargando = false;
      });
    }
  }

  void _actualizar() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    DiarioStore.instance.removeListener(_actualizar);
    TasksService.instance.removeListener(_actualizar);
    super.dispose();
  }

  EntradaDiario? _entrada(DateTime d) {
    final key = _clave(d);
    for (final e in DiarioStore.instance.entradas) {
      if (e.fecha == key) return e;
    }
    return null;
  }

  List<Task> _tareas(DateTime d) => TasksService.instance.tasks
      .where((t) => t.fecha == _clave(d))
      .toList();

  static const Color _diaTranscurrido = Color(0xFFFF9800);

  int get _diasTranscurridos {
    final hoy = DateTime(_hoy.year, _hoy.month, _hoy.day);
    final diferencia = hoy.difference(_inicio).inDays;
    return (diferencia + 1).clamp(0, 30);
  }

  // El anillo representa el paso del tiempo, no una calificación del día.
  Color _colorDia(DateTime d) {
    final hoy = DateTime(_hoy.year, _hoy.month, _hoy.day);
    return !d.isAfter(hoy) ? _diaTranscurrido : _sinRegistro;
  }

  String _fechaLarga(DateTime d) {
    const dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
    const meses = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
    final dia = dias[d.weekday - 1];
    return '${dia[0].toUpperCase()}${dia.substring(1)} ${d.day} de ${meses[d.month - 1]}';
  }

  String _energia(int n) => n > 0 && n <= kNivelesEnergia.length
      ? kNivelesEnergia[n - 1]
      : 'Sin registro';

  String _estado(int n) => n > 0 && n <= kNivelesEstado.length
      ? kNivelesEstado[n - 1]
      : 'Sin registro';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Mi pulso')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final resumen = Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 5, child: _panelIndicadores(scheme)),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 6,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: _anillo(scheme),
                      ),
                    ),
                  ],
                );
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    Text(
                      'Tu recorrido · ciclo de 30 días',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
                    ),
                    const SizedBox(height: 14),
                    resumen,
                    const SizedBox(height: 12),
                    _composicionDiagnostica(scheme),
                    const SizedBox(height: 22),
                    _tareasDelDia(scheme),
                  ],
                );
              },
            ),
    );
  }

  Widget _anillo(ColorScheme scheme) {
    return Center(
      child: SizedBox(
        width: 290,
        height: 290,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(290, 290),
              painter: _PulsoPainter(
                colores: _dias.map(_colorDia).toList(),
                seleccionado: _dias.indexWhere((d) => _clave(d) == _clave(_seleccionado)),
                base: _sinRegistro,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('MI PULSO',
                    style: TextStyle(
                      color: scheme.primary,
                      fontSize: 12,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 5),
                Text('$_diasTranscurridos',
                    style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w700)),
                Text('días transcurridos de 30',
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.68))),
              ],
            ),
            for (var i = 0; i < _dias.length; i++)
              _puntoInteractivo(i, scheme),
          ],
        ),
      ),
    );
  }

  Widget _panelIndicadores(ColorScheme scheme) {
    final entrada = _entrada(_seleccionado);
    final colorTexto = Colors.white.withValues(alpha: 0.82);

    Widget opcionSemaforo(String valor, String nombre, String significado, Color color) {
      final activo = entrada?.semaforo == valor;
      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          final registro = DiarioStore.instance.obtenerOCrear(_clave(_seleccionado));
          registro.semaforo = valor;
          DiarioStore.instance.cambio(registro);
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
          decoration: BoxDecoration(
            color: activo ? color.withValues(alpha: 0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: activo ? color : Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombre, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    Text(significado, style: TextStyle(fontSize: 9, height: 1.2, color: colorTexto)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget escala(String titulo, int valor, String descripcion, IconData icono,
        void Function(int) alSeleccionar) {
      return Padding(
        padding: const EdgeInsets.only(top: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icono, size: 14, color: scheme.primary),
              const SizedBox(width: 5),
              Expanded(child: Text(titulo, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 6),
            Row(
              children: List.generate(5, (i) {
                final nivel = i + 1;
                final activo = valor == nivel;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i == 4 ? 0 : 4),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(5),
                      onTap: () => alSeleccionar(activo ? 0 : nivel),
                      child: Container(
                        height: 25,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: valor >= nivel
                              ? scheme.primary.withValues(alpha: 0.85)
                              : Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: activo ? scheme.primary : Colors.white.withValues(alpha: 0.10),
                            width: activo ? 1.5 : 0.7,
                          ),
                        ),
                        child: Text('$nivel', style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: valor >= nivel ? Colors.black87 : colorTexto,
                        )),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 4),
            Text(valor > 0 ? descripcion : 'Toca un cuadro para registrar',
              style: TextStyle(fontSize: 10, color: colorTexto)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('¿De qué color pasó tu día hoy?',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 9),
          opcionSemaforo('bien', 'Bien', 'Satisfacción', kColorBien),
          const SizedBox(height: 5),
          opcionSemaforo('atencion', 'Atención', 'Pausa y observa', kColorAtencion),
          const SizedBox(height: 5),
          opcionSemaforo('riesgo', 'Desafío', 'Una oportunidad', kColorDesafio),
          escala('Estado emocional', entrada?.estado ?? 0,
            _estado(entrada?.estado ?? 0), Icons.mood_outlined, (nivel) {
              final registro = DiarioStore.instance.obtenerOCrear(_clave(_seleccionado));
              registro.estado = nivel;
              DiarioStore.instance.cambio(registro);
            }),
          escala('Energía', entrada?.energia ?? 0,
            _energia(entrada?.energia ?? 0), Icons.bolt_outlined, (nivel) {
              final registro = DiarioStore.instance.obtenerOCrear(_clave(_seleccionado));
              registro.energia = nivel;
              DiarioStore.instance.cambio(registro);
            }),
        ],
      ),
    );
  }


  /// Dos discos superpuestos: cada uno conserva su gráfico y sus valores.
  /// El toque intercambia el primer plano; la transición combina profundidad,
  /// inclinación y giro tipo flip sin convertir los gráficos en imágenes.
  Widget _composicionDiagnostica(ColorScheme scheme) {
    final rueda = _cuaderno?.ruedaVida ?? RuedaVida();
    final diagnostico = _cuaderno?.diagnosticoInicial ?? DiagnosticoInicial();

    final ruedaValores = <double>[
      rueda.salud.toDouble(),
      rueda.estudios.toDouble(),
      rueda.trabajo.toDouble(),
      rueda.finanzas.toDouble(),
      rueda.familia.toDouble(),
      rueda.amigos.toDouble(),
      rueda.descanso.toDouble(),
      rueda.crecimiento.toDouble(),
    ];
    const ruedaEtiquetas = [
      'Salud', 'Estudios', 'Trabajo', 'Finanzas',
      'Familia', 'Amigos', 'Descanso', 'Crecimiento',
    ];
    final diagnosticoValores = <double>[
      diagnostico.energia.toDouble(),
      diagnostico.estres.toDouble(),
      diagnostico.claridadMental.toDouble(),
      diagnostico.organizacion.toDouble(),
      diagnostico.motivacion.toDouble(),
      diagnostico.satisfaccionGeneral.toDouble(),
    ];
    const diagnosticoEtiquetas = [
      'Energía', 'Estrés', 'Claridad mental',
      'Organización', 'Motivación', 'Satisfacción general',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Tu punto de partida',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          'Explora la relación entre tu visión de vida y tu diagnóstico inicial.',
          style: TextStyle(
            fontSize: 12,
            height: 1.35,
            color: Colors.white.withValues(alpha: 0.66),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final diameter = math.min(278.0, constraints.maxWidth * 0.76);
            final desplazamiento = diameter * 0.39;
            final total = diameter + desplazamiento;
            return SizedBox(
              height: diameter + 28,
              child: Center(
                child: SizedBox(
                  width: total,
                  height: diameter + 28,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      _discoDiagnostico(
                        diameter: diameter,
                        left: _ruedaAlFrente ? desplazamiento : 0,
                        front: !_ruedaAlFrente,
                        title: 'DIAGNÓSTICO INICIAL',
                        values: diagnosticoValores,
                        labels: diagnosticoEtiquetas,
                        scheme: scheme,
                      ),
                      _discoDiagnostico(
                        diameter: diameter,
                        left: _ruedaAlFrente ? 0 : desplazamiento,
                        front: _ruedaAlFrente,
                        title: 'RUEDA DE LA VIDA',
                        values: ruedaValores,
                        labels: ruedaEtiquetas,
                        scheme: scheme,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        Center(
          child: TextButton.icon(
            onPressed: () => setState(() => _ruedaAlFrente = !_ruedaAlFrente),
            icon: const Icon(Icons.flip, size: 18),
            label: Text(_ruedaAlFrente
                ? 'Ver diagnóstico inicial al frente'
                : 'Ver rueda de la vida al frente'),
            style: TextButton.styleFrom(
              foregroundColor: scheme.primary,
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _discoDiagnostico({
    required double diameter,
    required double left,
    required bool front,
    required String title,
    required List<double> values,
    required List<String> labels,
    required ColorScheme scheme,
  }) {
    final tilt = front ? -0.035 : 0.045;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 720),
      curve: Curves.easeInOutCubic,
      left: left,
      top: front ? 0 : 18,
      width: diameter,
      height: diameter,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 720),
        curve: Curves.easeInOutCubic,
        scale: front ? 1 : 0.91,
        child: AnimatedRotation(
          duration: const Duration(milliseconds: 720),
          curve: Curves.easeInOutCubic,
          turns: front ? 0 : 0.012,
          child: GestureDetector(
            onTap: () => setState(() => _ruedaAlFrente = title == 'RUEDA DE LA VIDA'),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 720),
              curve: Curves.easeInOutCubic,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.28, -0.35),
                  radius: 1.12,
                  colors: [
                    const Color(0xFF263D67).withValues(alpha: front ? 0.98 : 0.90),
                    const Color(0xFF111D3B).withValues(alpha: front ? 0.98 : 0.94),
                    const Color(0xFF080F22),
                  ],
                ),
                border: Border.all(
                  color: front
                      ? const Color(0xFF8CEBFF).withValues(alpha: 0.88)
                      : const Color(0xFFB66BFF).withValues(alpha: 0.65),
                  width: front ? 3.2 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (front ? const Color(0xFF9B4DFF) : const Color(0xFF38CFFF))
                        .withValues(alpha: front ? 0.42 : 0.22),
                    blurRadius: front ? 30 : 17,
                    spreadRadius: front ? 2 : 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.48),
                    blurRadius: 18,
                    offset: const Offset(8, 12),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.10),
                    blurRadius: 2,
                    spreadRadius: -2,
                    offset: const Offset(-4, -5),
                  ),
                ],
              ),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..rotateY(tilt),
                child: Padding(
                  padding: EdgeInsets.all(diameter * 0.075),
                  child: Column(
                    children: [
                      SizedBox(height: diameter * 0.055),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: TextStyle(
                          fontSize: diameter * 0.052,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: front ? 0.98 : 0.76),
                          shadows: const [
                            Shadow(color: Color(0xFFB66BFF), blurRadius: 10),
                          ],
                        ),
                      ),
                      Expanded(
                        child: CustomPaint(
                          painter: _RadarDiagnosticoPainter(
                            values: values,
                            labels: labels,
                            color: title == 'RUEDA DE LA VIDA'
                                ? const Color(0xFFE16BFF)
                                : const Color(0xFF9B75FF),
                            textColor: Colors.white.withValues(alpha: front ? 0.90 : 0.68),
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                      SizedBox(height: diameter * 0.045),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tareasDelDia(ColorScheme scheme) {
    final tareas = _tareas(_seleccionado);
    final hechas = tareas.where((t) => t.done).length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.task_alt, color: scheme.primary),
            const SizedBox(width: 8),
            const Expanded(child: Text('Tareas del día',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            Text('$hechas/${tareas.length}',
              style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 4),
          Text(_fechaLarga(_seleccionado),
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.65))),
          const SizedBox(height: 10),
          if (tareas.isEmpty)
            Text('No hay tareas programadas para este día.',
              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.68)))
          else
            for (final tarea in tareas)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: tarea.done,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(tarea.title,
                  style: TextStyle(
                    fontSize: 13,
                    decoration: tarea.done ? TextDecoration.lineThrough : null,
                    color: tarea.done
                        ? Colors.white.withValues(alpha: 0.55)
                        : Colors.white.withValues(alpha: 0.92),
                  )),
                onChanged: (_) => TasksService.instance.alternar(tarea),
              ),
        ],
      ),
    );
  }

  Widget _puntoInteractivo(int index, ColorScheme scheme) {
    const center = 145.0;
    const radius = 118.0;
    final angle = (index * 2 * 3.141592653589793 / 30) - 3.141592653589793 / 2;
    final x = center + radius * math.cos(angle) - 13;
    final y = center + radius * math.sin(angle) - 13;
    final seleccionado = _clave(_dias[index]) == _clave(_seleccionado);
    return Positioned(
      left: x,
      top: y,
      child: GestureDetector(
        onTap: () => setState(() => _seleccionado = _dias[index]),
        child: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _colorDia(_dias[index]),
            shape: BoxShape.circle,
            border: Border.all(
              color: seleccionado ? Colors.orangeAccent : const Color(0xFF0B1020),
              width: seleccionado ? 2.5 : 1.5,
            ),
          ),
          child: Text(
            '${_dias[index].day}',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: _colorDia(_dias[index]) == _sinRegistro
                  ? Colors.white70
                  : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }


  List<EvaluacionBloque> _evaluacionesDeFecha(DateTime fecha) {
    final clave = _clave(fecha);
    return (_cuaderno?.evaluacionesBloques ?? [])
        .where((e) => e.fecha == clave)
        .toList();
  }

  Widget _resumenEvaluaciones(ColorScheme scheme) {
    final evaluaciones = (_cuaderno?.evaluacionesBloques ?? [])
        .where((e) => _dias.any((d) => _clave(d) == e.fecha))
        .toList();
    final conSatisfaccion = evaluaciones.where((e) => e.satisfaccion > 0).toList();
    final promedio = conSatisfaccion.isEmpty
        ? null
        : conSatisfaccion.map((e) => e.satisfaccion).reduce((a, b) => a + b) /
            conSatisfaccion.length;
    final porBloque = <String, int>{
      'manana': evaluaciones.where((e) => e.bloque == 'manana').length,
      'tarde': evaluaciones.where((e) => e.bloque == 'tarde').length,
      'noche': evaluaciones.where((e) => e.bloque == 'noche').length,
    };
    final apagado = Colors.white.withValues(alpha: 0.68);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.insights_outlined, color: scheme.primary),
            const SizedBox(width: 8),
            const Expanded(child: Text('Evaluación de mi recorrido',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 5),
          Text('Evaluaciones de bloques registradas en este ciclo de 30 días.',
            style: TextStyle(fontSize: 12, color: apagado)),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _datoIndicador('Bloques evaluados', '${evaluaciones.length} de 90'),
              _datoIndicador('Satisfacción media',
                promedio == null ? 'Sin datos' : '${promedio.toStringAsFixed(1)} / 5'),
            ],
          ),
          const SizedBox(height: 14),
          for (final item in [
            ('Mañana', porBloque['manana']!),
            ('Tarde', porBloque['tarde']!),
            ('Noche', porBloque['noche']!),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(children: [
                Expanded(child: Text(item.$1, style: TextStyle(fontSize: 12, color: apagado))),
                Text('${item.$2} evaluaciones', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
          Text('Los bloques sin evaluación no se cuentan como incumplidos ni como satisfacción baja.',
            style: TextStyle(fontSize: 11.5, height: 1.35, color: apagado)),
        ],
      ),
    );
  }

  Widget _datoIndicador(String titulo, String valor) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.68))),
        const SizedBox(height: 4),
        Text(valor, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
      ],
    ),
  );

  Widget _detalleDia(ColorScheme scheme) {
    final e = _entrada(_seleccionado);
    final tareas = _tareas(_seleccionado);
    final hechas = tareas.where((t) => t.done).length;
    final color = _colorDia(_seleccionado);
    final apagado = Colors.white.withValues(alpha: 0.68);

    Widget dato(String titulo, String valor) => Padding(
          padding: const EdgeInsets.only(bottom: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: TextStyle(fontSize: 12, color: apagado)),
              const SizedBox(height: 3),
              Text(valor, style: const TextStyle(fontSize: 14)),
            ],
          ),
        );

    Widget encabezado(String titulo, String subtitulo, IconData icono) => Row(
          children: [
            Icon(icono, color: scheme.primary, size: 19),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
                  Text(subtitulo, style: TextStyle(fontSize: 12, color: apagado)),
                ],
              ),
            ),
          ],
        );

    BoxDecoration decoracion(Color borde) => BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borde.withValues(alpha: 0.55)),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_fechaLarga(_seleccionado), style: TextStyle(
          fontSize: 17, fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: 0.92))),
        const SizedBox(height: 14),

        // Dimensión 1: cómo viviste el día. No es una nota de rendimiento.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(17),
          decoration: decoracion(color),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              encabezado('Mi ritmo', 'Cómo viviste este día', Icons.graphic_eq),
              const SizedBox(height: 17),
              dato('Semáforo personal',
                e == null || e.semaforo.isEmpty
                    ? 'Sin registro'
                    : nombreDeSemaforo(e.semaforo)),
              dato('Energía percibida', _energia(e?.energia ?? 0)),
              dato('Estado emocional', _estado(e?.estado ?? 0)),
              Text(
                'Este registro describe tu experiencia, no determina cuánto vales ni cuánto lograste.',
                style: TextStyle(fontSize: 12, height: 1.4, color: apagado),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Evaluación cualitativa de los bloques del día seleccionado.
        if (_evaluacionesDeFecha(_seleccionado).isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(17),
            decoration: decoracion(scheme.tertiary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                encabezado('Evaluación de la agenda', 'Lo que reconociste en cada momento del día',
                  Icons.rate_review_outlined),
                const SizedBox(height: 14),
                for (final ev in _evaluacionesDeFecha(_seleccionado)) ...[
                  Text(
                    ev.bloque == 'manana' ? 'Mañana' : (ev.bloque == 'tarde' ? 'Tarde' : 'Noche'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (ev.porQueDiaSalioAsi.trim().isNotEmpty)
                    dato('¿Por qué salió así?', ev.porQueDiaSalioAsi),
                  if (ev.comoSalieronActividades.trim().isNotEmpty)
                    dato('¿Cómo salieron las actividades?', ev.comoSalieronActividades),
                  if (ev.satisfaccion > 0)
                    dato('Satisfacción', '${ev.satisfaccion} de 5${ev.porQueSatisfaccion.trim().isEmpty ? '' : ' · ${ev.porQueSatisfaccion}'}'),
                  const Divider(height: 14),
                ],
              ],
            ),
          ),
        ],
        
        // Dimensión 2: aquello a lo que decidiste dar importancia.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(17),
          decoration: decoracion(scheme.primary),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              encabezado('Mis intenciones',
                'Lo que elegiste atender o poner en movimiento',
                Icons.explore_outlined),
              const SizedBox(height: 17),
              dato('Prioridad que elegiste',
                (e?.prioridad ?? '').trim().isEmpty
                    ? 'No registraste una prioridad'
                    : e!.prioridad),
              if (tareas.isNotEmpty) ...[
                const Divider(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Acciones registradas',
                      style: TextStyle(fontSize: 12, color: apagado)),
                    Text('$hechas de ${tareas.length}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 10),
                for (final t in tareas)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Icon(t.done ? Icons.check_circle : Icons.circle_outlined,
                        size: 17, color: t.done ? kColorBien : apagado),
                      const SizedBox(width: 8),
                      Expanded(child: Text(t.title, style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                        decoration: t.done ? TextDecoration.lineThrough : null,
                      ))),
                    ]),
                  ),
              ] else
                Text(
                  'No hay acciones asociadas a este día. Tu intención sigue teniendo valor aunque no se haya convertido en una tarea.',
                  style: TextStyle(fontSize: 12, height: 1.4, color: apagado),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _notaMetodo(ColorScheme scheme) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          'Mi pulso no califica tu valor ni exige días perfectos. Reúne lo que has registrado durante este ciclo para ayudarte a reconocer tu recorrido. Un día sin registro sigue siendo simplemente un día sin información.',
          style: TextStyle(fontSize: 12.5, height: 1.45,
              color: Colors.white.withValues(alpha: 0.82)),
        ),
      );
}



/// Radar numérico reutilizable para la Rueda de la Vida y el Diagnóstico.
class _RadarDiagnosticoPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color color;
  final Color textColor;

  _RadarDiagnosticoPainter({
    required this.values,
    required this.labels,
    required this.color,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.285;
    final count = values.length;
    final gridPaint = Paint()
      ..color = const Color(0xFF9FB8E8).withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final axisPaint = Paint()
      ..color = const Color(0xFF9FB8E8).withValues(alpha: 0.24)
      ..strokeWidth = 0.7;

    for (var level = 1; level <= 10; level++) {
      final r = radius * level / 10;
      final points = List.generate(count, (i) {
        final angle = -math.pi / 2 + 2 * math.pi * i / count;
        return center + Offset(math.cos(angle) * r, math.sin(angle) * r);
      });
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    final polygon = <Offset>[];
    for (var i = 0; i < count; i++) {
      final angle = -math.pi / 2 + 2 * math.pi * i / count;
      final end = center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      canvas.drawLine(center, end, axisPaint);
      final value = values[i].clamp(0, 10).toDouble();
      polygon.add(center + Offset(
        math.cos(angle) * radius * value / 10,
        math.sin(angle) * radius * value / 10,
      ));
    }

    final area = Path()..moveTo(polygon.first.dx, polygon.first.dy);
    for (final point in polygon.skip(1)) {
      area.lineTo(point.dx, point.dy);
    }
    area.close();
    canvas.drawPath(
      area,
      Paint()
        ..color = color.withValues(alpha: 0.22)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      area,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    canvas.drawPath(
      area,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeJoin = StrokeJoin.round,
    );

    for (var i = 0; i < count; i++) {
      final point = polygon[i];
      canvas.drawCircle(point, 3.2, Paint()..color = color);
      canvas.drawCircle(
        point,
        5.3,
        Paint()
          ..color = color.withValues(alpha: 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      final angle = -math.pi / 2 + 2 * math.pi * i / count;
      final labelPoint = center + Offset(
        math.cos(angle) * (radius + 17),
        math.sin(angle) * (radius + 17),
      );
      final text = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: textColor,
            fontSize: 8.5,
            fontWeight: FontWeight.w600,
            shadows: const [Shadow(color: Color(0xFFB66BFF), blurRadius: 5)],
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 2,
      )..layout(maxWidth: 70);
      final offset = Offset(
        (labelPoint.dx - text.width / 2).clamp(0.0, size.width - text.width),
        (labelPoint.dy - text.height / 2).clamp(0.0, size.height - text.height),
      );
      text.paint(canvas, offset);
    }

    // Escala discreta 1–10 en el eje vertical, como referencia numérica.
    for (var level = 2; level <= 10; level += 2) {
      final y = center.dy - radius * level / 10;
      final text = TextPainter(
        text: TextSpan(
          text: '$level',
          style: TextStyle(
            color: textColor.withValues(alpha: 0.58),
            fontSize: 7,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(center.dx + 4, y - text.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _RadarDiagnosticoPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.labels != labels ||
      oldDelegate.color != color ||
      oldDelegate.textColor != textColor;
}

/// Dibuja los 30 segmentos del anillo; el selector táctil se superpone encima.
class _PulsoPainter extends CustomPainter {
  final List<Color> colores;
  final int seleccionado;
  final Color base;

  _PulsoPainter({
    required this.colores,
    required this.seleccionado,
    required this.base,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height / 2);
    const radio = 112.0;
    const grosor = 13.0;
    const separacion = 0.035;
    final rect = Rect.fromCircle(center: centro, radius: radio);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 30; i++) {
      final inicio = -3.141592653589793 / 2 +
          i * 2 * 3.141592653589793 / 30 + separacion;
      paint.color = i < colores.length ? colores[i] : base;
      canvas.drawArc(rect, inicio, 2 * 3.141592653589793 / 30 - separacion * 2,
          false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PulsoPainter oldDelegate) =>
      oldDelegate.colores != colores || oldDelegate.seleccionado != seleccionado;
}

