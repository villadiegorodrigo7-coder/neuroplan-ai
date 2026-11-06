import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/entrada_diario.dart';
import '../models/cuadernillo_data.dart';
import '../services/cuadernillo_service.dart';
import '../models/task.dart';
import '../services/diario_store.dart';
import '../services/tasks_service.dart';
import '../services/agenda_store.dart';

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
    AgendaStore.instance.addListener(_actualizar);
    CuadernilloService.cambios.addListener(_actualizarCuadernillo);
    _cargar();
  }

  Future<void> _cargar() async {
    await Future.wait([
      DiarioStore.instance.cargar(),
      TasksService.instance.cargar(),
      AgendaStore.instance.cargar(),
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

  Future<void> _actualizarCuadernillo() async {
    final data = await CuadernilloService.cargar();
    if (mounted) setState(() => _cuaderno = data);
  }

  @override
  void dispose() {
    DiarioStore.instance.removeListener(_actualizar);
    TasksService.instance.removeListener(_actualizar);
    AgendaStore.instance.removeListener(_actualizar);
    CuadernilloService.cambios.removeListener(_actualizarCuadernillo);
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
                    if (_hayPropuestaRueda)
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
  static const List<Color> _coloresRueda = [
    Color(0xFF35D07F), // Salud
    Color(0xFF45A9FF), // Estudios
    Color(0xFFFF9F43), // Trabajo
    Color(0xFFFFD166), // Finanzas
    Color(0xFFFF6FAE), // Familia
    Color(0xFF35D6C5), // Amigos
    Color(0xFFB28DFF), // Descanso
    Color(0xFFA6D854), // Crecimiento
    Color(0xFFFFE45E), // Energía
    Color(0xFFFF5C65), // Estrés
    Color(0xFF65D8FF), // Claridad mental
    Color(0xFF788BFF), // Organización
    Color(0xFFFF65D4), // Motivación
    Color(0xFFFF876B), // Satisfacción general
  ];

  static const List<String> _etiquetasRueda = [
    'Salud', 'Estudios', 'Trabajo', 'Finanzas', 'Familia', 'Amigos',
    'Descanso', 'Crecimiento', 'Energía', 'Estrés', 'Claridad mental',
    'Organización', 'Motivación', 'Satisfacción general',
  ];

  bool get _hayPropuestaRueda =>
      (_cuaderno?.diagnosticoConversacional?.valoresPropuestos.isNotEmpty ?? false) ||
      (_cuaderno?.diagnosticoConversacional?.confirmado == true);

  bool get _tieneDiagnosticoConversacionalConfirmado =>
      _cuaderno?.diagnosticoConversacional?.confirmado == true;

  List<double> _valoresRuedaUnificada() {
    final diagnostico = _cuaderno?.diagnosticoConversacional;
    final valores = diagnostico?.confirmado == true
        ? diagnostico!.valoresConfirmados
        : diagnostico?.valoresPropuestos ?? const <String, int>{};
    return _etiquetasRueda
        .map((etiqueta) => (valores[etiqueta] ?? 0).toDouble())
        .toList();
  }

  Widget _composicionDiagnostica(ColorScheme scheme) {
    final valores = _valoresRuedaUnificada();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Rueda de la Vida',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        Text(
          _tieneDiagnosticoConversacionalConfirmado\n              ? 'Diagnóstico conversacional confirmado. Puedes volver a revisar tus dimensiones.'\n              : 'Propuesta preliminar de Ágora. Revisa cada dimensión y confirma solo cuando te represente.',
          style: TextStyle(fontSize: 12, height: 1.35,
            color: Colors.white.withValues(alpha: 0.66)),
        ),
        const SizedBox(height: 12),
        Center(
          child: GestureDetector(
            onTap: () => _abrirEditorRadar(scheme: scheme),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 430),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF101A32),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha: 0.13),
                    blurRadius: 24, spreadRadius: 1),
                ],
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 300,
                    child: CustomPaint(
                      painter: _RadarDiagnosticoPainter(
                        values: valores,
                        labels: _etiquetasRueda,
                        color: const Color(0xFF9B75FF),
                        axisColors: _coloresRueda,
                        textColor: Colors.white,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.open_in_full, size: 15, color: Color(0xFF8CEBFF)),
                      const SizedBox(width: 6),
                      Text('Toca para ampliar y editar',
                        style: TextStyle(fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.82))),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _abrirEditorRadar({required ColorScheme scheme}) async {
    final editados = _valoresRuedaUnificada();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, actualizarDialogo) {
          void moverPunto(Offset posicion, Size size) {
            final centro = Offset(size.width / 2, size.height / 2);
            final delta = posicion - centro;
            final radio = math.min(size.width, size.height) * 0.285;
            if (delta.distance < 2) return;
            var angulo = math.atan2(delta.dy, delta.dx) + math.pi / 2;
            if (angulo < 0) angulo += 2 * math.pi;
            final paso = 2 * math.pi / editados.length;
            final indice = ((angulo / paso).round()) % editados.length;
            final valor = (delta.distance / radio * 10).clamp(0.0, 10.0);
            actualizarDialogo(() => editados[indice] = valor);
          }

          return Dialog.fullscreen(
            backgroundColor: const Color(0xFF080F22),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                        const Expanded(
                          child: Text('Rueda de la Vida',
                            style: TextStyle(color: Colors.white,
                              fontSize: 18, fontWeight: FontWeight.w700)),
                        ),
                        TextButton(
                          onPressed: () async {
                            final data = _cuaderno;
                            if (data == null) return;
                            final diagnostico = data.diagnosticoConversacional;
                            if (diagnostico == null) return;
                            for (var i = 0; i < _etiquetasRueda.length; i++) {
                              diagnostico.valoresConfirmados[_etiquetasRueda[i]] =
                                  editados[i].round();
                            }
                            diagnostico.confirmado = true;
                            await CuadernilloService.guardar(data);
                            if (mounted) setState(() {});
                            if (dialogContext.mounted) Navigator.pop(dialogContext);
                          },
                          child: const Text('Guardar',
                            style: TextStyle(color: Color(0xFF8CEBFF),
                              fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Text(
                      'Toca o arrastra sobre el gráfico para ajustar cada dimensión. También puedes usar los controles.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final side = math.min(constraints.maxWidth,
                          constraints.maxHeight * 0.78);
                        return Center(
                          child: SizedBox(
                            width: side,
                            height: side,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapDown: (d) => moverPunto(d.localPosition, Size(side, side)),
                              onPanStart: (d) => moverPunto(d.localPosition, Size(side, side)),
                              onPanUpdate: (d) => moverPunto(d.localPosition, Size(side, side)),
                              child: CustomPaint(
                                painter: _RadarDiagnosticoPainter(
                                  values: editados,
                                  labels: _etiquetasRueda,
                                  color: const Color(0xFF9B75FF),
                                  axisColors: _coloresRueda,
                                  textColor: Colors.white,
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    height: math.min(250, MediaQuery.of(context).size.height * 0.29),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                      itemCount: _etiquetasRueda.length,
                      itemBuilder: (context, index) => Row(
                        children: [
                          Container(width: 9, height: 9,
                            decoration: BoxDecoration(color: _coloresRueda[index],
                              shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 4,
                            child: Text(_etiquetasRueda[index],
                              style: const TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                          Expanded(
                            flex: 6,
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: _coloresRueda[index],
                                thumbColor: _coloresRueda[index],
                                inactiveTrackColor: _coloresRueda[index].withValues(alpha: 0.20),
                              ),
                              child: Slider(
                                value: editados[index].clamp(0, 10).toDouble(),
                                min: 0,
                                max: 10,
                                divisions: 10,
                                onChanged: (value) => actualizarDialogo(
                                  () => editados[index] = value),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 25,
                            child: Text(editados[index].toStringAsFixed(0),
                              textAlign: TextAlign.end,
                              style: TextStyle(color: _coloresRueda[index],
                                fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _tareasDelDia(ColorScheme scheme) {
    final tareasMatriz = _tareas(_seleccionado).where((t) => t.done).toList();
    final compromisos = AgendaStore.instance
        .eventosEnDia(_seleccionado)
        .where((e) => e.realizadaEn(_seleccionado))
        .toList();
    final clave = _clave(_seleccionado);
    final habitos = (_cuaderno?.habitos ?? [])
        .where((h) => h.registros[clave] == true)
        .toList();
    final total = tareasMatriz.length + compromisos.length + habitos.length;

    Widget actividad(String titulo, String origen, IconData icono) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(icono, size: 18, color: scheme.primary),
          const SizedBox(width: 9),
          Expanded(child: Text(titulo, style: const TextStyle(fontSize: 13))),
          Text(origen, style: TextStyle(
            fontSize: 10, color: Colors.white.withValues(alpha: 0.58))),
          const SizedBox(width: 5),
          Icon(Icons.check_circle, size: 16, color: scheme.primary),
        ]),
      );
    }

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
            const Expanded(child: Text('Tareas cumplidas',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            Text('$total', style: TextStyle(
              color: scheme.primary, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 4),
          Text(_fechaLarga(_seleccionado),
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.65))),
          const SizedBox(height: 10),
          if (total == 0)
            Text('Aún no hay actividades cumplidas en este día.',
              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.68)))
          else ...[
            for (final tarea in tareasMatriz)
              actividad(tarea.title, 'Matriz', Icons.checklist),
            for (final evento in compromisos)
              actividad(evento.title, 'Agenda', Icons.event_available),
            for (final habito in habitos)
              actividad(habito.nombre, 'Hábito', Icons.repeat),
          ],
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
  final List<Color>? axisColors;

  _RadarDiagnosticoPainter({
    required this.values,
    required this.labels,
    required this.color,
    required this.textColor,
    this.axisColors,
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
      final axisColor = axisColors != null && i < axisColors!.length ? axisColors![i] : color;
      canvas.drawLine(center, end, Paint()..color = axisColor.withValues(alpha: 0.48)..strokeWidth = 1.1);
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
    for (var i = 0; i < count; i++) {
      final next = (i + 1) % count;
      final sector = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(polygon[i].dx, polygon[i].dy)
        ..lineTo(polygon[next].dx, polygon[next].dy)
        ..close();
      final sectorColor = axisColors != null && i < axisColors!.length
          ? axisColors![i] : color;
      canvas.drawPath(sector, Paint()
        ..color = sectorColor.withValues(alpha: 0.13)
        ..style = PaintingStyle.fill);
      canvas.drawLine(polygon[i], polygon[next], Paint()
        ..color = sectorColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round);
    }

    for (var i = 0; i < count; i++) {
      final point = polygon[i];
      final pointColor = axisColors != null && i < axisColors!.length ? axisColors![i] : color;
      canvas.drawCircle(point, 4.2, Paint()..color = pointColor);
      canvas.drawCircle(
        point,
        5.3,
        Paint()
          ..color = pointColor.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      final angle = -math.pi / 2 + 2 * math.pi * i / count;
      final labelPoint = center + Offset(
        math.cos(angle) * (radius + 17),
        math.sin(angle) * (radius + 17),
      );
      final labelColor = axisColors != null && i < axisColors!.length ? axisColors![i] : textColor;
      final text = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: labelColor,
            fontSize: 9.5,
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
            fontSize: 8,
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
      oldDelegate.textColor != textColor ||
      oldDelegate.axisColors != axisColors;
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

