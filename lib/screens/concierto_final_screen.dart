import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/entrada_diario.dart';
import '../models/productividad_data.dart';
import '../widgets/radar_diagnostico_painter.dart';
import '../services/concierto_final_service.dart';
import 'chat_screen.dart';

/// Concierto Final: una lectura musical de registros reales.
/// La vista previa no permite cerrar ni modificar el ciclo.
class ConciertoFinalScreen extends StatefulWidget {
  const ConciertoFinalScreen({super.key, required this.snapshot});
  final ConciertoFinalSnapshot snapshot;

  @override
  State<ConciertoFinalScreen> createState() => _ConciertoFinalScreenState();
}

class _ConciertoFinalScreenState extends State<ConciertoFinalScreen> {
  static const _fondo = Color(0xFF0B1022);
  static const _superficie = Color(0xFF161B35);
  static const _superficieClara = Color(0xFF1D2442);
  static const _lila = Color(0xFFB395F8);
  static const _turquesa = Color(0xFF68DFE8);
  static const _verde = kColorBien;
  static const _amarillo = kColorAtencion;
  static const _rosa = kColorDesafio;
  static const _sinRegistro = Color(0xFF48516C);
  static const _futuro = Color(0xFF2A324C);
  static const _textoTenue = Color(0xFFB6BED8);

  int _diaSeleccionado = 0;
  bool _mostrarRitmo = false;
  bool _mostrarAcciones = false;
  bool _mostrarPartitura = false;
  ConciertoFinalSnapshot get snapshot => widget.snapshot;

  int get _diasVividos {
    if (!snapshot.esVistaPrevia) return snapshot.ciclo.duracionDias;
    final inicio = snapshot.ciclo.inicio;
    final hasta = DateTime.tryParse(snapshot.fechaHasta);
    if (inicio == null || hasta == null) return 0;
    final primerDia = DateTime(inicio.year, inicio.month, inicio.day);
    final ultimoDia = DateTime(hasta.year, hasta.month, hasta.day);
    return (ultimoDia.difference(primerDia).inDays + 1)
        .clamp(0, snapshot.ciclo.duracionDias);
  }

  @override
  void initState() {
    super.initState();
    _diaSeleccionado = _diasVividos > 0 ? _diasVividos - 1 : 0;
  }

  DateTime _fechaDelDia(int indice) {
    final inicio = snapshot.ciclo.inicio!;
    return DateTime(inicio.year, inicio.month, inicio.day + indice);
  }

  String _fechaClave(int indice) =>
      EntradaDiario.claveFecha(_fechaDelDia(indice));

  List<Color> _colores(Map<String, EntradaDiario> diarios) {
    return List.generate(snapshot.ciclo.duracionDias, (i) {
      if (i >= _diasVividos && snapshot.esVistaPrevia) return _futuro;
      return colorDeSemaforo(diarios[_fechaClave(i)]?.semaforo ?? '') ??
          _sinRegistro;
    });
  }

  void _seleccionarDia(int indice) {
    if (indice < 0 || indice >= snapshot.ciclo.duracionDias) return;
    if (snapshot.esVistaPrevia && indice >= _diasVividos) return;
    if (_diaSeleccionado == indice) return;
    setState(() => _diaSeleccionado = indice);
  }

  void _tocarAnillo(TapDownDetails toque, double lado, int cantidad) {
    if (cantidad == 0) return;
    final p = toque.localPosition - Offset(lado / 2, lado / 2);
    final radio = p.distance;
    final centroAnillo = lado * .405;
    if (radio < centroAnillo - 19 || radio > centroAnillo + 19) return;
    final angulo = (math.atan2(p.dy, p.dx) + math.pi / 2 + 2 * math.pi) %
        (2 * math.pi);
    final indice = (angulo / (2 * math.pi) * cantidad).floor();
    _seleccionarDia(indice);
    if (!_mostrarPartitura && (!snapshot.esVistaPrevia ||
        indice < _diasVividos)) {
      setState(() => _mostrarPartitura = true);
    }
  }

  String _nombre(Color color) {
    if (color == _verde) return 'Bien';
    if (color == _amarillo) return 'Atención';
    if (color == _rosa) return 'Desafío';
    if (color == _futuro) return 'Por vivir';
    return 'Sin valoración';
  }

  double? _promedio(Iterable<int> numeros) {
    final validos = numeros.where((v) => v > 0).toList();
    if (validos.isEmpty) return null;
    return validos.reduce((a, b) => a + b) / validos.length;
  }

