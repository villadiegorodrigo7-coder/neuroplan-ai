import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/agenda_event.dart';
import '../services/agenda_store.dart';

const _dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const _nombresFrecuencia = {
  'unica': 'Una sola vez',
  'diaria': 'Todos los días',
  'semanal': 'Cada semana',
  'personalizada': 'Días seleccionados',
};

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});
  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    AgendaStore.instance.addListener(_alCambiar);
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      await AgendaStore.instance.cargar();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _alCambiar() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AgendaStore.instance.removeListener(_alCambiar);
    super.dispose();
  }

  Future<void> _addEvent() async {
    final title = TextEditingController();
    DateTime dia = DateTime.now();
    TimeOfDay inicio = TimeOfDay.now();
    int duracionMinutos = 60;
    String frecuencia = 'unica';
    bool aviso = true;
    final diasElegidos = <int>{};

    final creado = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Nuevo compromiso'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: title,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Actividad'),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Fecha de inicio'),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(dia)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final p = await showDatePicker(
                      context: ctx, initialDate: dia,
                      firstDate: DateTime(2020), lastDate: DateTime(2100),
                    );
                    if (p != null) setD(() => dia = p);
                  },
                ),
                Row(children: [
                  Expanded(
                    child: _horaTile(
                      ctx, 'Hora para realizarlo', inicio,
                      (v) => setD(() => inicio = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: duracionMinutos,
                      decoration: const InputDecoration(labelText: 'Duración'),
                      items: const [
                        DropdownMenuItem(value: 15, child: Text('15 minutos')),
                        DropdownMenuItem(value: 30, child: Text('30 minutos')),
                        DropdownMenuItem(value: 45, child: Text('45 minutos')),
                        DropdownMenuItem(value: 60, child: Text('1 hora')),
                        DropdownMenuItem(value: 90, child: Text('1 h 30 min')),
                        DropdownMenuItem(value: 120, child: Text('2 horas')),
                        DropdownMenuItem(value: 180, child: Text('3 horas')),
                      ],
                      onChanged: (v) => setD(() => duracionMinutos = v ?? 60),
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(
                  'La Agenda reservará ese intervalo a partir de la hora elegida.',
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.62)),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: frecuencia,
                  decoration: const InputDecoration(labelText: 'Se repite'),
                  items: _nombresFrecuencia.entries.map((e) =>
                    DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                  onChanged: (v) => setD(() { frecuencia = v ?? 'unica'; diasElegidos.clear(); }),
                ),
                if (frecuencia == 'personalizada') ...[
                  const SizedBox(height: 8),
                  const Align(alignment: Alignment.centerLeft, child: Text('Selecciona los días')),
                  Wrap(spacing: 2, children: [
                    for (var i = 0; i < 7; i++)
                      FilterChip(
                        label: Text(_dias[i]),
                        selected: diasElegidos.contains(i + 1),
                        onSelected: (v) => setD(() {
                          if (v) { diasElegidos.add(i + 1); } else { diasElegidos.remove(i + 1); }
                        }),
                      ),
                  ]),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activar aviso'),
                  value: aviso,
                  onChanged: (v) => setD(() => aviso = v),
                ),
                const Text('Los compromisos recurrentes siguen activos hasta que los elimines.',
                  style: TextStyle(fontSize: 12)),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                final s = DateTime(dia.year, dia.month, dia.day, inicio.hour, inicio.minute);
                if (title.text.trim().isEmpty ||
                    (frecuencia == 'personalizada' && diasElegidos.isEmpty)) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );

    if (creado == true && mounted) {
      final s = DateTime(dia.year, dia.month, dia.day, inicio.hour, inicio.minute);
      final e = s.add(Duration(minutes: duracionMinutos));
      final evento = AgendaEvent(
        id: const Uuid().v4(), title: title.text.trim(), date: s, endDate: e,
        aviso: aviso, frecuencia: frecuencia, diasSemana: diasElegidos.toList()..sort(),
      );
      final conflicto = _buscarConflicto(evento);
      if (conflicto != null) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Horario ocupado'),
            content: Text(_mensajeConflicto(evento, conflicto)),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido'))],
          ),
        );
      } else {
        AgendaStore.instance.agregar(evento);
      }
    }
    title.dispose();
  }

  Widget _horaTile(BuildContext ctx, String label, TimeOfDay value, ValueChanged<TimeOfDay> onPick) =>
    InkWell(
      onTap: () async {
        final p = await showTimePicker(context: ctx, initialTime: value);
        if (p != null) onPick(p);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(value.format(ctx)),
      ),
    );

  AgendaEvent? _buscarConflicto(AgendaEvent nuevo) {
    final existentes = AgendaStore.instance.eventos.where((e) => e.id != nuevo.id);
    for (final actual in existentes) {
      late final List<DateTime> diasARevisar;
      if (nuevo.frecuencia == 'unica') {
        diasARevisar = [DateTime(nuevo.date.year, nuevo.date.month, nuevo.date.day)];
      } else if (actual.frecuencia == 'unica') {
        diasARevisar = [DateTime(actual.date.year, actual.date.month, actual.date.day)];
      } else {
        final desde = nuevo.date.isAfter(actual.date) ? nuevo.date : actual.date;
        final primerDia = DateTime(desde.year, desde.month, desde.day);
        // Los patrones de repetición se repiten en un ciclo de siete días.
        diasARevisar = List.generate(7, (i) => primerDia.add(Duration(days: i)));
      }

      for (final dia in diasARevisar) {
        final ni = nuevo.inicioEn(dia);
        final nf = nuevo.finEn(dia);
        final ai = actual.inicioEn(dia);
        final af = actual.finEn(dia);
        if (ni == null || nf == null || ai == null || af == null) continue;
        if (ni.isBefore(af) && ai.isBefore(nf)) return actual;
      }
    }
    return null;
  }

  String _mensajeConflicto(AgendaEvent nuevo, AgendaEvent conflicto) {
    final inicioPedido = nuevo.date;
    final finPedido = nuevo.endDate;
    final inicioOcupado = DateTime(
      inicioPedido.year, inicioPedido.month, inicioPedido.day,
      conflicto.date.hour, conflicto.date.minute,
    );
    final finOcupado = inicioOcupado.add(conflicto.duracion);
    final libreAntes = inicioOcupado.difference(inicioPedido).inMinutes;
    final cruceInicio = inicioPedido.isAfter(inicioOcupado)
        ? inicioPedido
        : inicioOcupado;
    final cruceFin = finPedido.isBefore(finOcupado) ? finPedido : finOcupado;
    final minutosCruce = cruceFin.difference(cruceInicio).inMinutes;

    final detalle = libreAntes > 0
        ? 'Puedes utilizar el tramo de ${DateFormat('HH:mm').format(inicioPedido)} '
          'a ${DateFormat('HH:mm').format(inicioOcupado)}: son $libreAntes minutos libres. '
          'El resto se cruza con el compromiso existente.'
        : 'El horario solicitado coincide con un periodo que ya está ocupado.';
    return 'Se cruza con "${conflicto.title}", de '
        '${DateFormat('HH:mm').format(inicioOcupado)} a '
        '${DateFormat('HH:mm').format(finOcupado)}. '
        '$detalle (solapamiento: $minutosCruce minutos).';
  }

  Future<void> _confirmDeleteEvent(AgendaEvent event) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar compromiso'),
        content: Text('¿Eliminar "${event.title}" y sus repeticiones?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) AgendaStore.instance.eliminar(event.id);
  }

  String _descripcion(AgendaEvent e) {
    final hora = '${DateFormat('HH:mm').format(e.date)}–${DateFormat('HH:mm').format(e.endDate)}';
    final repeticion = _nombresFrecuencia[e.frecuencia] ?? 'Una sola vez';
    final dias = e.frecuencia == 'personalizada'
        ? ' · ${e.diasSemana.map((d) => _dias[d - 1]).join(', ')}'
        : '';
    return '${DateFormat('dd/MM/yyyy').format(e.date)} · $hora · $repeticion$dias';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final events = AgendaStore.instance.eventos;
    return Scaffold(
      appBar: AppBar(title: const Text('Agenda')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addEvent, backgroundColor: scheme.primary, child: const Icon(Icons.add),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : events.isEmpty
          ? Center(child: Text('No tienes compromisos todavía.\nToca + para agregar uno',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.62))))
          : ListView.builder(
              padding: const EdgeInsets.all(16), itemCount: events.length,
              itemBuilder: (ctx, index) {
                final event = events[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: Icon(Icons.event, color: scheme.primary),
                    title: Text(event.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text(_descripcion(event), style: const TextStyle(fontSize: 12)),
                    isThreeLine: true,
                    trailing: IconButton(
                      tooltip: 'Eliminar compromiso y repeticiones',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _confirmDeleteEvent(event),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
