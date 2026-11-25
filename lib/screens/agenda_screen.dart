import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/agenda_event.dart';
import '../models/entrada_diario.dart';
import '../models/task.dart';
import '../services/agenda_store.dart';
import '../services/tasks_service.dart';
import '../widgets/nuevo_compromiso_dialog.dart';

const _dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const _diasFull = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];
const _meses = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];
const _colores = {
  'urgenteImportante': Color(0xFFFF6B6B),
  'importanteNoUrgente': Color(0xFF8C7CFF),
  'urgenteNoImportante': Color(0xFFFFB74D),
  'niUrgenteNiImportante': Color(0xFFB0AEC5),
};
const _bloques = [
  _Bloque('manana', 'Mañana', 'Antes de las 12 p. m.', Icons.wb_sunny_outlined),
  _Bloque('tarde', 'Tarde', 'De 12 a 6 p. m.', Icons.wb_twilight),
  _Bloque('noche', 'Noche', 'Desde las 6 p. m.', Icons.nights_stay_outlined),
];

class _Bloque {
  final String clave, titulo, rango;
  final IconData icono;
  const _Bloque(this.clave, this.titulo, this.rango, this.icono);
}

DateTime _fecha(DateTime d) => DateTime(d.year, d.month, d.day);
Color _colorTarea(Task t) => _colores[t.cuadrante] ?? const Color(0xFF8D9BC8);

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});
  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  bool _loading = true, _mensual = false;
  final _bloquesAbiertos = <String>{};
  DateTime _seleccion = _fecha(DateTime.now());
  DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month);
  final _tasks = TasksService.instance;

  @override
  void initState() {
    super.initState();
    AgendaStore.instance.addListener(_refresh);
    _tasks.addListener(_refresh);
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      await Future.wait([AgendaStore.instance.cargar(), _tasks.cargar()]);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AgendaStore.instance.removeListener(_refresh);
    _tasks.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _addEvent() async {
    final evento = await showDialog<AgendaEvent>(
      context: context,
      builder: (_) => NuevoCompromisoDialog(fechaInicial: _seleccion),
    );
    if (evento == null || !mounted) return;

    final conflicto = _buscarConflicto(evento);
    if (conflicto != null) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Horario ocupado'),
          content: Text(_mensajeConflicto(evento, conflicto)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    AgendaStore.instance.agregar(evento);
    setState(() {
      _seleccion = _fecha(evento.date);
      _mes = DateTime(evento.date.year, evento.date.month);
    });
  }

  AgendaEvent? _buscarConflicto(AgendaEvent nuevo) {
    for (final actual in AgendaStore.instance.eventos.where(
      (e) => e.id != nuevo.id,
    )) {
      final desde = nuevo.date.isAfter(actual.date) ? nuevo.date : actual.date;
      final inicio = _fecha(desde);
      final dias = nuevo.frecuencia == 'unica'
          ? [_fecha(nuevo.date)]
          : actual.frecuencia == 'unica'
          ? [_fecha(actual.date)]
          : List.generate(7, (i) => inicio.add(Duration(days: i)));
      for (final dia in dias) {
        final inicioNuevo = nuevo.inicioEn(dia);
        final finNuevo = nuevo.finEn(dia);
        final inicioActual = actual.inicioEn(dia);
        final finActual = actual.finEn(dia);
        if (inicioNuevo != null &&
            finNuevo != null &&
            inicioActual != null &&
            finActual != null &&
            inicioNuevo.isBefore(finActual) &&
            inicioActual.isBefore(finNuevo)) {
          return actual;
        }
      }
    }
    return null;
  }

  String _mensajeConflicto(AgendaEvent nuevo, AgendaEvent conflicto) {
    final inicioPedido = nuevo.date;
    final finPedido = nuevo.endDate;
    final inicioOcupado = DateTime(
      inicioPedido.year,
      inicioPedido.month,
      inicioPedido.day,
      conflicto.date.hour,
      conflicto.date.minute,
    );
    final finOcupado = inicioOcupado.add(conflicto.duracion);
    final libreAntes = inicioOcupado.difference(inicioPedido).inMinutes;
    final cruceInicio = inicioPedido.isAfter(inicioOcupado)
        ? inicioPedido
        : inicioOcupado;
    final cruceFin = finPedido.isBefore(finOcupado) ? finPedido : finOcupado;
    final minutosCruce = cruceFin.difference(cruceInicio).inMinutes;
    final detalle = libreAntes > 0
        ? "Puedes utilizar el tramo de ${DateFormat('HH:mm').format(inicioPedido)} a ${DateFormat('HH:mm').format(inicioOcupado)}: son $libreAntes minutos libres. El resto se cruza con el compromiso existente."
        : 'El horario solicitado coincide con un periodo que ya está ocupado.';
    return "Se cruza con \"${conflicto.title}\", de ${DateFormat('HH:mm').format(inicioOcupado)} a ${DateFormat('HH:mm').format(finOcupado)}. $detalle (solapamiento: $minutosCruce minutos).";
  }

  Future<void> _eliminar(AgendaEvent e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar compromiso'),
        content: Text('¿Eliminar "${e.title}" y sus repeticiones?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) AgendaStore.instance.eliminar(e.id);
  }

  void _moverPeriodo(int delta) {
    setState(() {
      if (_mensual) {
        _mes = DateTime(_mes.year, _mes.month + delta);
      } else {
        _seleccion = _seleccion.add(Duration(days: delta * 7));
        _mes = DateTime(_seleccion.year, _seleccion.month);
      }
    });
  }

  List<DateTime> _diasCalendario() {
    if (!_mensual) {
      final lunes = _seleccion.subtract(Duration(days: _seleccion.weekday - 1));
      return List.generate(7, (i) => lunes.add(Duration(days: i)));
    }
    final primero = DateTime(_mes.year, _mes.month, 1);
    final inicio = primero.subtract(Duration(days: primero.weekday - 1));
    final cantidad =
        ((primero.weekday -
                1 +
                DateTime(_mes.year, _mes.month + 1, 0).day +
                6) ~/
            7) *
        7;
    return List.generate(cantidad, (i) => inicio.add(Duration(days: i)));
  }

  Widget _calendario(ColorScheme s) {
    final dias = _diasCalendario();
    final mes = _meses[_mes.month - 1];
    final titulo = '${mes[0].toUpperCase()}${mes.substring(1)} ${_mes.year}';
    final rango = '${_fechaBreve(dias.first)} – ${_fechaBreve(dias.last)}';
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF202B55), Color(0xFF171D3B), Color(0xFF211F49)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFB784FF).withValues(alpha: 0.44),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6255D8).withValues(alpha: 0.10),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Mis compromisos',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              _flechaPeriodo(-1),
              Flexible(child: Text(titulo, textAlign: TextAlign.end)),
              _flechaPeriodo(1),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final d in _dias)
                Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(
                        fontSize: 11,
                        color: s.onSurface.withValues(alpha: .65),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: dias.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 3,
              mainAxisExtent: 38,
            ),
            itemBuilder: (ctx, i) {
              final d = dias[i],
                  sel = _fecha(d) == _seleccion,
                  actual = _fecha(d) == _fecha(DateTime.now());
              final tiene = AgendaStore.instance.eventosEnDia(d).isNotEmpty;
              final delMes = d.month == _mes.month;
              return InkWell(
                borderRadius: BorderRadius.circular(11),
                onTap: () => setState(() {
                  _seleccion = _fecha(d);
                  _mes = DateTime(d.year, d.month);
                }),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: sel
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFA387FF), Color(0xFF6553D2)],
                          )
                        : null,
                    color: sel
                        ? null
                        : Colors.white.withValues(alpha: actual ? 0.08 : 0.035),
                    borderRadius: BorderRadius.circular(11),
                    border: actual && !sel
                        ? Border.all(
                            color: const Color(0xFF55DDF2)
                                .withValues(alpha: 0.75),
                          )
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${d.day}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: sel || actual
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: !delMes && _mensual
                              ? s.onSurface.withValues(alpha: .25)
                              : sel
                              ? s.onPrimaryContainer
                              : s.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: tiene ? s.tertiary : Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  _mensual ? titulo : rango,
                  style: TextStyle(fontSize: 11, color: s.onSurfaceVariant),
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  final hoy = DateTime.now();
                  _seleccion = _fecha(hoy);
                  _mes = DateTime(hoy.year, hoy.month);
                }),
                child: const Text('Hoy'),
              ),
              PopupMenuButton<bool>(
                tooltip: 'Cambiar vista del calendario',
                initialValue: _mensual,
                onSelected: (mensual) => setState(() {
                  _mensual = mensual;
                  _mes = DateTime(_seleccion.year, _seleccion.month);
                }),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: false, child: Text('Semana')),
                  PopupMenuItem(value: true, child: Text('Mes')),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    _mensual ? 'Vista mensual' : 'Vista semanal',
                    style: TextStyle(color: s.primary, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fechaBreve(DateTime fecha) =>
      '${fecha.day} ${_meses[fecha.month - 1].substring(0, 3)}';

  Widget _flechaPeriodo(int delta) => IconButton(
    tooltip: delta < 0 ? 'Período anterior' : 'Período siguiente',
    visualDensity: VisualDensity.compact,
    iconSize: 18,
    onPressed: () => _moverPeriodo(delta),
    icon: Icon(delta < 0 ? Icons.chevron_left : Icons.chevron_right),
  );

  String _bloqueHora(DateTime d) => d.hour < 12
      ? 'manana'
      : d.hour < 18
      ? 'tarde'
      : 'noche';
  Future<void> _agregarTarea(String bloque) async {
    final f = EntradaDiario.claveFecha(_seleccion);
    final pendientes = _tasks.tasks
        .where((t) => !t.done && !(t.fecha == f && t.bloque == bloque))
        .toList();
    final elegida = await showModalBottomSheet<Task>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: pendientes.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No hay tareas pendientes. Agrégalas desde la matriz de Tareas.',
                ),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Selecciona una tarea de la matriz',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  for (final t in pendientes)
                    ListTile(
                      leading: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _colorTarea(t),
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(t.title),
                      subtitle: Text(t.cuadrante ?? 'Sin clasificar'),
                      onTap: () => Navigator.pop(ctx, t),
                    ),
                ],
              ),
      ),
    );
    if (elegida != null) _tasks.llevarAFecha(elegida, f, bloque);
  }

  Color _tonoBloque(String clave) => clave == 'manana'
      ? const Color(0xFFFFC46B)
      : clave == 'tarde'
      ? const Color(0xFF72DDF3)
      : const Color(0xFFB59BFF);

  Widget _jornada(ColorScheme s) {
    final eventos = AgendaStore.instance.eventosEnDia(_seleccion);
    final fecha = EntradaDiario.claveFecha(_seleccion);
    final tareas = _tasks.tasks.where((t) => t.fecha == fecha).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 12, 2, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Tu día',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Flexible(
                flex: 2,
                child: Text(
                  '${_diasFull[_seleccion.weekday - 1]}, ${_seleccion.day} de ${_meses[_seleccion.month - 1]}',
                  textAlign: TextAlign.end,
                  style: TextStyle(fontSize: 12, color: s.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
        for (final b in _bloques)
          _tarjetaJornada(
            b,
            eventos.where((e) => _bloqueHora(e.date) == b.clave).toList(),
            tareas.where((t) => t.bloque == b.clave).toList(),
            s,
          ),
      ],
    );
  }

  Widget _tarjetaJornada(
    _Bloque b,
    List<AgendaEvent> eventos,
    List<Task> tareas,
    ColorScheme s,
  ) {
    final total = eventos.length + tareas.length;
    final realizados =
        eventos.where((e) => e.realizadaEn(_seleccion)).length +
        tareas.where((t) => t.done).length;
    final abierto = _bloquesAbiertos.contains(b.clave);
    final tono = _tonoBloque(b.clave);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF171D39), tono, 0.17)!,
            const Color(0xFF151B36),
          ],
        ),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: tono.withValues(alpha: 0.40)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            onTap: () => setState(() {
              if (abierto) {
                _bloquesAbiertos.remove(b.clave);
              } else {
                _bloquesAbiertos.add(b.clave);
              }
            }),
            leading: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: tono.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(b.icono, color: tono, size: 18),
            ),
            title: Text(
              b.titulo,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.rango),
                Text(
                  total == 0
                      ? 'Espacio disponible'
                      : '$realizados de $total actividades realizadas',
                  style: TextStyle(color: tono, fontSize: 11),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  total == 0 ? '0' : '$realizados/$total',
                  style: TextStyle(color: tono),
                ),
                const SizedBox(width: 6),
                Icon(
                  abierto ? Icons.expand_less : Icons.expand_more,
                  color: tono,
                ),
              ],
            ),
          ),
          if (abierto) ...[
            for (final e in eventos)
              Row(
                children: [
                  GestureDetector(
                    onTap: () => AgendaStore.instance.alternarCumplimiento(
                      e.id,
                      _seleccion,
                    ),
                    child: Icon(
                      e.realizadaEn(_seleccion)
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      color: e.realizadaEn(_seleccion)
                          ? s.primary
                          : s.onSurface.withValues(alpha: .58),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 7),
                  SizedBox(
                    width: 91,
                    child: Text(
                      '${DateFormat('HH:mm').format(e.date)}–${DateFormat('HH:mm').format(e.endDate)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: s.onSurface.withValues(alpha: .65),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      e.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        decoration: e.realizadaEn(_seleccion)
                            ? TextDecoration.lineThrough
                            : null,
                        color: e.realizadaEn(_seleccion)
                            ? s.onSurface.withValues(alpha: .58)
                            : null,
                      ),
                    ),
                  ),
                  if (e.aviso)
                    Icon(
                      Icons.notifications_active,
                      size: 14,
                      color: s.primary,
                    ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () =>
                        _eliminar(AgendaStore.instance.porId(e.id)!),
                    icon: const Icon(Icons.delete_outline, size: 17),
                  ),
                ],
              ),
            for (final t in tareas)
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _colorTarea(t),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _tasks.alternar(t),
                    child: Icon(
                      t.done ? Icons.check_circle : Icons.circle_outlined,
                      color: t.done
                          ? s.primary
                          : s.onSurface.withValues(alpha: .6),
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.title,
                      style: TextStyle(
                        fontSize: 13,
                        decoration: t.done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Quitar de este día',
                    onPressed: () => _tasks.quitarDeHoy(t),
                    icon: const Icon(Icons.close, size: 17),
                  ),
                ],
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _agregarTarea(b.clave),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Agregar tarea de la matriz'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _resumenDia(ColorScheme s) {
    final eventos = AgendaStore.instance.eventosEnDia(_seleccion);
    final fecha = EntradaDiario.claveFecha(_seleccion);
    final tareas = _tasks.tasks.where((t) => t.fecha == fecha).toList();
    final total = eventos.length + tareas.length;
    final realizados =
        eventos.where((e) => e.realizadaEn(_seleccion)).length +
        tareas.where((t) => t.done).length;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(17, 15, 17, 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(21),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF172A49), Color(0xFF17203E), Color(0xFF29204D)],
        ),
        border: Border.all(
          color: const Color(0xFF55DDF2).withValues(alpha: 0.38),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: const Color(0xFF55DDF2).withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.waves_rounded,
                  color: Color(0xFF72E4F2),
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tu ritmo de hoy',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      total == 0
                          ? 'Un espacio abierto para organizar tu tiempo'
                          : '$realizados de $total compromisos y tareas realizados',
                      style: TextStyle(
                        fontSize: 11,
                        color: s.onSurface.withValues(alpha: 0.70),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${total == 0 ? 0 : (realizados * 100 / total).round()}%',
                style: const TextStyle(
                  color: Color(0xFF72E4F2),
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: total == 0 ? 0 : realizados / total,
            minHeight: 4,
            color: const Color(0xFF72E4F2),
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Agenda')),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 18),
              children: [
                const Center(
                  child: Icon(
                    Icons.calendar_month_rounded,
                    color: Color(0xFFC18AFF),
                    size: 26,
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Tu tiempo, a tu ritmo',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 5),
                const Center(
                  child: Text(
                    'Dale espacio a lo que importa',
                    style: TextStyle(fontSize: 12, color: Color(0xFFC4C9E2)),
                  ),
                ),
                const SizedBox(height: 18),
                _resumenDia(s),
                _calendario(s),
                _jornada(s),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _addEvent,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Organizar mi día'),
                  ),
                ),
              ],
            ),
    );
  }
}