  Widget _titulo(String titulo, {String? subtitulo, IconData? icono}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 17, 2, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (icono != null) ...[
            Icon(icono, size: 18, color: _lila),
            const SizedBox(width: 9),
          ],
          Expanded(child: Text(titulo,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
              color: Colors.white))),
        ]),
        if (subtitulo != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(subtitulo,
              style: const TextStyle(fontSize: 11, color: _textoTenue)),
          ),
      ]),
    );
  }

  Widget _superficieCard({required Widget child, Color? color}) {
    final acento = color ?? _lila;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _superficie,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: acento.withValues(alpha: 0.20)),
      ),
      child: child,
    );
  }

  Widget _portada() {
    return Column(children: [
      SizedBox(
        height: 158,
        child: Stack(alignment: Alignment.center, children: [
          const Positioned.fill(
            child: CustomPaint(painter: _OndasMusicalesPainter()),
          ),
          Container(
            width: 116, height: 116,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF191C39),
              border: Border.all(color: _lila.withValues(alpha: .75)),
              boxShadow: [
                BoxShadow(color: _lila.withValues(alpha: .12),
                  blurRadius: 48, spreadRadius: 5),
              ],
            ),
            child: const Icon(Icons.music_note_rounded, color: _lila, size: 69),
          ),
        ]),
      ),
      const SizedBox(height: 5),
      const Text('Tu recorrido merece escucharse',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800,
          color: Colors.white)),
      const SizedBox(height: 7),
      Text('${snapshot.ciclo.fechaInicio}  —  ${EntradaDiario.claveFecha(snapshot.ciclo.fechaFin!)}',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: _textoTenue)),
      const SizedBox(height: 5),
      Text(snapshot.esVistaPrevia
          ? 'Una historia que todavía estás escribiendo'
          : 'Un ciclo vivido a tu propio ritmo',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: _lila)),
    ]);
  }


  Widget _estadoCompacto(String etiqueta, int cifra, Color tono,
      IconData icono) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 11),
      decoration: BoxDecoration(
        color: tono.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: tono.withValues(alpha: .16)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icono, size: 15, color: tono),
          const SizedBox(width: 4),
          Text('$cifra', style: TextStyle(
            color: tono, fontSize: 21, fontWeight: FontWeight.w900)),
        ]),
        Text(etiqueta, style: TextStyle(color: tono,
          fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    ));
  }

  Widget _anillo(List<Color> colores) {
    final bien = colores.where((c) => c == _verde).length;
    final atencion = colores.where((c) => c == _amarillo).length;
    final desafio = colores.where((c) => c == _rosa).length;
    final futuros = colores.where((c) => c == _futuro).length;
    final sinRegistro = colores.length - bien - atencion - desafio - futuros;
    return Container(
      key: const ValueKey('concierto-portada-premium'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF171A37), Color(0xFF121C38), Color(0xFF211731)]),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _lila.withValues(alpha: .22)),
        boxShadow: [
          BoxShadow(color: _lila.withValues(alpha: .07),
            blurRadius: 26, spreadRadius: 2),
        ],
      ),
      child: Column(children: [
        SizedBox(height: 252, child: Stack(
          alignment: Alignment.center,
          children: [
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _OrnamentoConciertoPainter()))),
            const Positioned(left: 12, top: 55, child: Icon(
              Icons.music_note_rounded, color: _lila, size: 21)),
            const Positioned(right: 15, bottom: 54, child: Icon(
              Icons.music_note_outlined, color: _turquesa, size: 19)),
            LayoutBuilder(builder: (context, medidas) {
              final lado = math.min(242.0, medidas.maxWidth);
              return GestureDetector(
                key: const ValueKey('concierto-anillo-interactivo'),
                behavior: HitTestBehavior.opaque,
                onTapDown: (toque) =>
                    _tocarAnillo(toque, lado, colores.length),
                child: SizedBox(width: lado, height: lado, child: Stack(
                  alignment: Alignment.center, children: [
                    CustomPaint(size: Size(lado, lado),
                      painter: _AnilloConciertoPainter(
                        colores: colores, seleccionado: _diaSeleccionado)),
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('TU RECORRIDO', style: TextStyle(
                        fontSize: 11, letterSpacing: 2.4, color: _textoTenue)),
                      const SizedBox(height: 5),
                      Row(mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic, children: [
                          Text('$_diasVividos', key:
                            const ValueKey('concierto-dias-vividos'),
                            style: const TextStyle(color: Colors.white,
                              fontSize: 57, height: 1,
                              fontWeight: FontWeight.w800)),
                          Text('/${snapshot.ciclo.duracionDias}', style:
                            const TextStyle(color: _textoTenue,
                              fontSize: 22, fontWeight: FontWeight.w600)),
                        ]),
                      const SizedBox(height: 5),
                      const Text('días de ciclo', style: TextStyle(
                        fontSize: 13, color: Colors.white)),
                      const SizedBox(height: 8),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 190),
                        child: Text('Día ${_diaSeleccionado + 1}',
                          key: ValueKey(_diaSeleccionado),
                          style: TextStyle(fontSize: 10,
                            color: colores[_diaSeleccionado])),
                      ),
                    ]),
                  ]),
                ),
              );
            }),
          ],
        )),
        const SizedBox(height: 1),
        const Text('Cada día tiene su propio color.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
            color: Color(0xFFE4DFF8))),
        const SizedBox(height: 15),
        Row(children: [
          _estadoCompacto('Bien', bien, _verde, Icons.spa_outlined),
          const SizedBox(width: 7),
          _estadoCompacto('Atención', atencion, _amarillo,
            Icons.warning_amber_rounded),
          const SizedBox(width: 7),
          _estadoCompacto('Desafío', desafio, _rosa,
            Icons.bolt_rounded),
        ]),
        const SizedBox(height: 13),
        Wrap(
          alignment: WrapAlignment.center, spacing: 12, runSpacing: 5,
          children: [
            Text('$sinRegistro sin registro', style: const TextStyle(
              color: _textoTenue, fontSize: 11)),
            if (snapshot.esVistaPrevia)
              Text('$futuros por vivir', style: const TextStyle(
                color: _textoTenue, fontSize: 11)),
          ],
        ),
      ]),
    );
  }


  Widget _partitura(List<Color> colores, Map<String, EntradaDiario> diarios) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _titulo('La partitura de tus días',
        icono: Icons.graphic_eq_rounded, subtitulo: 'Toca una nota para explorar su día'),
      LayoutBuilder(builder: (context, c) {
        final porFila = c.maxWidth < 420 ? 10 : 15;
        final filas = (colores.length / porFila).ceil();
        return Column(children: List.generate(filas, (fila) {
          final inicio = fila * porFila;
          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: SizedBox(height: 69, child: Stack(children: [
              const Positioned.fill(child: CustomPaint(
                painter: _PentagramaPainter())),
              Row(children: List.generate(porFila, (col) {
                final i = inicio + col;
                if (i >= colores.length) return const Expanded(child: SizedBox());
                final color = colores[i];
                final seleccionado = i == _diaSeleccionado;
                final disponible = !snapshot.esVistaPrevia || i < _diasVividos;
                return Expanded(child: Tooltip(
                  message: 'Día ${i + 1}',
                  child: InkWell(
                    key: ValueKey('concierto-dia-${i + 1}'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: disponible ? () => _seleccionarDia(i) : null,
                    child: Column(children: [
                      SizedBox(height: 46, child: Center(child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 26, height: 36,
                        decoration: seleccionado
                            ? BoxDecoration(color: color.withValues(alpha: .18),
                                borderRadius: BorderRadius.circular(14))
                            : null,
                        child: Icon(Icons.music_note_rounded, size: 24,
                          color: color),
                      ))),
                      Text('${i + 1}', style: TextStyle(
                        fontSize: 10,
                        fontWeight: seleccionado
                            ? FontWeight.w900 : FontWeight.normal,
                        color: seleccionado ? color : _textoTenue)),
                    ]),
                  ),
                ));
              })), 
            ])),
          );
        }));
      }),
      const SizedBox(height: 2),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        switchInCurve: Curves.easeOutCubic,
        child: KeyedSubtree(
          key: ValueKey('detalle-dia-$_diaSeleccionado'),
          child: _detalleDia(diarios, colores),
        ),
      ),
    ]);
  }

  Widget _detalleDia(Map<String, EntradaDiario> diarios, List<Color> colores) {
    final indice = _diaSeleccionado.clamp(0, colores.length - 1);
    final entrada = diarios[_fechaClave(indice)];
    final color = colores[indice];
    final energia = entrada?.energia ?? 0;
    final estado = entrada?.estado ?? 0;
    return Container(
      key: const ValueKey('concierto-detalle-dia'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _superficieClara,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Día ${indice + 1} · ${_fechaClave(indice)}',
            style: const TextStyle(fontSize: 12,
              fontWeight: FontWeight.w800))),
          Container(width: 7, height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(_nombre(color), style: const TextStyle(
            fontSize: 11, color: _textoTenue)),
        ]),
        if (energia > 0 || estado > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              if (energia > 0) ...[
                const Icon(Icons.bolt_rounded, size: 15, color: _turquesa),
                Text('Energía: ${energia}/5', style: const TextStyle(
                  fontSize: 11, color: _textoTenue)),
              ],
              if (energia > 0 && estado > 0) const SizedBox(width: 15),
              if (estado > 0) ...[
                const Icon(Icons.favorite_rounded, size: 15, color: _lila),
                Text('Estado: ${estado}/5', style: const TextStyle(
                  fontSize: 11, color: _textoTenue)),
              ],
            ]),
          )
        else if (color != _futuro)
          const Padding(
            padding: EdgeInsets.only(top: 7),
            child: Text('Sin indicadores registrados para este día',
              style: TextStyle(fontSize: 11, color: _textoTenue)),
          ),
      ]),
    );
  }


  Widget _bienestarVisual({
    required String titulo, required IconData icono,
    required Color tono, required double? valor, required int registros,
  }) {
    final porcentaje = ((valor ?? 0) / 5).clamp(0.0, 1.0);
    return Expanded(child: Container(
      key: ValueKey('concierto-bienestar-$titulo'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            tono.withValues(alpha: .22),
            const Color(0xFF172039),
          ],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tono.withValues(alpha: .30)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 42, height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(
                color: tono.withValues(alpha: .20), blurRadius: 23)],
            ),
            child: Icon(icono, size: 39, color: tono)),
          const SizedBox(width: 7),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, height: 1.15,
                  fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              Text(valor == null ? '—' :
                '${valor.toStringAsFixed(1).replaceAll('.', ',')} / 5',
                style: TextStyle(fontWeight: FontWeight.w900,
                  fontSize: 18, color: tono)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        ClipRRect(borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: porcentaje),
            duration: MediaQuery.maybeOf(context)?.disableAnimations == true
                ? Duration.zero : const Duration(milliseconds: 560),
            builder: (context, value, _) => LinearProgressIndicator(
              minHeight: 6, value: value,
              backgroundColor: Colors.white.withValues(alpha: .12),
              valueColor: AlwaysStoppedAnimation<Color>(tono)),
          )),
        const SizedBox(height: 7),
        Text('$registros días registrados',
          style: const TextStyle(fontSize: 10, color: _textoTenue)),
      ]),
    ));
  }


  Widget _graficoRitmo(String titulo, Color color,
      int Function(EntradaDiario) valor, int totalDias,
      Map<String, EntradaDiario> diarios) {
    final serie = List<int>.generate(totalDias, (i) {
      if (snapshot.esVistaPrevia && i >= _diasVividos) return 0;
      final entrada = diarios[_fechaClave(i)];
      return entrada == null ? 0 : valor(entrada);
    });
    final disponibles = serie.where((n) => n > 0).length;
    return Padding(
      padding: const EdgeInsets.only(top: 11),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(titulo, style: TextStyle(color: color,
            fontSize: 12, fontWeight: FontWeight.w800)),
          Text('$disponibles registros',
            style: const TextStyle(color: _textoTenue, fontSize: 10)),
        ]),
        const SizedBox(height: 7),
        Semantics(
          label: '$titulo: $disponibles días valorados sobre 5; '
            'los días sin información se muestran sin conectar',
          child: SizedBox(height: 77, width: double.infinity,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: MediaQuery.maybeOf(context)?.disableAnimations == true
                  ? Duration.zero : const Duration(milliseconds: 470),
              builder: (context, avance, _) => CustomPaint(
                painter: _EvolucionDiasPainter(
                  valores: serie, color: color, avance: avance)),
            )),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Día 1', style: TextStyle(
            color: _textoTenue, fontSize: 10)),
          Text('Día $totalDias', style: const TextStyle(
            color: _textoTenue, fontSize: 10)),
        ]),
      ]),
    );
  }

  Widget _tendencias(Map<String, EntradaDiario> diarios) {
    return _superficieCard(color: _turquesa, child: Column(children: [
      _graficoRitmo('Energía', _turquesa, (e) => e.energia,
        snapshot.ciclo.duracionDias, diarios),
      const SizedBox(height: 13),
      _graficoRitmo('Estado emocional', _lila, (e) => e.estado,
        snapshot.ciclo.duracionDias, diarios),
    ]));
  }

  Widget _progreso(int marcado, int total, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: SizedBox(height: 9, child: LinearProgressIndicator(
        value: total == 0 ? 0 : marcado / total,
        backgroundColor: Colors.white.withValues(alpha: .10),
        color: color,
      )),
    );
  }

  Widget _filaAccion({
    required IconData icono,
    required Color color,
    required String fecha,
    required String texto,
    required String estado,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(children: [
        Icon(icono, color: color, size: 17),
        const SizedBox(width: 9),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(texto, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12,
                fontWeight: FontWeight.w600)),
            Text('$fecha · $estado',
              style: const TextStyle(color: _textoTenue, fontSize: 10)),
          ],
        )),
      ]),
    );
  }

  Widget _detalleAcciones() {
    final tareas = snapshot.tareas;
    final compromisos = snapshot.agenda;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 9),
      Container(height: 1, color: Colors.white.withValues(alpha: .09)),
      const SizedBox(height: 12),
      const Text('Tareas registradas', style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w800, color: _verde)),
      if (tareas.isEmpty)
        const Padding(padding: EdgeInsets.only(top: 6),
          child: Text('Sin tareas guardadas en este período.',
            style: TextStyle(fontSize: 11, color: _textoTenue))),
      for (final tarea in tareas.take(8))
        _filaAccion(
          icono: tarea.done ? Icons.check_circle_rounded
              : Icons.circle_outlined,
          color: tarea.done ? _verde : _sinRegistro,
          fecha: tarea.fecha,
          texto: tarea.title,
          estado: tarea.done ? 'Cumplida' : 'Pendiente registrada',
        ),
      if (tareas.length > 8)
        Padding(padding: const EdgeInsets.only(top: 8),
          child: Text('Y ${tareas.length - 8} tareas guardadas más',
            style: const TextStyle(fontSize: 11, color: _textoTenue))),
      const SizedBox(height: 16),
      const Text('Compromisos registrados', style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w800, color: _turquesa)),
      if (compromisos.isEmpty)
        const Padding(padding: EdgeInsets.only(top: 6),
          child: Text('Sin compromisos registrados en este período.',
            style: TextStyle(fontSize: 11, color: _textoTenue))),
      for (final evento in compromisos.take(8))
        _filaAccion(
          icono: evento.cumplida ? Icons.check_circle_rounded
              : evento.marcada ? Icons.cancel_outlined
              : Icons.radio_button_unchecked_rounded,
          color: evento.cumplida ? _turquesa
              : evento.marcada ? _rosa : _sinRegistro,
          fecha: evento.fecha,
          texto: evento.titulo,
          estado: evento.cumplida ? 'Cumplido'
              : evento.marcada ? 'Marcado como no cumplido'
              : 'Sin marcar',
        ),
      if (compromisos.length > 8)
        Padding(padding: const EdgeInsets.only(top: 8),
          child: Text('Y ${compromisos.length - 8} compromisos más',
            style: const TextStyle(fontSize: 11, color: _textoTenue))),
      const SizedBox(height: 12),
      const Text('Se muestran registros disponibles; las tareas eliminadas '
        'no forman parte de este resumen.',
        style: TextStyle(color: _textoTenue, fontSize: 10.5)),
    ]);
  }


  Widget _accionVisual({
    required String titulo, required int principal,
    required int secundarios, required Color tono,
    required IconData icono, required String descripcion,
  }) {
    final total = principal + secundarios;
    final llenas = total == 0 ? 0 : (principal / total * 5).round();
    return Expanded(child: Container(
      padding: const EdgeInsets.fromLTRB(11, 12, 11, 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          tono.withValues(alpha: .23),
          tono.withValues(alpha: .09),
        ]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tono.withValues(alpha: .30)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icono, color: tono, size: 17),
          const SizedBox(width: 6),
          Text(titulo, style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 9),
        Row(children: [
          Text('$principal', style: TextStyle(
            color: tono, fontSize: 28, height: 1,
            fontWeight: FontWeight.w900)),
          const SizedBox(width: 10),
          Expanded(child: Row(children: List.generate(5, (i) =>
            Expanded(child: Container(
              height: 12, margin: const EdgeInsets.only(right: 3),
              decoration: BoxDecoration(
                color: i < llenas ? tono :
                  Colors.white.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(4)),
              child: i < llenas ? const Icon(Icons.check,
                size: 9, color: Color(0xFF0B1022)) : null,
            )),
          ))),
        ]),
        const SizedBox(height: 7),
        Text(descripcion, maxLines: 2,
          style: const TextStyle(fontSize: 10,
            color: _textoTenue, height: 1.25)),
      ]),
    ));
  }

  Widget _acciones() {
    final hechas = snapshot.tareasCompletadas;
    final pendientes = snapshot.tareasPendientesRegistradas;
    final agendaHecha = snapshot.compromisosCumplidos;
    final sinMarcar = snapshot.compromisosSinMarca;
    final noCumplidos = snapshot.compromisosMarcadosNoCumplidos;
    return Column(children: [
      Row(children: [
        _accionVisual(titulo: 'Tareas',
          principal: hechas, secundarios: pendientes,
          tono: _verde, icono: Icons.assignment_turned_in_outlined,
          descripcion: '$hechas cumplidas · $pendientes pendientes'),
        const SizedBox(width: 9),
        _accionVisual(titulo: 'Agenda',
          principal: agendaHecha, secundarios: sinMarcar + noCumplidos,
          tono: _turquesa, icono: Icons.calendar_month_rounded,
          descripcion: '$agendaHecha cumplidos · $sinMarcar sin marcar'),
      ]),
      Align(alignment: Alignment.centerRight, child: TextButton.icon(
        key: const ValueKey('concierto-toggle-acciones'),
        onPressed: () => setState(() => _mostrarAcciones = !_mostrarAcciones),
        icon: Icon(_mostrarAcciones ?
          Icons.keyboard_arrow_up_rounded :
          Icons.keyboard_arrow_down_rounded, size: 16),
        label: Text(_mostrarAcciones ? 'Ocultar registros' : 'Ver registros'),
        style: TextButton.styleFrom(foregroundColor: _turquesa,
          textStyle: const TextStyle(fontSize: 11)),
      )),
      AnimatedSize(
        duration: const Duration(milliseconds: 240),
        child: _mostrarAcciones ? _superficieCard(
          color: _turquesa, child: _detalleAcciones())
          : const SizedBox.shrink(),
      ),
    ]);
  }



  Widget _barraHabito(String nombre, int afirmativas,
      int total, Color tono) {
    final segmentos = total == 0 ? 5 : math.min(total, 12);
    final usados = total == 0 ? 0 :
      (afirmativas / total * segmentos).round();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(nombre, style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700))),
        Text('$afirmativas/$total', style: TextStyle(
          color: tono, fontSize: 13, fontWeight: FontWeight.w900)),
      ]),
      const SizedBox(height: 7),
      Row(children: List.generate(segmentos, (i) =>
        Expanded(child: Container(
          height: 6, margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: i < usados ? tono :
              Colors.white.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(5)),
        )),
      )),
    ]);
  }

  Widget _cultivando() {
    final porIncorporar = snapshot.habitos
        .where((h) => h.tipo == 'incorporar').toList();
    final porAlejar = snapshot.habitos
        .where((h) => h.tipo == 'alejar').toList();
    final siIncorporar = porIncorporar.where((h) => h.realizado).length;
    final siAlejar = porAlejar.where((h) => h.realizado).length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 13, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [
          Color(0xFF172F30), Color(0xFF13272D), Color(0xFF171C32),
        ]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _verde.withValues(alpha: .23)),
      ),
      child: Row(children: [
        SizedBox(width: 105, height: 127,
          child: CustomPaint(painter: _PlantaConciertoPainter(
            progreso: porIncorporar.isEmpty ? 0.0 :
              siIncorporar / porIncorporar.length))),
        Container(width: 1, height: 101,
          color: Colors.white.withValues(alpha: .12)),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            _barraHabito('Por incorporar', siIncorporar,
              porIncorporar.length, _verde),
            const SizedBox(height: 16),
            _barraHabito('Por alejar', siAlejar,
              porAlejar.length, _lila),
            const SizedBox(height: 8),
            const Text('Marcas afirmativas', style: TextStyle(
              color: _textoTenue, fontSize: 10,
              fontStyle: FontStyle.italic)),
          ]),
        ),
      ]),
    );
  }



  void _abrirRuedaInicial() {
    final valores = snapshot.valoresRuedaInicial;
    if (valores.isEmpty) return;
    final faltantes = <int>{
      for (var i = 0; i < pilaresRuedaVida.length; i++)
        if (!valores.containsKey(pilaresRuedaVida[i])) i,
    };
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF12182F),
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false, initialChildSize: .85,
        minChildSize: .48, maxChildSize: .96,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(19, 18, 19, 30),
          children: [
            Center(child: Container(
              height: 4, width: 42,
              decoration: BoxDecoration(
                color: _lila.withValues(alpha: .40),
                borderRadius: BorderRadius.circular(9)))),
            const SizedBox(height: 17),
            const Text('Tu Rueda de la Vida',
              style: TextStyle(color: Colors.white, fontSize: 19,
                fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Text(snapshot.ruedaInicialHistorica
                ? 'Punto de partida registrado'
                : 'Valores de tu diagnóstico confirmado',
              style: const TextStyle(color: _textoTenue, fontSize: 12)),
            const SizedBox(height: 14),
            SizedBox(
              height: 310, width: double.infinity,
              child: CustomPaint(
                key: const ValueKey('concierto-radar-real'),
                painter: RadarDiagnosticoPainter(
                  values: [
                    for (final p in pilaresRuedaVida)
                      (valores[p] ?? 0).toDouble(),
                  ],
                  labels: pilaresRuedaVida,
                  color: _lila,
                  textColor: const Color(0xFFDDE3FB),
                  missingIndices: faltantes,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('Dimensiones registradas · ${valores.length} de '
                '${pilaresRuedaVida.length}',
              style: const TextStyle(color: _textoTenue,
                fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            for (final pilar in pilaresRuedaVida)
              if (valores.containsKey(pilar))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(children: [
                    Expanded(child: Text(pilar, style: const TextStyle(
                      color: Color(0xFFE6E8FC), fontSize: 12))),
                    Text('${valores[pilar]}/10', style: const TextStyle(
                      color: _lila, fontSize: 13,
                      fontWeight: FontWeight.w800)),
                  ]),
                ),
            const SizedBox(height: 12),
            const Row(children: [
              Icon(Icons.lock_outline_rounded, color: _lila, size: 17),
              SizedBox(width: 8),
              Expanded(child: Text(
                'La evaluación final seguirá pendiente hasta tu cierre.',
                style: TextStyle(color: _textoTenue, fontSize: 11))),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _transformacion() {
    final valores = snapshot.valoresRuedaInicial;
    final tieneRueda = valores.isNotEmpty;
    return InkWell(
      key: const ValueKey('concierto-rueda-inicial'),
      onTap: tieneRueda ? _abrirRuedaInicial : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [
            Color(0xFF241E3E), Color(0xFF1A203B), Color(0xFF291D46),
          ]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _lila.withValues(alpha: .28)),
        ),
        child: Row(children: [
          SizedBox(width: 92, height: 94,
            child: tieneRueda
                ? Semantics(
                    label: 'Rueda inicial con ${valores.length} '
                      'dimensiones registradas',
                    child: CustomPaint(
                      key: const ValueKey('concierto-radar-inicial'),
                      painter: _RadarInicialCompactoPainter(
                        valores: valores, color: _lila)),
                  )
                : const Stack(alignment: Alignment.center, children: [
                    CustomPaint(size: Size(88, 88),
                      painter: _RadarVacioPainter()),
                    Icon(Icons.lock_outline_rounded,
                      color: _lila, size: 24),
                  ]),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Rueda de la Vida', style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              if (tieneRueda) ...[
                Text(snapshot.ruedaInicialHistorica
                    ? 'Tu punto de partida registrado'
                    : 'Tu diagnóstico confirmado',
                  style: const TextStyle(
                    fontSize: 11, color: Color(0xFFDBC7FC),
                    fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('${valores.length} dimensiones · Toca para ampliar',
                  style: const TextStyle(
                    fontSize: 10.5, color: _textoTenue)),
              ] else
                const Text('No hay dimensiones confirmadas. '
                    'Revisa tu diagnóstico inicial en Mi Pulso.',
                  style: TextStyle(
                    fontSize: 11, height: 1.4, color: _textoTenue)),
              const SizedBox(height: 8),
              const Row(children: [
                Icon(Icons.lock_outline_rounded, size: 13, color: _lila),
                SizedBox(width: 4),
                Expanded(child: Text('Evaluación final pendiente',
                  style: TextStyle(fontSize: 10,
                    color: _textoTenue))),
              ]),
            ]),
          )),
          if (tieneRueda)
            const Icon(Icons.chevron_right_rounded,
              color: _lila, size: 18),
        ]),
      ),
    );
  }

  Widget _pieMusical() {
    return Column(children: [
      SizedBox(height: 42, child: Stack(alignment: Alignment.center, children: [
        const Positioned.fill(child: CustomPaint(
          painter: _OndasMusicalesPainter())),
        const Icon(Icons.music_note_rounded, color: _lila, size: 29),
      ])),
      const Text('Concierto Final', style: TextStyle(
        color: _lila, fontSize: 21,
        fontWeight: FontWeight.w800, fontStyle: FontStyle.italic)),
      const SizedBox(height: 5),
      Text(snapshot.esVistaPrevia
          ? 'Disponible al culminar tus 30 días.'
          : 'Tu recorrido está listo para escucharse.',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: _textoTenue)),
      const SizedBox(height: 9),
      if (!snapshot.esVistaPrevia) ...[
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) =>
              ChatScreen(conciertoFinalSnapshot: snapshot))),
          icon: const Icon(Icons.auto_awesome_rounded),
          label: const Text('Reflexionar con Ágora'),
          style: FilledButton.styleFrom(
            backgroundColor: _lila, foregroundColor: _fondo),
        ),
        const SizedBox(height: 10),
      ],
      const Text('Un paso, un día, un compás.',
        style: TextStyle(color: _lila,
          fontSize: 11, fontStyle: FontStyle.italic)),
    ]);
  }



  @override
  Widget build(BuildContext context) {
    final diarios = {for (final e in snapshot.diarios) e.fecha: e};
    final colores = _colores(diarios);
    final energia = _promedio(snapshot.diarios.map((e) => e.energia));
    final estado = _promedio(snapshot.diarios.map((e) => e.estado));
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        title: const Text('Mi recorrido',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        backgroundColor: _fondo,
        surfaceTintColor: Colors.transparent,
        actions: [
          Padding(padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text(snapshot.esVistaPrevia
                ? 'Vista previa' : 'Concierto Final',
              style: const TextStyle(color: _lila, fontSize: 12)))),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B1022), Color(0xFF0D1429),
              Color(0xFF121027)],
          ),
        ),
        child: SafeArea(child: ListView(
          padding: const EdgeInsets.fromLTRB(13, 7, 13, 31),
          children: [
            _anillo(colores),
            const SizedBox(height: 7),
            InkWell(
              key: const ValueKey('concierto-toggle-partitura'),
              borderRadius: BorderRadius.circular(13),
              onTap: () => setState(() =>
                _mostrarPartitura = !_mostrarPartitura),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9, vertical: 11),
                child: Row(children: [
                  const Icon(Icons.queue_music_rounded,
                    color: _lila, size: 17),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Explorar mis días',
                    style: TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w700))),
                  Icon(_mostrarPartitura ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                    size: 20, color: _lila),
                ]),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOut,
              child: _mostrarPartitura
                  ? _partitura(colores, diarios)
                  : const SizedBox.shrink(),
            ),
            InkWell(
              key: const ValueKey('concierto-toggle-ritmo'),
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _mostrarRitmo = !_mostrarRitmo),
              child: Row(children: [
                Expanded(child: _titulo('Tu bienestar',
                  icono: Icons.monitor_heart_outlined)),
                Text(_mostrarRitmo ? 'Ocultar' : 'Ver evolución',
                  style: const TextStyle(color: _lila, fontSize: 11)),
                Icon(_mostrarRitmo ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded, color: _lila),
              ]),
            ),
            Row(children: [
              _bienestarVisual(titulo: 'Energía media',
                icono: Icons.wb_sunny_outlined,
                tono: _turquesa, valor: energia,
                registros: snapshot.diasConEnergia),
              const SizedBox(width: 9),
              _bienestarVisual(titulo: 'Estado emocional medio',
                icono: Icons.favorite_rounded,
                tono: _lila, valor: estado,
                registros: snapshot.diasConEstado),
            ]),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              child: _mostrarRitmo ? Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _tendencias(diarios)) : const SizedBox.shrink(),
            ),
            _titulo('Tus acciones', icono: Icons.task_alt_rounded),
            _acciones(),
            _titulo('Hábitos', icono: Icons.spa_outlined),
            _cultivando(),
            const SizedBox(height: 18),
            _transformacion(),
            const SizedBox(height: 19),
            _pieMusical(),
          ],
        )),
      ),
    );
  }



}

