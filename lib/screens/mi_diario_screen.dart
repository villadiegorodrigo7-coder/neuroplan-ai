import 'package:flutter/material.dart';

import '../models/entrada_diario.dart';
import '../services/diario_store.dart';

const List<String> _diasSemana = [
  'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo',
];
const List<String> _meses = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/// Mi diario: el mes en colores y el recorrido por los días.
class MiDiarioScreen extends StatefulWidget {
  const MiDiarioScreen({super.key});

  @override
  State<MiDiarioScreen> createState() => _MiDiarioScreenState();
}

class _MiDiarioScreenState extends State<MiDiarioScreen> {
  bool _cargando = true;
  DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month);

  List<EntradaDiario> get _lista => DiarioStore.instance.entradas;

  @override
  void initState() {
    super.initState();
    DiarioStore.instance.addListener(_alCambiar);
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      await DiarioStore.instance.cargar();
    } catch (_) {
      // Se muestra lo que haya en el dispositivo.
    }
    if (mounted) setState(() => _cargando = false);
  }

  void _alCambiar() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    DiarioStore.instance.removeListener(_alCambiar);
    super.dispose();
  }

  void _mover(int delta) {
    setState(() => _mes = DateTime(_mes.year, _mes.month + delta));
  }

  String get _prefijoMes =>
      '${_mes.year.toString().padLeft(4, '0')}-${_mes.month.toString().padLeft(2, '0')}';

  List<EntradaDiario> get _entradasDelMes {
    final lista = _lista.where((e) => e.fecha.startsWith(_prefijoMes)).toList();
    lista.sort((a, b) => b.fecha.compareTo(a.fecha));
    return lista;
  }

  Widget _celda(int dia, EntradaDiario? entrada, bool esHoy, ColorScheme scheme) {
    final color = entrada == null ? null : colorDeSemaforo(entrada.semaforo);
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color != null
            ? color.withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: esHoy ? Border.all(color: scheme.primary, width: 2) : null,
      ),
      child: Text(
        '$dia',
        style: TextStyle(
          fontSize: 13,
          fontWeight: entrada != null ? FontWeight.w700 : FontWeight.w400,
          color: color != null ? Colors.black87 : const Color(0xFFC4C2DA),
        ),
      ),
    );
  }

  Widget _punto(Color color) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  String _titulo(EntradaDiario e) {
    final f = DateTime.tryParse(e.fecha);
    if (f == null) return e.fecha;
    final dia = _diasSemana[f.weekday - 1];
    return '${dia[0].toUpperCase()}${dia.substring(1)} ${f.day}';
  }

  Widget _detalle(EntradaDiario e) {
    final apagado = Colors.white.withValues(alpha: 0.76);
    final lineas = <Widget>[];

    void campo(String nombre, String valor) {
      if (valor.isEmpty) return;
      lineas.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nombre, style: TextStyle(fontSize: 12.5, color: apagado)),
            const SizedBox(height: 2),
            Text(valor),
          ],
        ),
      ));
    }

    campo('Prioridad', e.prioridad);
    if (e.semaforo.isNotEmpty) campo('Semáforo', nombreDeSemaforo(e.semaforo));
    if (e.energia > 0) campo('Energía', kNivelesEnergia[e.energia - 1]);
    if (e.estado > 0) campo('Estado emocional', kNivelesEstado[e.estado - 1]);
    campo('Reflexión', e.reflexion);
    if (e.notas.isNotEmpty) {
      campo('Notas', e.notas.map((n) => '• ${n.texto}').join('\n'));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lineas,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final apagado = Colors.white.withValues(alpha: 0.76);

    return Scaffold(
      appBar: AppBar(title: const Text('Mi diario')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _contenido(scheme, apagado),
    );
  }

  Widget _contenido(ColorScheme scheme, Color apagado) {
    final porFecha = <String, EntradaDiario>{for (final e in _lista) e.fecha: e};
    final hoyClave = EntradaDiario.claveFecha(DateTime.now());
    final primerDia = DateTime(_mes.year, _mes.month, 1);
    final diasDelMes = DateTime(_mes.year, _mes.month + 1, 0).day;
    final huecos = primerDia.weekday - 1;

    final celdas = <Widget>[
      for (var i = 0; i < huecos; i++) const SizedBox.shrink(),
      for (var d = 1; d <= diasDelMes; d++)
        _celda(
          d,
          porFecha[EntradaDiario.claveFecha(DateTime(_mes.year, _mes.month, d))],
          EntradaDiario.claveFecha(DateTime(_mes.year, _mes.month, d)) == hoyClave,
          scheme,
        ),
    ];

    final delMes = _entradasDelMes;
    final bien = delMes.where((e) => e.semaforo == 'bien').length;
    final atencion = delMes.where((e) => e.semaforo == 'atencion').length;
    final riesgo = delMes.where((e) => e.semaforo == 'riesgo').length;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () => _mover(-1),
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Mes anterior',
            ),
            Text(
              '${_meses[_mes.month - 1][0].toUpperCase()}${_meses[_mes.month - 1].substring(1)} ${_mes.year}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            IconButton(
              onPressed: () => _mover(1),
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Mes siguiente',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final d in const ['L', 'M', 'M', 'J', 'V', 'S', 'D'])
              Expanded(
                child: Center(
                  child: Text(d, style: TextStyle(fontSize: 12, color: apagado)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: celdas,
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              _punto(kColorBien),
              const SizedBox(width: 6),
              Text('Bien $bien'),
            ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              _punto(kColorAtencion),
              const SizedBox(width: 6),
              Text('Atención $atencion'),
            ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              _punto(kColorRiesgo),
              const SizedBox(width: 6),
              Text('Riesgo $riesgo'),
            ]),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Un mes con varios amarillos y rojos sigue siendo información útil: te muestra tu patrón real. Un día sin registrar no es un error.',
          style: TextStyle(fontSize: 13, color: apagado),
        ),
        const SizedBox(height: 22),
        if (delMes.isEmpty)
          Text(
            'Todavía no hay días registrados en este mes.',
            style: TextStyle(color: apagado),
          )
        else
          for (final e in delMes)
            ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: _punto(colorDeSemaforo(e.semaforo) ?? Colors.white24),
              title: Text(_titulo(e)),
              subtitle: e.prioridad.isEmpty
                  ? null
                  : Text(e.prioridad, maxLines: 1, overflow: TextOverflow.ellipsis),
              children: [_detalle(e)],
            ),
      ],
    );
  }
}
