import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/entrada_diario.dart';
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
  late DateTime _inicioCiclo;

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

  Color _colorDia(DateTime d) {
    final e = _entrada(d);
    if (e == null || e.semaforo.isEmpty) return _sinRegistro;
    return colorDeSemaforo(e.semaforo) ?? _sinRegistro;
  }

  int get _registrados =>
      _dias.where((d) => (_entrada(d)?.semaforo ?? '').isNotEmpty).length;

  int get _bien =>
      _dias.where((d) => _entrada(d)?.semaforo == 'bien').length;

  int get _atencion =>
      _dias.where((d) => _entrada(d)?.semaforo == 'atencion').length;

  int get _desafio =>
      _dias.where((d) => _entrada(d)?.semaforo == 'riesgo').length;

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
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Text(
                  'Tu recorrido · ciclo de 30 días',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
                ),
                const SizedBox(height: 18),
                _anillo(scheme),
                const SizedBox(height: 18),
                _leyenda(),
                const SizedBox(height: 24),
                _detalleDia(scheme),
                const SizedBox(height: 20),
                _notaMetodo(scheme),
              ],
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
                Text('$_registrados',
                    style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w700)),
                Text('de 30 días del ciclo',
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
              color: seleccionado ? scheme.primary : const Color(0xFF0B1020),
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


  Widget _leyenda() {
    Widget item(Color color, String texto, int cantidad) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 9, height: 9,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text('$texto $cantidad', style: const TextStyle(fontSize: 12)),
          ],
        );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 9,
      children: [
        item(kColorBien, 'Bien', _bien),
        item(kColorAtencion, 'Atención', _atencion),
        item(kColorDesafio, 'Desafío', _desafio),
        item(_sinRegistro, 'Sin registro', 30 - _registrados),
      ],
    );
  }

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