/// Portada: ondas y estrellas dibujadas, sin recursos externos.
class _OndasMusicalesPainter extends CustomPainter {
  const _OndasMusicalesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 6; i++) {
      final y = size.height * (.40 + i * .038);
      final ruta = Path()
        ..moveTo(0, y)
        ..cubicTo(size.width * .25, y - 90,
          size.width * .35, y + 83,
          size.width * .53, y - 9)
        ..cubicTo(size.width * .75, y - 85,
          size.width * .78, y - 48,
          size.width, y + 5);
      canvas.drawPath(ruta, Paint()
        ..color = const Color(0xFFB395F8).withValues(alpha: .28 - i * .025)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1);
    }
    const estrellas = <Offset>[
      Offset(.12, .19), Offset(.24, .72), Offset(.38, .19),
      Offset(.68, .25), Offset(.86, .76), Offset(.93, .19),
      Offset(.52, .87), Offset(.08, .80),
    ];
    for (final p in estrellas) {
      canvas.drawCircle(Offset(p.dx * size.width, p.dy * size.height),
        2, Paint()..color = const Color(0xFFB395F8).withValues(alpha: .75));
    }
  }

  @override
  bool shouldRepaint(covariant _OndasMusicalesPainter oldDelegate) => false;
}

class _AnilloConciertoPainter extends CustomPainter {
  const _AnilloConciertoPainter({
    required this.colores,
    required this.seleccionado,
  });
  final List<Color> colores;
  final int seleccionado;

