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
        const Text('Los colores de tu ciclo',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
      ]),
      const SizedBox(height: 4),
      SizedBox(
        height: 276, width: 276,
        child: Stack(alignment: Alignment.center, children: [
          CustomPaint(size: const Size(276, 276),
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
          ]),
        ]),
      ),
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
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('● ${sinRegistro} sin valoración',
          style: const TextStyle(fontSize: 11, color: _textoTenue)),
        if (snapshot.esVistaPrevia)
          Text('○ ${porVivir} por vivir',
            style: const TextStyle(fontSize: 11, color: _textoTenue)),
      ]),
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
                    onTap: disponible
                        ? () => setState(() => _diaSeleccionado = i)
                        : null,
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
      _detalleDia(diarios, colores),
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
            CustomPaint(size: const Size(113, 113),
              painter: _MedidorCircularPainter(
                progreso: ((valor ?? 0) / 5).clamp(0.0, 1.0),
                color: color)),
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
    ]));
  }

  Widget _cultivando() {
    final incorporar = snapshot.habitos.where((h) => h.tipo == 'incorporar');
    final alejar = snapshot.habitos.where((h) => h.tipo == 'alejar');
    final siIncorporar = incorporar.where((h) => h.realizado).length;
    final siAlejar = alejar.where((h) => h.realizado).length;
    return _superficieCard(child: Row(children: [
      Expanded(child: _habitoIlustrado(
        'Por incorporar', siIncorporar, incorporar.length, _verde,
        Icons.spa_rounded)),
      Container(width: 1, height: 137,
        color: Colors.white.withValues(alpha: .10)),
      Expanded(child: _habitoIlustrado(
        'Por alejar', siAlejar, alejar.length, _lila,
        Icons.eco_outlined)),
    ]));
  }

  Widget _habitoIlustrado(String titulo, int si, int total,
      Color color, IconData icono) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(children: [
        Icon(icono, size: 56, color: color),
        const SizedBox(height: 9),
        Text('${si} / ${total}', style: TextStyle(
          color: color, fontSize: 22, fontWeight: FontWeight.w900)),
        Text(titulo, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        const Text('Marcas afirmativas',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: _textoTenue)),
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
          _titulo('Cómo te has sentido', icono: Icons.favorite_border_rounded),
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
