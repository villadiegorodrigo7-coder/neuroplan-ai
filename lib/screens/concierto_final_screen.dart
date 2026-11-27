import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/entrada_diario.dart';
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

  Widget _cifraLeyenda(String nombre, int numero, Color color) {
    return Expanded(child: Column(children: [
      Text('$numero',
        style: TextStyle(color: color, fontWeight: FontWeight.w900,
          fontSize: 21)),
      const SizedBox(height: 3),
      Text(nombre, style: const TextStyle(color: _textoTenue, fontSize: 11)),
    ]));
  }

  Widget _anillo(List<Color> colores) {
    final bien = colores.where((c) => c == _verde).length;
    final atencion = colores.where((c) => c == _amarillo).length;
    final desafio = colores.where((c) => c == _rosa).length;
    final porVivir = colores.where((c) => c == _futuro).length;
    final sinRegistro = colores.length - bien - atencion - desafio - porVivir;
    return _superficieCard(child: Column(children: [
      Row(children: [
        const Icon(Icons.album_rounded, color: _lila, size: 18),
        const SizedBox(width: 8),
        const Expanded(child: Text('Los colores de tu ciclo',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
      ]),
      const SizedBox(height: 4),
      LayoutBuilder(builder: (context, medidas) {
        final lado = math.min(276.0, medidas.maxWidth);
        return Center(child: GestureDetector(
          key: const ValueKey('concierto-anillo-interactivo'),
          behavior: HitTestBehavior.opaque,
          onTapDown: (toque) => _tocarAnillo(toque, lado, colores.length),
          child: SizedBox(
            height: lado, width: lado,
            child: Stack(alignment: Alignment.center, children: [
              CustomPaint(size: Size(lado, lado),
                painter: _AnilloConciertoPainter(
                  colores: colores, seleccionado: _diaSeleccionado)),
              Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('TU CICLO', style: TextStyle(color: _lila,
                  letterSpacing: 4, fontSize: 11)),
                const SizedBox(height: 5),
                Text('${_diasVividos}',
                  key: const ValueKey('concierto-dias-vividos'),
                  style: const TextStyle(fontSize: 62, height: 1.1,
                    fontWeight: FontWeight.w300, color: Colors.white)),
                Text('de ${snapshot.ciclo.duracionDias} días',
                  style: const TextStyle(color: _textoTenue, fontSize: 14)),
                const SizedBox(height: 9),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Text('Día ${_diaSeleccionado + 1} · ${_nombre(colores[_diaSeleccionado])}',
                    key: ValueKey(_diaSeleccionado),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11,
                      color: colores[_diaSeleccionado])),
                ),
              ]),
            ]),
          ),
        ));
      }),
      if (snapshot.esVistaPrevia)
        Text('${porVivir} días por vivir',
          style: const TextStyle(color: _textoTenue, fontSize: 12)),
      const SizedBox(height: 15),
      Row(children: [
        _cifraLeyenda('Bien', bien, _verde),
        _cifraLeyenda('Atención', atencion, _amarillo),
        _cifraLeyenda('Desafío', desafio, _rosa),
      ]),
      const SizedBox(height: 15),
      Container(height: 1, color: Colors.white.withValues(alpha: .09)),
      const SizedBox(height: 10),
      Wrap(
        spacing: 16,
        runSpacing: 6,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Text('● ${sinRegistro} sin valoración',
            style: const TextStyle(fontSize: 11, color: _textoTenue)),
          if (snapshot.esVistaPrevia)
            Text('○ ${porVivir} por vivir',
              style: const TextStyle(fontSize: 11, color: _textoTenue)),
        ],
      ),
    ]));
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

  Widget _medidor({
    required String titulo,
    required IconData icono,
    required Color color,
    required double? valor,
    required int registros,
  }) {
    return Expanded(child: Container(
      padding: const EdgeInsets.fromLTRB(9, 15, 9, 14),
      decoration: BoxDecoration(
        color: _superficie,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(children: [
        SizedBox(width: 113, height: 113, child: Stack(
          alignment: Alignment.center, children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: 0, end: ((valor ?? 0) / 5).clamp(0.0, 1.0)),
              duration: MediaQuery.maybeOf(context)?.disableAnimations == true
                  ? Duration.zero : const Duration(milliseconds: 650),
              curve: Curves.easeOutCubic,
              builder: (context, progreso, _) => CustomPaint(
                size: const Size(113, 113),
                painter: _MedidorCircularPainter(
                  progreso: progreso, color: color)),
            ),
            Icon(icono, size: 48, color: color),
          ],
        )),
        const SizedBox(height: 10),
        Text(titulo, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        RichText(text: TextSpan(children: [
          TextSpan(text: valor == null ? '—' : valor.toStringAsFixed(1),
            style: TextStyle(color: color, fontSize: 22,
              fontWeight: FontWeight.w900)),
          const TextSpan(text: ' / 5',
            style: TextStyle(color: _textoTenue, fontSize: 12)),
        ])),
        Text('${registros} días registrados',
          textAlign: TextAlign.center,
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

  Widget _acciones() {
    final cumplidas = snapshot.tareasCompletadas;
    final pendientes = snapshot.tareasPendientesRegistradas;
    final agendaCumplida = snapshot.compromisosCumplidos;
    final sinMarcar = snapshot.compromisosSinMarca;
    final noCumplida = snapshot.compromisosMarcadosNoCumplidos;
    return _superficieCard(color: _turquesa, child: Column(children: [
      Row(children: [
        Container(
          width: 63, height: 63,
          decoration: BoxDecoration(
            color: _verde.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.task_alt_rounded,
            size: 42, color: _verde),
        ),
        const SizedBox(width: 15),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Tareas', style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text('${cumplidas} cumplidas',
              style: const TextStyle(color: _verde, fontSize: 19,
                fontWeight: FontWeight.w900)),
            Text('${pendientes} pendientes registradas',
              style: const TextStyle(color: _textoTenue, fontSize: 11)),
          ],
        )),
      ]),
      const SizedBox(height: 13),
      _progreso(cumplidas, cumplidas + pendientes, _verde),
      const SizedBox(height: 20),
      Container(height: 1, color: Colors.white.withValues(alpha: .10)),
      const SizedBox(height: 18),
      Row(children: [
        Container(
          width: 63, height: 63,
          decoration: BoxDecoration(
            color: _turquesa.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.calendar_month_rounded,
            size: 39, color: _turquesa),
        ),
        const SizedBox(width: 15),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Agenda', style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text('${agendaCumplida} compromisos cumplidos',
              style: const TextStyle(color: _turquesa, fontSize: 15,
                fontWeight: FontWeight.w800)),
            Text('${sinMarcar} sin marcar · ${noCumplida} no cumplidos',
              style: const TextStyle(color: _textoTenue, fontSize: 11)),
          ],
        )),
      ]),
      const SizedBox(height: 13),
      _progreso(agendaCumplida,
        agendaCumplida + sinMarcar + noCumplida, _turquesa),
      const SizedBox(height: 9),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          key: const ValueKey('concierto-toggle-acciones'),
          onPressed: () => setState(() => _mostrarAcciones = !_mostrarAcciones),
          label: Text(_mostrarAcciones ? 'Ocultar registros' : 'Explorar registros'),
          icon: Icon(_mostrarAcciones
              ? Icons.keyboard_arrow_up_rounded
              : Icons.keyboard_arrow_down_rounded),
          style: TextButton.styleFrom(foregroundColor: _turquesa),
        ),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        child: _mostrarAcciones ? _detalleAcciones() : const SizedBox.shrink(),
      ),
    ]));
  }

  Widget _cultivando() {
    final incorporar = snapshot.habitos
        .where((h) => h.tipo == 'incorporar')
        .map((h) => h.realizado).toList();
    final alejar = snapshot.habitos
        .where((h) => h.tipo == 'alejar')
        .map((h) => h.realizado).toList();
    return _superficieCard(child: Row(children: [
      Expanded(child: _habitoIlustrado('Por incorporar', incorporar, _verde)),
      Container(width: 1, height: 150,
        color: Colors.white.withValues(alpha: .10)),
      Expanded(child: _habitoIlustrado('Por alejar', alejar, _lila)),
    ]));
  }

  Widget _habitoIlustrado(String titulo, List<bool> marcas, Color color) {
    final afirmativas = marcas.where((m) => m).length;
    final ultimas = marcas.length > 6
        ? marcas.sublist(marcas.length - 6) : marcas;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Column(children: [
        SizedBox(
          width: double.infinity,
          height: 71,
          child: marcas.isEmpty
              ? Icon(Icons.spa_outlined, size: 50,
                  color: color.withValues(alpha: .45))
              : CustomPaint(
                  painter: _BrotesHabitosPainter(
                    marcas: ultimas, color: color)),
        ),
        const SizedBox(height: 6),
        Text('${afirmativas} / ${marcas.length}', style: TextStyle(
          color: color, fontSize: 22, fontWeight: FontWeight.w900)),
        Text(titulo, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        Text(marcas.length > 6 ? 'Últimas 6 marcas' : 'Marcas afirmativas',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, color: _textoTenue)),
      ]),
    );
  }

  Widget _transformacion() {
    return _superficieCard(child: Column(children: [
      Row(children: [
        Expanded(child: _radarEsquema('Punto de partida', false)),
        const Icon(Icons.arrow_forward_rounded, color: _lila, size: 23),
        Expanded(child: _radarEsquema('Evaluación final', true)),
      ]),
      const SizedBox(height: 6),
      const Text('La comparación estará disponible al evaluar tu ciclo.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: _textoTenue)),
    ]));
  }

  Widget _radarEsquema(String titulo, bool bloqueado) {
    return Column(children: [
      SizedBox(width: 100, height: 100, child: Stack(
        alignment: Alignment.center, children: [
          const CustomPaint(size: Size(98, 98),
            painter: _RadarVacioPainter()),
          Icon(bloqueado ? Icons.lock_outline_rounded
              : Icons.bookmark_border_rounded,
            color: _lila, size: 25),
        ],
      )),
      const SizedBox(height: 8),
      Text(titulo, textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, color: _textoTenue)),
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
        title: const Text('Mi recorrido', style: TextStyle(
          fontWeight: FontWeight.w800, fontSize: 17)),
        backgroundColor: _fondo,
        surfaceTintColor: Colors.transparent,
        actions: [
          Padding(padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text(snapshot.esVistaPrevia
                ? 'Vista previa' : 'Concierto Final',
              style: const TextStyle(color: _lila, fontSize: 12)))),
        ],
      ),
      body: SafeArea(child: ListView(
        padding: const EdgeInsets.fromLTRB(15, 4, 15, 30),
        children: [
          _portada(),
          const SizedBox(height: 22),
          _anillo(colores),
          const SizedBox(height: 7),
          _partitura(colores, diarios),
          InkWell(
            key: const ValueKey('concierto-toggle-ritmo'),
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _mostrarRitmo = !_mostrarRitmo),
            child: Row(children: [
              Expanded(child: _titulo('Cómo te has sentido',
                icono: Icons.favorite_border_rounded)),
              Text(_mostrarRitmo ? 'Ocultar' : 'Ver evolución',
                style: const TextStyle(color: _lila, fontSize: 11)),
              Icon(_mostrarRitmo ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded, color: _lila),
            ]),
          ),
          Row(children: [
            _medidor(titulo: 'Energía', icono: Icons.wb_sunny_outlined,
              color: _turquesa, valor: energia,
              registros: snapshot.diasConEnergia),
            const SizedBox(width: 10),
            _medidor(titulo: 'Estado emocional',
              icono: Icons.favorite_border_rounded,
              color: _lila, valor: estado,
              registros: snapshot.diasConEstado),
          ]),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: _mostrarRitmo
                ? Padding(padding: const EdgeInsets.only(top: 10),
                    child: _tendencias(diarios))
                : const SizedBox.shrink(),
          ),
          _titulo('Tus acciones en movimiento',
            icono: Icons.auto_graph_rounded),
          _acciones(),
          _titulo('Lo que estás cultivando', icono: Icons.spa_outlined),
          _cultivando(),
          _titulo('Tu transformación', icono: Icons.radar_rounded),
          _transformacion(),
          const SizedBox(height: 28),
          if (!snapshot.esVistaPrevia) ...[
            SizedBox(width: double.infinity, child: FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) =>
                  ChatScreen(conciertoFinalSnapshot: snapshot))),
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Reflexionar con Ágora'),
              style: FilledButton.styleFrom(
                backgroundColor: _lila,
                foregroundColor: _fondo,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            )),
            const SizedBox(height: 14),
          ],
          const Center(child: Text('Un paso, un día, un compás.',
            style: TextStyle(color: _lila,
              fontSize: 12, fontStyle: FontStyle.italic))),
        ],
      )),
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