  @override
  void paint(Canvas canvas, Size size) {
    if (colores.isEmpty) return;
    final centro = Offset(size.width / 2, size.height / 2);
    final radio = math.min(size.width, size.height) * .405;
    final rect = Rect.fromCircle(center: centro, radius: radio);
    final paso = math.pi * 2 / colores.length;
    const separacion = .065;
    final lapiz = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < colores.length; i++) {
      lapiz.color = colores[i];
      lapiz.strokeWidth = seleccionado == i ? 13 : 10;
      canvas.drawArc(rect, -math.pi / 2 + paso * i + separacion / 2,
        paso - separacion, false, lapiz);
    }
    canvas.drawCircle(centro, radio * .68, Paint()
      ..color = const Color(0xFFB395F8).withValues(alpha: .28)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant _AnilloConciertoPainter old) =>
      old.seleccionado != seleccionado || old.colores != colores;
}

class _PentagramaPainter extends CustomPainter {
  const _PentagramaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final lapiz = Paint()
      ..color = const Color(0xFF7781A5).withValues(alpha: .30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8;
    for (var i = 0; i < 5; i++) {
      final y = 9.0 + i * 8.0;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), lapiz);
    }
  }

  @override
  bool shouldRepaint(covariant _PentagramaPainter old) => false;
}

