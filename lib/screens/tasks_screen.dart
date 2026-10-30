import 'package:flutter/material.dart';

import '../models/agenda_event.dart';
import '../models/cuadernillo_data.dart';
import '../models/entrada_diario.dart';
import '../models/task.dart';
import '../services/agenda_store.dart';
import '../services/cuadernillo_service.dart';
import '../services/tasks_service.dart';

/// Datos de presentación de cada cuadrante (mismos colores que la Etapa 2).
class _Cuadrante {
  final String clave;
  final String titulo;
  final String subtitulo;
  final Color color;
  const _Cuadrante(this.clave, this.titulo, this.subtitulo, this.color);
}

const List<_Cuadrante> _cuadrantes = [
  _Cuadrante('urgenteImportante', 'Urgente e Importante', 'Hazlo ya',
      Color(0xFFFF6B6B)),
  _Cuadrante('importanteNoUrgente', 'Importante, no Urgente', 'Planifícalo',
      Color(0xFF8C7CFF)),
  _Cuadrante('urgenteNoImportante', 'Urgente, no Importante', 'Delégalo',
      Color(0xFFFFB74D)),
  _Cuadrante('niUrgenteNiImportante', 'Ni Urgente ni Importante', 'Elimínalo',
      Color(0xFFB0AEC5)),
];

const List<String> _diasNombre = [
  'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo',
];
const List<String> _mesesAbrev = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

/// Los tres bloques del día, igual que en la Etapa 3 del cuadernillo.
class _Bloque {
  final String clave;
  final String titulo;
  final String rango;
  final IconData icono;
  const _Bloque(this.clave, this.titulo, this.rango, this.icono);
}

const List<_Bloque> _bloques = [
  _Bloque('manana', 'Mañana', 'antes de las 12 p. m.', Icons.wb_sunny_outlined),
  _Bloque('tarde', 'Tarde', 'de 12 a 6 p. m.', Icons.wb_twilight),
  _Bloque('noche', 'Noche', 'desde las 6 p. m.', Icons.nights_stay_outlined),
];

String _tituloBloque(String clave) {
  for (final b in _bloques) {
    if (b.clave == clave) return b.titulo;
  }
  return '';
}

Color _colorDeTarea(Task t) {
  for (final c in _cuadrantes) {
    if (c.clave == t.cuadrante) return c.color;
  }
  return const Color(0xFF8D9BC8);
}

