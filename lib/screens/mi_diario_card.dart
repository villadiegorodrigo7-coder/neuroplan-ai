import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/agenda_event.dart';
import '../models/entrada_diario.dart';
import '../services/agenda_store.dart';
import '../services/diario_store.dart';
import '../services/recordatorio_diario.dart';
import '../services/reflexion_service.dart';
import '../services/tasks_service.dart';
import '../widgets/campo_dictado.dart';
import 'mi_diario_screen.dart';

const List<String> _diasSemana = [
  'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo',
];
const List<String> _meses = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

String _fechaLarga(DateTime d) {
  final dia = _diasSemana[d.weekday - 1];
  final nombre = '${dia[0].toUpperCase()}${dia.substring(1)}';
  return '$nombre ${d.day} de ${_meses[d.month - 1]}';
}

String _hora(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Tarjeta "Mi diario": lo que se llena cada día.
///
/// Sin parámetros muestra el día de hoy (así se usa en el Perfil). Con [fecha]
/// muestra ese día, y con [compacto] oculta el encabezado, el enlace al mes y
/// los ajustes del recordatorio (así se usa dentro de la Etapa 4).
class MiDiarioCard extends StatefulWidget {
  const MiDiarioCard({super.key, this.fecha, this.compacto = false});

  final DateTime? fecha;
  final bool compacto;

  @override
  State<MiDiarioCard> createState() => _MiDiarioCardState();
}

class _MiDiarioCardState extends State<MiDiarioCard> {
  final TextEditingController _prioridadCtrl = TextEditingController();
  final TextEditingController _reflexionCtrl = TextEditingController();
  final TextEditingController _notaCtrl = TextEditingController();

  late final DateTime _dia;
  late final String _fecha;
  EntradaDiario? _entrada;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    final base = widget.fecha ?? DateTime.now();
    _dia = DateTime(base.year, base.month, base.day);
    _fecha = EntradaDiario.claveFecha(_dia);
    DiarioStore.instance.addListener(_alCambiarStore);
    AgendaStore.instance.addListener(_alCambiarAgenda);
    AgendaStore.instance.cargar();
    _cargar();
  }

  /// La Agenda cambió (por ejemplo, borraste un evento allá): se repinta.
  void _alCambiarAgenda() {
    if (mounted) setState(() {});
  }

  Future<void> _cargar() async {
    try {
      await DiarioStore.instance.cargar();
    } catch (_) {
      // Si algo falla, se empieza con el día en blanco.
    }
    if (!mounted) return;
    final e = DiarioStore.instance.obtenerOCrear(_fecha);
    setState(() {
      _entrada = e;
      _prioridadCtrl.text = e.prioridad;
      _reflexionCtrl.text = e.reflexion;
      _cargando = false;
    });
  }

  /// Otra pantalla pudo cambiar este día (por ejemplo, el chat al guardar una
  /// reflexión). Se refleja aquí sin pisar lo que se esté escribiendo.
  void _alCambiarStore() {
    if (!mounted || _cargando) return;
    final e = DiarioStore.instance.obtenerOCrear(_fecha);
    _entrada = e;
    if (_reflexionCtrl.text.trim() != e.reflexion) _reflexionCtrl.text = e.reflexion;
    if (_prioridadCtrl.text.trim() != e.prioridad) _prioridadCtrl.text = e.prioridad;
    setState(() {});
  }

  void _cambio() {
    final e = _entrada;
    if (e == null) return;
    DiarioStore.instance.cambio(e);
  }

  @override
  void dispose() {
    DiarioStore.instance.removeListener(_alCambiarStore);
    AgendaStore.instance.removeListener(_alCambiarAgenda);
    _prioridadCtrl.dispose();
    _reflexionCtrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Acciones
  // ------------------------------------------------------------------

  void _setSemaforo(String clave) {
    final e = _entrada;
    if (e == null) return;
    e.semaforo = e.semaforo == clave ? '' : clave;
    _cambio();
  }

  void _setEnergia(int nivel) {
    final e = _entrada;
    if (e == null) return;
    e.energia = e.energia == nivel ? 0 : nivel;
    _cambio();
  }

  void _setEstado(int nivel) {
    final e = _entrada;
    if (e == null) return;
    e.estado = e.estado == nivel ? 0 : nivel;
    _cambio();
  }

  void _agregarNota() {
    final e = _entrada;
    final texto = _notaCtrl.text.trim();
    if (e == null || texto.isEmpty) return;
    e.notas.add(NotaDiario(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      texto: texto,
    ));
    _notaCtrl.clear();
    _cambio();
  }

  void _borrarNota(NotaDiario nota) {
    final e = _entrada;
    if (e == null) return;
    // Si la nota tenía recordatorio, se quita también de la Agenda.
    if (nota.agendaId.isNotEmpty) {
      AgendaStore.instance.eliminar(nota.agendaId);
    }
    e.notas.remove(nota);
    _cambio();
  }

  String _cuando(DateTime d) =>
      '${d.day} de ${_meses[d.month - 1]}, ${TimeOfDay.fromDateTime(d).format(context)}';

  /// Programa un recordatorio para la nota: queda como evento de la Agenda
  /// con aviso.
  Future<void> _programarNota(NotaDiario nota) async {
    final ahora = DateTime.now();
    final dia = await showDatePicker(
      context: context,
      initialDate: ahora,
      firstDate: DateTime(ahora.year, ahora.month, ahora.day),
      lastDate: ahora.add(const Duration(days: 365 * 2)),
      helpText: '¿Qué día te lo recuerdo?',
    );
    if (dia == null || !mounted) return;

    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(ahora.add(const Duration(hours: 1))),
      helpText: '¿A qué hora?',
    );
    if (hora == null || !mounted) return;

    final cuando = DateTime(dia.year, dia.month, dia.day, hora.hour, hora.minute);
    if (!cuando.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esa hora ya pasó. Elige una más adelante.')),
      );
      return;
    }

    try {
      await AgendaStore.instance.cargar();
    } catch (_) {}
    final evento = AgendaEvent(
      id: const Uuid().v4(),
      title: nota.texto,
      date: cuando,
      aviso: true,
    );
    AgendaStore.instance.agregar(evento);
    nota.agendaId = evento.id;
    _cambio();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Listo: te lo recuerdo el ${_cuando(cuando)}, cuando tengas la app abierta. También quedó en tu Agenda.',
        ),
      ),
    );
  }

  Future<void> _quitarProgramacion(NotaDiario nota) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitar recordatorio'),
        content: const Text(
          'Se quitará el recordatorio y el evento de la Agenda. La nota se queda en tu diario.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    AgendaStore.instance.eliminar(nota.agendaId);
    nota.agendaId = '';
    _cambio();
  }

  Widget _filaNota(NotaDiario nota, Color apagado, ColorScheme scheme) {
    final evento = nota.agendaId.isEmpty
        ? null
        : AgendaStore.instance.porId(nota.agendaId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_hora(nota.creada),
              style: TextStyle(fontSize: 12.5, color: apagado)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nota.texto),
                if (evento != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Recordatorio: ${_cuando(evento.date)}',
                      style: TextStyle(fontSize: 12, color: scheme.primary),
                    ),
                  ),
              ],
            ),
          ),
          Tooltip(
            message: evento == null
                ? 'Programar un recordatorio'
                : 'Quitar el recordatorio',
            child: InkWell(
              onTap: () => evento == null
                  ? _programarNota(nota)
                  : _quitarProgramacion(nota),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  evento == null
                      ? Icons.notifications_none
                      : Icons.notifications_active,
                  size: 19,
                  color: evento == null ? apagado : scheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () => _borrarNota(nota),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(Icons.close, size: 18, color: apagado),
            ),
          ),
        ],
      ),
    );
  }

  /// Abre el chat con Ágora para hacer la reflexión de este día.
  void _reflexionarConAgora() {
    // Si estamos dentro de otra pantalla (como la Etapa 4), se vuelve al inicio
    // para que se vea el chat.
    Navigator.of(context).popUntil((r) => r.isFirst);
    ReflexionService.instance.solicitar(_fecha);
  }

  Future<void> _elegirTarea() async {
    await TasksService.instance.cargar();
    final pendientes =
        TasksService.instance.tasks.where((t) => !t.done).toList();
    if (!mounted) return;

    final elegida = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: pendientes.isEmpty
            ? const Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 28),
                child: Text(
                  'No tienes tareas pendientes. Puedes escribir tu prioridad en la caja.',
                ),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final t in pendientes)
                    ListTile(
                      title: Text(t.title),
                      onTap: () => Navigator.of(ctx).pop(t.title),
                    ),
                ],
              ),
      ),
    );

    final e = _entrada;
    if (elegida != null && e != null) {
      _prioridadCtrl.text = elegida;
      e.prioridad = elegida;
      _cambio();
    }
  }

  // ------------------------------------------------------------------
  // Piezas de la pantalla
  // ------------------------------------------------------------------

  Widget _titulo(String texto) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(
          texto,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      );

  Widget _botonSemaforo(int i, EntradaDiario e) {
    final clave = kSemaforos[i];
    final color = colorDeSemaforo(clave) ?? Colors.grey;
    final seleccionado = e.semaforo == clave;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _setSemaforo(clave),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: seleccionado ? color.withValues(alpha: 0.22) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: seleccionado ? color : Colors.white.withValues(alpha: 0.15),
            width: seleccionado ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(height: 6),
            Text(
              kNombresSemaforo[i],
              style: TextStyle(
                fontSize: 13,
                fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _barraEnergia(EntradaDiario e, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(5, (i) {
            final lleno = i < e.energia;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < 4 ? 6 : 0),
                child: GestureDetector(
                  onTap: () => _setEnergia(i + 1),
                  child: Container(
                    height: 30,
                    decoration: BoxDecoration(
                      color: lleno ? scheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: lleno
                            ? scheme.primary
                            : Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        if (e.energia > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              kNivelesEnergia[e.energia - 1],
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final apagado = Colors.white.withValues(alpha: 0.6);
    final e = _entrada;

    if (_cargando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (e == null) return const SizedBox.shrink();

    // Un día que todavía no llega no se puede llenar.
    if (_fecha.compareTo(EntradaDiario.claveFecha(DateTime.now())) > 0) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text('Este día todavía no llega.', style: TextStyle(color: apagado)),
      );
    }

    final indiceSemaforo = kSemaforos.indexOf(e.semaforo);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.compacto) ...[
            Row(
              children: [
                Icon(Icons.menu_book_rounded, color: scheme.primary, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Mi diario',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(_fechaLarga(_dia), style: TextStyle(color: apagado)),
          ] else
            Text(_fechaLarga(_dia), style: TextStyle(color: apagado)),

          _titulo('Mi prioridad del día'),
          CampoDictado(
            controller: _prioridadCtrl,
            hint: '¿Qué es lo más importante?',
            maxLines: 2,
            onChanged: (v) {
              e.prioridad = v.trim();
              _cambio();
            },
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _elegirTarea,
              icon: const Icon(Icons.checklist_rounded, size: 18),
              label: const Text('Elegir de mis tareas'),
            ),
          ),

          _titulo('¿Cómo te fue con tu ritmo?'),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                Expanded(child: _botonSemaforo(i, e)),
                if (i < 2) const SizedBox(width: 8),
              ],
            ],
          ),
          if (indiceSemaforo >= 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                kDefinicionesSemaforo[indiceSemaforo],
                style: TextStyle(fontSize: 12.5, color: apagado),
              ),
            ),

          _titulo('Energía'),
          _barraEnergia(e, scheme),

          _titulo('Estado emocional'),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (var i = 0; i < 5; i++)
                ChoiceChip(
                  label: Text(kNivelesEstado[i]),
                  selected: e.estado == i + 1,
                  onSelected: (_) => _setEstado(i + 1),
                ),
            ],
          ),

          _titulo('Reflexión del día'),
          CampoDictado(
            controller: _reflexionCtrl,
            hint: '¿Por qué crees que el día salió así?',
            minLines: 2,
            maxLines: 6,
            onChanged: (v) {
              e.reflexion = v.trim();
              _cambio();
            },
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _reflexionarConAgora,
              icon: const Icon(Icons.record_voice_over_outlined, size: 18),
              label: const Text('Reflexionar con Ágora'),
            ),
          ),

          _titulo('Notas'),
          for (final nota in e.notas) _filaNota(nota, apagado, scheme),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: CampoDictado(
                  controller: _notaCtrl,
                  hint: 'Una nota rápida...',
                  maxLines: 1,
                  onSubmitted: _agregarNota,
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                tooltip: 'Agregar nota',
                onPressed: _agregarNota,
                icon: const Icon(Icons.add),
              ),
            ],
          ),

          if (!widget.compacto) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MiDiarioScreen()),
                  );
                },
                icon: const Icon(Icons.calendar_month_rounded, size: 18),
                label: const Text('Ver mi mes y mis notas'),
              ),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            ListenableBuilder(
              listenable: RecordatorioDiario.instance,
              builder: (context, _) {
                final r = RecordatorioDiario.instance;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Recordarme llenar mi diario'),
                      subtitle: Text(
                        r.activo
                            ? 'Te invito a las ${r.hora.format(context)}, cuando tengas la app abierta.'
                            : 'Sin recordatorio. Un día sin registrar no es un error.',
                        style: TextStyle(fontSize: 12.5, color: apagado),
                      ),
                      value: r.activo,
                      onChanged: (v) => r.activar(v),
                    ),
                    if (r.activo)
                      TextButton.icon(
                        onPressed: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: r.hora,
                            helpText: 'Hora del recordatorio',
                          );
                          if (t != null) r.cambiarHora(t);
                        },
                        icon: const Icon(Icons.schedule, size: 18),
                        label: const Text('Cambiar hora'),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