class _MedidorCircularPainter extends CustomPainter {
  const _MedidorCircularPainter({required this.progreso, required this.color});
  final double progreso;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: size.width * .43,
    );
    final lapiz = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    lapiz.color = const Color(0xFF2C3552);
    canvas.drawArc(r, -math.pi / 2, math.pi * 2, false, lapiz);
    lapiz.color = color;
    if (progreso > 0) {
      canvas.drawArc(r, -math.pi / 2, math.pi * 2 * progreso,
        false, lapiz);
    }
  }

  @override
  bool shouldRepaint(covariant _MedidorCircularPainter old) =>
      old.progreso != progreso || old.color != color;
}

class _RadarVacioPainter extends CustomPainter {
  const _RadarVacioPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height / 2);
    final radio = size.width * .46;
    final lapiz = Paint()
      ..color = const Color(0xFFB395F8).withValues(alpha: .28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final frac in [.25, .5, .75, 1.0]) {
      canvas.drawCircle(centro, radio * frac, lapiz);
    }
    for (var i = 0; i < 8; i++) {
      final ang = math.pi * 2 * i / 8;
      canvas.drawLine(centro, centro +
        Offset(math.cos(ang) * radio, math.sin(ang) * radio), lapiz);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarVacioPainter old) => false;
}