String _etiquetaCuadrante(Task t) {
  for (final c in _cuadrantes) {
    if (c.clave == t.cuadrante) return c.subtitulo;
  }
  return 'Sin clasificar';
}

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  /// Sube cada vez que se entra a la pestaña de Tareas: se vuelve a leer el
  /// cuadernillo para mostrar lo último de las Etapas 2 y 3.
  static final ValueNotifier<int> recargar = ValueNotifier<int>(0);

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final TasksService _service = TasksService.instance;
  // Un campo "Agregar tarea..." por cuadrante.
  final Map<String, TextEditingController> _controllers = {
    for (final c in _cuadrantes) c.clave: TextEditingController(),
  };
  bool _loading = true;
  CuadernilloData? _cuaderno;

  @override
  void initState() {
    super.initState();
    AgendaStore.instance.addListener(_alCambiarAgenda);
    AgendaStore.instance.cargar();
    TasksScreen.recargar.addListener(_sincronizarConCuadernillo);
    _iniciar();
  }

  void _alCambiarAgenda() {
    if (mounted) setState(() {});
  }

  Future<void> _iniciar() async {
    await _service.cargar();
    if (mounted) setState(() => _loading = false);
    await _sincronizarConCuadernillo();
  }

  /// Trae las tareas que el usuario ya tenía en la Matriz de Eisenhower
  /// (Etapa 2) y la rutina de la Etapa 3. Solo si hay Cuadernillo guardado: si
  /// no, una lectura vacía borraría por error las tareas ya sincronizadas.
  Future<void> _sincronizarConCuadernillo() async {
    if (await CuadernilloService.tieneDatosGuardados()) {
      final data = await CuadernilloService.cargar();
      await _service.sincronizarMatriz(data.matrizEisenhower);
      if (mounted) setState(() => _cuaderno = data);
    }
  }

  Future<void> _agregarHabito(String tipo) async {
    final controlador = TextEditingController();
    final nombre = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tipo == 'incorporar' ? 'Hábito por incorporar' : 'Hábito por alejar'),
        content: TextField(
          controller: controlador,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Escribe el comportamiento...'),
          onSubmitted: (_) => Navigator.pop(ctx, controlador.text.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controlador.text.trim()),
            child: const Text('Agregar')),
        ],
      ),
    );
    controlador.dispose();
    if (nombre == null || nombre.trim().isEmpty) return;
    final data = await CuadernilloService.cargar();
    final cantidad = data.habitos.where((h) => h.tipo == tipo).length;
    if (cantidad >= 3) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Puedes llevar hasta tres hábitos en cada categoría.')),
      );
      return;
    }
    data.habitos.add(HabitoSeguimiento(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      nombre: nombre.trim(),
      tipo: tipo,
    ));
    await CuadernilloService.guardar(data);
    if (mounted) setState(() => _cuaderno = data);
  }

  Future<void> _registrarHabito(HabitoSeguimiento habito, bool valor) async {
    final data = await CuadernilloService.cargar();
    final actual = data.habitos.where((h) => h.id == habito.id).toList();
    if (actual.isEmpty) return;
    actual.first.registros[EntradaDiario.claveFecha(DateTime.now())] = valor;
    await CuadernilloService.guardar(data);
    if (mounted) setState(() => _cuaderno = data);
  }

  Widget _buildHabitos(ColorScheme scheme) {
    final habitos = _cuaderno?.habitos ?? [];
    final hoy = EntradaDiario.claveFecha(DateTime.now());
    Widget grupo(String tipo, String titulo, String ayuda) {
      final lista = habitos.where((h) => h.tipo == tipo).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600))),
              TextButton.icon(
                onPressed: lista.length >= 3 ? null : () => _agregarHabito(tipo),
                icon: const Icon(Icons.add, size: 17),
                label: const Text('Agregar'),
              ),
            ],
          ),
          Text(ayuda, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.68))),
          for (final h in lista)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: h.registros[hoy] ?? false,
              onChanged: (v) => _registrarHabito(h, v ?? false),
              title: Text(h.nombre),
              subtitle: Text(h.tipo == 'incorporar' ? 'Lo hice hoy' : 'Hoy logré evitarlo'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          if (lista.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Text('Todavía no agregas hábitos aquí.',
                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.55))),
            ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Seguimiento de hábitos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Un hábito no es una tarea. Observa su evolución sin convertirla en una calificación.',
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
          const SizedBox(height: 12),
          grupo('incorporar', 'Hábitos por incorporar', 'Empieza con uno o dos; máximo tres.'),
          const Divider(height: 22),
          grupo('alejar', 'Hábitos por alejar', 'Elige comportamientos que quieres reducir o dejar; máximo tres.'),
        ],
      ),
    );
  }

  void _addTask(String cuadrante) {
    final controller = _controllers[cuadrante]!;
    _service.agregar(controller.text, cuadrante);
    controller.clear();
  }

  Future<void> _confirmDeleteTask(Task task) async {
    final vieneDeMatriz = task.origen == TasksService.origenMatriz;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar tarea'),
        content: Text(
          vieneDeMatriz
              ? '¿Seguro que quieres eliminar "${task.title}"?\n\n'
                  'Viene de tu Matriz de Eisenhower (Etapa 2), así que '
                  'también se quitará de ahí.'
              : '¿Seguro que quieres eliminar "${task.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _service.eliminar(task);
    }
  }

  @override
  void dispose() {
    AgendaStore.instance.removeListener(_alCambiarAgenda);
    TasksScreen.recargar.removeListener(_sincronizarConCuadernillo);
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Tareas')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListenableBuilder(
              listenable: _service,
              builder: (context, _) {
                final tasks = _service.tasks;
                final pending = tasks.where((t) => !t.done).length;
                final sinClasificar = tasks
                    .where((t) => !TasksService.cuadrantesSincronizados
                        .containsKey(t.cuadrante))
                    .toList();

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '$pending pendientes',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        children: [
                          _buildHabitos(scheme),
                          const SizedBox(height: 18),
                          _buildMiDia(tasks, scheme),
                          const SizedBox(height: 18),
                          for (final c in _cuadrantes) ...[

                            _buildCuadrante(
                              c,
                              tasks.where((t) => t.cuadrante == c.clave).toList(),
                              scheme,
                            ),
                            const SizedBox(height: 14),
                          ],
                          if (sinClasificar.isNotEmpty)
                            _buildSinClasificar(sinClasificar, scheme),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  /// Tarjeta de un cuadrante: igual que en la Etapa 2 (lista + campo con +).
  Widget _buildCuadrante(_Cuadrante c, List<Task> delCuadrante, ColorScheme scheme) {
    // Pendientes primero, completadas al final.
    final ordenadas = [
      ...delCuadrante.where((t) => !t.done),
      ...delCuadrante.where((t) => t.done),
    ];
    final controller = _controllers[c.clave]!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: c.color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c.titulo,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          Text(c.subtitulo,
              style: TextStyle(
                  fontSize: 12, color: Colors.white.withValues(alpha: 0.72))),
          const SizedBox(height: 12),
          for (final task in ordenadas) _buildFila(task, scheme),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Agregar tarea...',
                    hintStyle: TextStyle(
                        fontSize: 13, color: Colors.white.withValues(alpha: 0.62)),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onSubmitted: (_) => _addTask(c.clave),
                ),
              ),
              GestureDetector(
                onTap: () => _addTask(c.clave),
                child: Icon(Icons.add_circle, color: c.color, size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Tareas que no tienen cuadrante (creadas antes de la clasificación).
  Widget _buildSinClasificar(List<Task> tareas, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sin clasificar',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          Text('Toca la etiqueta para elegir su cuadrante',
              style: TextStyle(
                  fontSize: 12, color: Colors.white.withValues(alpha: 0.72))),
          const SizedBox(height: 12),
          for (final task in tareas)
            _buildFila(
              task,
              scheme,
              clasificador: PopupMenuButton<String>(
                tooltip: 'Clasificar',
                icon: Icon(Icons.label_outline,
                    color: scheme.primary.withValues(alpha: 0.9), size: 20),
                onSelected: (clave) => _service.clasificar(task, clave),
                itemBuilder: (context) => [
                  for (final c in _cuadrantes)
                    PopupMenuItem(
                      value: c.clave,
                      child: Text('${c.titulo} · ${c.subtitulo}'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// "Hoy · Tarde", o "Quedó del 26 oct" si era de un día anterior y sigue
  /// pendiente.
  String? _etiquetaDia(Task t) {
    if (t.fecha.isEmpty) return null;
    final hoy = EntradaDiario.claveFecha(DateTime.now());
    if (t.fecha == hoy) return 'Hoy · ${_tituloBloque(t.bloque)}';
    if (t.fecha.compareTo(hoy) < 0 && !t.done) {
      final d = DateTime.tryParse(t.fecha);
      if (d == null) return null;
      return 'Quedó del ${d.day} ${_mesesAbrev[d.month - 1]}';
    }
    return null;
  }

  /// Elige una tarea pendiente y la fecha en la que quiere ubicarla.
  /// El bloque se conserva según el botón + que abrió este selector.
  Future<void> _llevarTarea(_Bloque bloque) async {
    final ahora = DateTime.now();
    final fechaElegida = await showDatePicker(
      context: context,
      initialDate: DateTime(ahora.year, ahora.month, ahora.day),
      firstDate: DateTime(ahora.year, ahora.month, ahora.day),
      lastDate: DateTime(ahora.year + 5, ahora.month, ahora.day),
      helpText: '¿Qué día quieres realizar esta tarea?',
      cancelText: 'Cancelar',
      confirmText: 'Continuar',
    );
    if (fechaElegida == null || !mounted) return;

    final claveFecha = EntradaDiario.claveFecha(fechaElegida);
    final candidatas = _service.tasks
        .where((t) => !t.done && !(t.fecha == claveFecha && t.bloque == bloque.clave))
        .toList();

    final elegida = await showModalBottomSheet<Task>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: candidatas.isEmpty
            ? const Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 28),
                child: Text(
                  'No tienes tareas pendientes para asignar. Crea una en la Matriz de abajo.',
                ),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Text(
                      'Tareas para ${fechaElegida.day}/${fechaElegida.month}/${fechaElegida.year} · ${bloque.titulo}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  for (final t in candidatas)
                    ListTile(
                      leading: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _colorDeTarea(t),
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(t.title),
                      subtitle: Text(
                        t.fecha.isEmpty
                            ? _etiquetaCuadrante(t)
                            : '${_etiquetaCuadrante(t)} · ${t.fecha}',
                      ),
                      onTap: () => Navigator.of(ctx).pop(t),
                    ),
                ],
              ),
      ),
    );
    if (elegida != null) {
      _service.llevarAFecha(elegida, claveFecha, bloque.clave);
    }
  }

  /// El día se compone de compromisos con hora fija y tareas en los espacios disponibles.
  Widget _buildMiDia(List<Task> tasks, ColorScheme scheme) {
    final hoy = DateTime.now();
    final fechaHoy = EntradaDiario.claveFecha(hoy);
    final eventosHoy = AgendaStore.instance.eventosEnDia(hoy)
      ..sort((a, b) => a.date.compareTo(b.date));
    final deHoy = tasks.where((t) => t.fecha == fechaHoy).toList();
    final fechaTexto =
        '${hoy.day.toString().padLeft(2, '0')}/${hoy.month.toString().padLeft(2, '0')}/${hoy.year}';
    final apagado = Colors.white.withValues(alpha: 0.72);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.today_rounded, color: scheme.secondary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Hoy · ${_diasNombre[hoy.weekday - 1]} $fechaTexto',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Tus compromisos reservan el tiempo indicado. Las tareas ocupan los espacios que decidas; el resto queda libre.',
            style: TextStyle(fontSize: 12.5, color: apagado),
          ),
          if (eventosHoy.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('COMPROMISOS DE AGENDA',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: scheme.secondary)),
            for (final e in eventosHoy)
              Padding(
                padding: const EdgeInsets.only(top: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.schedule, size: 16, color: apagado),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 112,
                      child: Text(
                        '${TimeOfDay.fromDateTime(e.date).format(context)}–${TimeOfDay.fromDateTime(e.endDate).format(context)}',
                        style: TextStyle(fontSize: 12, color: apagado),
                      ),
                    ),
                    Expanded(child: Text(e.title, style: const TextStyle(fontSize: 14))),
                    if (e.aviso) Icon(Icons.notifications_active, size: 14, color: scheme.primary),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 14),
          Text('TAREAS DEL DÍA',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: scheme.secondary)),
          const SizedBox(height: 8),
          for (final b in _bloques) ...[
            _buildBloque(b, deHoy.where((t) => t.bloque == b.clave).toList(), scheme),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildBloque(_Bloque b, List<Task> tareas, ColorScheme scheme) {
    final apagado = Colors.white.withValues(alpha: 0.72);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(b.icono, size: 18, color: scheme.secondary),
              const SizedBox(width: 8),
              Text(b.titulo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Expanded(child: Text(b.rango, style: TextStyle(fontSize: 12, color: apagado))),
              TextButton.icon(
                onPressed: () => _llevarTarea(b),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Llevar tarea'),
              ),
            ],
          ),
          for (final t in tareas)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: _colorDeTarea(t), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _service.alternar(t),
                    child: Icon(
                      t.done ? Icons.check_circle : Icons.circle_outlined,
                      size: 20,
                      color: t.done ? scheme.primary : Colors.white.withValues(alpha: 0.62),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.title,
                      style: TextStyle(
                        fontSize: 14,
                        decoration: t.done ? TextDecoration.lineThrough : null,
                        color: t.done ? apagado : Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Quitar de este día',
                    child: InkWell(
                      onTap: () => _service.quitarDeHoy(t),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.close, size: 16, color: apagado),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (tareas.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Espacio disponible para organizar tareas.',
                style: TextStyle(fontSize: 12, color: apagado)),
            ),
        ],
      ),
    );
  }

  /// Una tarea: toca para marcar como hecha, X para eliminar.
  Widget _buildFila(Task task, ColorScheme scheme, {Widget? clasificador}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _service.alternar(task),
            child: Icon(
              task.done ? Icons.check_circle : Icons.circle_outlined,
              color: task.done
                  ? scheme.primary
                  : Colors.white.withValues(alpha: 0.55),
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => _service.alternar(task),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 14,
                      decoration: task.done ? TextDecoration.lineThrough : null,
                      color: task.done
                          ? Colors.white.withValues(alpha: 0.62)
                          : Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  if (_etiquetaDia(task) != null)
                    Text(
                      _etiquetaDia(task)!,
                      style: TextStyle(fontSize: 11.5, color: scheme.secondary),
                    ),
                ],
              ),
            ),
          ),
          if (clasificador != null) clasificador,
          PopupMenuButton<String>(
            tooltip: 'Llevar a hoy',
            icon: Icon(Icons.today_outlined,
                size: 19, color: scheme.secondary.withValues(alpha: 0.9)),
            onSelected: (v) {
              if (v == 'quitar') {
                _service.quitarDeHoy(task);
              } else {
                _service.llevarAHoy(task, v);
              }
            },
            itemBuilder: (context) => [
              for (final b in _bloques)
                PopupMenuItem(
                  value: b.clave,
                  child: Text('Llevar a hoy · ${b.titulo}'),
                ),
              if (task.fecha.isNotEmpty)
                const PopupMenuItem(value: 'quitar', child: Text('Quitar del día')),
            ],
          ),
          GestureDetector(
            onTap: () => _confirmDeleteTask(task),
            child: Icon(Icons.close,
                color: Colors.white.withValues(alpha: 0.62), size: 18),
          ),
        ],
      ),
    );
  }
}
