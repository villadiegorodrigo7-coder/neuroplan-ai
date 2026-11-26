import 'package:flutter/material.dart';
import '../models/entrada_diario.dart';
import '../services/concierto_final_service.dart';
import '../widgets/pulso_painter.dart';
import 'chat_screen.dart';

class ConciertoFinalScreen extends StatefulWidget {
  const ConciertoFinalScreen({super.key, required this.snapshot});
  final ConciertoFinalSnapshot snapshot;

  @override
  State<ConciertoFinalScreen> createState() => _ConciertoFinalScreenState();
}

class _ConciertoFinalScreenState extends State<ConciertoFinalScreen> {
  int _diaSeleccionado = 0;
  ConciertoFinalSnapshot get snapshot => widget.snapshot;
  static const oscuro = Color(0xFF0B1023);
  static const violeta = Color(0xFFA98BFF);
  static const celeste = Color(0xFF67E2F0);
  static const gris = Color(0xFF30384D);

  Widget panel(String titulo, IconData icon, Color color, Widget body) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          Color.lerp(oscuro, color, .16)!,
          const Color(0xFF171C37),
        ]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .33)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 25),
          const SizedBox(width: 10),
          Expanded(child: Text(titulo, style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 15),
        body,
      ]),
    );
  }

  Widget numero(String titulo, String valor, Color color, String detalle) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titulo, style: const TextStyle(fontSize: 11,
          color: Color(0xFFBAC3DB))),
        const SizedBox(height: 5),
        Text(valor, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
          color: color)),
        Text(detalle, style: const TextStyle(fontSize: 10,
          color: Color(0xFFBAC3DB))),
      ]),
    ));
  }

  Widget leyenda(String titulo, int total, Color color) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        CircleAvatar(radius: 5, backgroundColor: color),
        const SizedBox(width: 8),
        Expanded(child: Text(titulo, style: const TextStyle(fontSize: 12))),
        Text('$total', style: const TextStyle(fontWeight: FontWeight.bold)),
      ]));
  }

  double? promedio(Iterable<int> datos) {
    final validos = datos.where((n) => n > 0).toList();
    if (validos.isEmpty) return null;
    return validos.reduce((a, b) => a + b) / validos.length;
  }

  Widget _detalleDia(Map<String, EntradaDiario> diario, DateTime inicio,
      List<Color> colores) {
    final fecha = EntradaDiario.claveFecha(DateTime(
      inicio.year, inicio.month, inicio.day + _diaSeleccionado));
    final entrada = diario[fecha];
    final semaforo = entrada?.semaforo ?? '';
    final nombre = semaforo.isEmpty
        ? 'Sin valoración del semáforo'
        : semaforo == 'bien'
            ? 'Bien'
            : semaforo == 'atencion'
                ? 'Atención'
                : (semaforo == 'riesgo' || semaforo == 'desafio')
                    ? 'Desafío'
                    : 'Sin valoración del semáforo';
    final textos = <String>[
      if (entrada != null && entrada.energia > 0)
        'Energía: ${entrada.energia}/5',
      if (entrada != null && entrada.estado > 0)
        'Estado emocional: ${entrada.estado}/5',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Día ${_diaSeleccionado + 1} · $fecha',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Row(children: [
          CircleAvatar(radius: 5, backgroundColor: colores[_diaSeleccionado]),
          const SizedBox(width: 7),
          Text(nombre, style: const TextStyle(fontSize: 12)),
        ]),
        if (textos.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('No hay detalles registrados para este día.',
              style: TextStyle(fontSize: 12, color: Color(0xFFBAC3DB))),
          ),
        for (final texto in textos)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(texto, style: const TextStyle(
              fontSize: 12, height: 1.4, color: Color(0xFFE0E5F7))),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inicio = snapshot.ciclo.inicio!;
    final diario = {for (final e in snapshot.diarios) e.fecha: e};
    final colores = List<Color>.generate(snapshot.ciclo.duracionDias, (i) {
      final fecha = EntradaDiario.claveFecha(
        DateTime(inicio.year, inicio.month, inicio.day + i));
      return colorDeSemaforo(diario[fecha]?.semaforo ?? '') ?? gris;
    });
    final bien = colores.where((c) => c == kColorBien).length;
    final atencion = colores.where((c) => c == kColorAtencion).length;
    final desafio = colores.where((c) => c == kColorDesafio).length;
    final energia = promedio(snapshot.diarios.map((e) => e.energia));
    final emocion = promedio(snapshot.diarios.map((e) => e.estado));
    final incorporar = snapshot.habitos.where((h) => h.tipo == 'incorporar').toList();
    final alejar = snapshot.habitos.where((h) => h.tipo == 'alejar').toList();

    return Scaffold(
      backgroundColor: oscuro,
      appBar: AppBar(title: const Text('Concierto Final'), backgroundColor: oscuro),
      body: SafeArea(child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 26),
        children: [
          const Center(child: Icon(Icons.music_note_rounded,
            size: 35, color: violeta)),
          const SizedBox(height: 8),
          const Center(child: Text('Tu recorrido merece escucharse',
            textAlign: TextAlign.center, style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w800))),
          const SizedBox(height: 7),
          Center(child: Text('${snapshot.ciclo.fechaInicio} — ${EntradaDiario.claveFecha(snapshot.ciclo.fechaFin!)}',
            style: const TextStyle(fontSize: 12, color: Color(0xFFBAC3DB)))),
          const SizedBox(height: 16),
          panel('Los colores de tu ciclo', Icons.donut_large_rounded, violeta,
            Column(children: [
              SizedBox(width: 270, height: 270, child: Stack(
                alignment: Alignment.center, children: [
                  CustomPaint(size: const Size(270, 270),
                    painter: PulsoPainter(colores: colores,
                      seleccionado: -1, base: gris)),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('${snapshot.ciclo.duracionDias}', style: const TextStyle(
                      fontSize: 38, fontWeight: FontWeight.w800)),
                    const Text('días de recorrido', style: TextStyle(fontSize: 11)),
                  ]),
                ])),
              leyenda('Bien', bien, kColorBien),
              leyenda('Atención', atencion, kColorAtencion),
              leyenda('Desafío', desafio, kColorDesafio),
              leyenda('Sin registro', colores.length-bien-atencion-desafio, gris),
              const SizedBox(height: 13),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Explora cada día',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 9),
              Wrap(spacing: 6, runSpacing: 7, children: [
                for (var indice = 0; indice < colores.length; indice++)
                  Tooltip(
                    message: 'Día ${indice + 1}',
                    child: InkWell(
                      key: ValueKey('concierto-dia-${indice + 1}'),
                      onTap: () => setState(() => _diaSeleccionado = indice),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 37, height: 37,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colores[indice].withValues(alpha: .22),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colores[indice],
                            width: indice == _diaSeleccionado ? 2.5 : 1,
                          ),
                        ),
                        child: Text('${indice + 1}',
                          style: TextStyle(fontSize: 12,
                            fontWeight: indice == _diaSeleccionado
                                ? FontWeight.w900 : FontWeight.w500)),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 12),
              _detalleDia(diario, inicio, colores),
              const SizedBox(height: 8),
              Text('${snapshot.diasConPulso} días con indicadores en Mi Pulso',
                style: const TextStyle(fontSize: 12, color: Color(0xFFBAC3DB))),
              const Text('Gris: sin valoración del semáforo, no incumplimiento.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Color(0xFFBAC3DB))),
            ])),
          panel('Energía y estado emocional', Icons.favorite_border, celeste,
            Row(children: [
              numero('Energía media', energia == null ? '—' :
                '${energia.toStringAsFixed(1)} / 5', celeste,
                '${snapshot.diasConEnergia} días registrados'),
              const SizedBox(width: 9),
              numero('Estado medio', emocion == null ? '—' :
                '${emocion.toStringAsFixed(1)} / 5', violeta,
                '${snapshot.diasConEstado} días registrados'),
            ])),
          panel('Tareas', Icons.check_circle_outline,
            const Color(0xFF56DFAE), Row(children: [
              numero('Cumplidas', '${snapshot.tareasCompletadas}',
                const Color(0xFF56DFAE), 'Registros disponibles'),
              const SizedBox(width: 9),
              numero('Pendientes', '${snapshot.tareasPendientesRegistradas}',
                violeta, 'Registros disponibles'),
            ])),
          panel('Agenda', Icons.calendar_month_outlined, celeste,
            Column(children: [
              Row(children: [
                numero('Cumplidos', '${snapshot.compromisosCumplidos}', celeste,
                  'Ocurrencias'),
                const SizedBox(width: 9),
                numero('Sin marcar', '${snapshot.compromisosSinMarca}', violeta,
                  'Sin valoración'),
              ]),
              const SizedBox(height: 8),
              Text('Marcados no cumplidos: ${snapshot.compromisosMarcadosNoCumplidos}',
                style: const TextStyle(fontSize: 12)),
            ])),
          panel('Hábitos', Icons.spa_outlined, violeta,
            Column(children: [
              Row(children: [
                numero('Por incorporar',
                  '${incorporar.where((h) => h.realizado).length} / ${incorporar.length}',
                  const Color(0xFF56DFAE), 'Marcas afirmativas'),
                const SizedBox(width: 9),
                numero('Por alejar',
                  '${alejar.where((h) => h.realizado).length} / ${alejar.length}',
                  violeta, 'Marcas afirmativas'),
              ]),
              const SizedBox(height: 8),
              const Text('Estas cifras indican registros, no califican a la persona.',
                style: TextStyle(fontSize: 11, color: Color(0xFFBAC3DB))),
            ])),
          panel('Rueda de la Vida', Icons.radar_rounded, violeta,
            const Text('La comparación inicial y final se mostrará después de tu evaluación y confirmación. No estimamos cambios sin tus respuestas.',
              style: TextStyle(fontSize: 13, height: 1.5))),
          panel('Ágora y el sentido del recorrido',
            Icons.auto_awesome_rounded, violeta, Column(children: [
              const Text('Estos indicadores describen tus registros. Ágora te ayudará a reflexionar sobre ellos y decidir cuándo cerrar este ciclo.',
                style: TextStyle(fontSize: 13, height: 1.5)),
              const SizedBox(height: 14),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ChatScreen(conciertoFinalSnapshot: snapshot))),
                icon: const Icon(Icons.forum_outlined),
                label: const Text('Reflexionar con Ágora'))),
            ])),
          const SizedBox(height: 10),
          const Center(child: Text('Un paso, un día, un compás.',
            style: TextStyle(color: Color(0xFFBDA8DE),
              fontStyle: FontStyle.italic, fontSize: 12))),
        ],
      )),
    );
  }
}