class _EvolucionDiasPainter extends CustomPainter {
  const _EvolucionDiasPainter({
    required this.valores, required this.color, required this.avance,
  });
  final List<int> valores;
  final Color color;
  final double avance;

  @override
  void paint(Canvas canvas, Size size) {
    const horizontal = 10.0;
    const vertical = 10.0;
    final ancho = math.max(0.0, size.width - horizontal * 2);
    final alto = math.max(0.0, size.height - vertical * 2);
    final cuadricula = Paint()
      ..color = const Color(0xFFB6BED8).withValues(alpha: .14)
      ..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      final y = vertical + alto * i / 4;
      canvas.drawLine(Offset(horizontal, y),
        Offset(size.width - horizontal, y), cuadricula);
    }
    if (valores.isEmpty) return;
    final ultimo = valores.length - 1;
    final trazo = Paint()
      ..color = color
      ..strokeWidth = 2.3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final punto = Paint()..color = color;
    Offset posicion(int i) {
      final v = valores[i].clamp(1, 5);
      return Offset(horizontal + ancho * i / math.max(1, ultimo),
        vertical + (5 - v) / 4 * alto);
    }
    for (var i = 0; i < valores.length; i++) {
      final xNormalizado = ultimo == 0 ? 0.0 : i / ultimo;
      if (xNormalizado > avance || valores[i] <= 0) continue;
      final actual = posicion(i);
      if (i > 0 && valores[i - 1] > 0) {
        canvas.drawLine(posicion(i - 1), actual, trazo);
      }
      canvas.drawCircle(actual, 3.5, punto);
      canvas.drawCircle(actual, 1.5, Paint()..color = const Color(0xFF161B35));
    }
  }

  @override
  bool shouldRepaint(covariant _EvolucionDiasPainter old) =>
      old.avance != avance || old.color != color || old.valores != valores;
}

/// Una planta por cada una de las últimas seis marcas observadas.
/// Los brotes destacados corresponden exactamente a registros afirmativos.
class _BrotesHabitosPainter extends CustomPainter {
  const _BrotesHabitosPainter({required this.marcas, required this.color});
  final List<bool> marcas;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (marcas.isEmpty) return;
    final suelo = Paint()
      ..color = const Color(0xFFB6BED8).withValues(alpha: .28)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final base = size.height - 11;
    canvas.drawLine(Offset(4, base),
      Offset(size.width - 4, base), suelo);
    final paso = (size.width - 12) / (marcas.length + 1);
    for (var i = 0; i < marcas.length; i++) {
      final x = 6 + paso * (i + 1);
      final altura = 20.0 + (i % 3) * 9.0;
      final tono = marcas[i] ? color : const Color(0xFF48516C);
      final tallo = Paint()
        ..color = tono.withValues(alpha: marcas[i] ? .95 : .58)
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x, base),
        Offset(x, base - altura), tallo);
      final hojas = Paint()
        ..color = tono.withValues(alpha: marcas[i] ? .90 : .40);
      final izquierda = Path()
        ..moveTo(x, base - altura * .47)
        ..quadraticBezierTo(x - 17, base - altura * .51,
          x - 13, base - altura * .75)
        ..quadraticBezierTo(x + 1, base - altura * .72,
          x, base - altura * .47);
      canvas.drawPath(izquierda, hojas);
      final derecha = Path()
        ..moveTo(x, base - altura * .64)
        ..quadraticBezierTo(x + 18, base - altura * .72,
          x + 10, base - altura)
        ..quadraticBezierTo(x - 3, base - altura * .90,
          x, base - altura * .64);
      canvas.drawPath(derecha, hojas);
    }
  }

  @override
  bool shouldRepaint(covariant _BrotesHabitosPainter old) =>
      old.marcas != marcas || old.color != color;
}


/// Orbitales musicales detrás del anillo; no representan datos.
class _OrnamentoConciertoPainter extends CustomPainter {
  const _OrnamentoConciertoPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height / 2);
    final contorno = Paint()
      ..color = const Color(0xFFB395F8).withValues(alpha: .18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .9;
    canvas.save();
    canvas.translate(centro.dx, centro.dy);
    canvas.rotate(-.28);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero,
      width: size.width * .97, height: size.height * .39), contorno);
    canvas.rotate(.63);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero,
      width: size.width * .98, height: size.height * .40),
      contorno..color = const Color(0xFF68DFE8).withValues(alpha: .12));
    canvas.restore();
    final puntos = <Offset>[
      Offset(.08, .2), Offset(.91, .28), Offset(.15, .74),
      Offset(.88, .79), Offset(.54, .05),
    ];
    for (final p in puntos) {
      final ubicacion = Offset(p.dx * size.width, p.dy * size.height);
      final tinta = Paint()
        ..color = const Color(0xFFB395F8).withValues(alpha: .55)
        ..strokeWidth = 1;
      canvas.drawLine(ubicacion + const Offset(-3, 0),
        ubicacion + const Offset(3, 0), tinta);
      canvas.drawLine(ubicacion + const Offset(0, -3),
        ubicacion + const Offset(0, 3), tinta);
    }
  }
  @override
  bool shouldRepaint(covariant _OrnamentoConciertoPainter old) => false;
}

/// Brote ilustrativo; el progreso numérico procede de registros de hábitos.
class _PlantaConciertoPainter extends CustomPainter {
  const _PlantaConciertoPainter({required this.progreso});
  final double progreso;
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final base = size.height - 13;
    final suelo = Paint()
      ..color = const Color(0xFF77E5A5).withValues(alpha: .50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawOval(Rect.fromCenter(
      center: Offset(cx, base + 2), width: size.width * .77,
      height: 9), suelo);
    final tallo = Paint()
      ..color = const Color(0xFF80DDA9)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final linea = Path()
      ..moveTo(cx, base)
      ..cubicTo(cx + 4, base - 21, cx - 4, base - 58, cx + 7, 22);
    canvas.drawPath(linea, tallo);
    void hoja(Offset inicio, Offset punta, Offset curva, Color color) {
      final path = Path()
        ..moveTo(inicio.dx, inicio.dy)
        ..quadraticBezierTo(curva.dx, curva.dy, punta.dx, punta.dy)
        ..quadraticBezierTo(
          (punta.dx + inicio.dx) / 2, inicio.dy - 4,
          inicio.dx, inicio.dy);
      canvas.drawPath(path, Paint()
        ..color = color.withValues(alpha: .78 + progreso * .18));
    }
    hoja(Offset(cx, base - 31), Offset(cx - 35, base - 61),
      Offset(cx - 39, base - 28), const Color(0xFF85E6AA));
    hoja(Offset(cx + 4, base - 68), Offset(cx + 41, base - 96),
      Offset(cx + 42, base - 62), const Color(0xFFB1E98D));
    hoja(Offset(cx + 1, base - 21), Offset(cx + 31, base - 44),
      Offset(cx + 33, base - 19), const Color(0xFF5DD89F));
    canvas.drawCircle(Offset(cx, base - 52), 42,
      Paint()..color = const Color(0xFF68DFE8)
        .withValues(alpha: .035 + .035 * progreso)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22));
  }
  @override
  bool shouldRepaint(covariant _PlantaConciertoPainter old) =>
      old.progreso != progreso;
}

/// Vista reducida de los valores reales confirmados de la Rueda.
/// Las dimensiones ausentes no se dibujan como puntuaciones de cero.
class _RadarInicialCompactoPainter extends CustomPainter {
  const _RadarInicialCompactoPainter({
    required this.valores, required this.color,
  });
  final Map<String, int> valores;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) * .42;
    final grilla = Paint()
      ..color = color.withValues(alpha: .24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8;
    final n = pilaresRuedaVida.length;
    for (final escala in [.25, .5, .75, 1.0]) {
      canvas.drawCircle(centro, r * escala, grilla);
    }
    final puntos = <Offset?>[];
    for (var i = 0; i < n; i++) {
      final ang = -math.pi / 2 + math.pi * 2 * i / n;
      final extremo = centro + Offset(
        math.cos(ang) * r, math.sin(ang) * r);
      canvas.drawLine(centro, extremo, grilla);
      final valor = valores[pilaresRuedaVida[i]];
      if (valor == null || valor < 0 || valor > 10) {
        puntos.add(null);
      } else {
        puntos.add(centro + Offset(
          math.cos(ang) * r * valor / 10,
          math.sin(ang) * r * valor / 10));
      }
    }
    final linea = Paint()..color = color
      ..style = PaintingStyle.stroke..strokeWidth = 1.8;
    final punto = Paint()..color = const Color(0xFF9FE7DB);
    for (var i = 0; i < n; i++) {
      final actual = puntos[i];
      if (actual == null) continue;
      canvas.drawCircle(actual, 2.3, punto);
      final proximo = puntos[(i + 1) % n];
      if (proximo != null) {
        canvas.drawLine(actual, proximo, linea);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RadarInicialCompactoPainter old) =>
      old.valores != valores || old.color != color;
}

