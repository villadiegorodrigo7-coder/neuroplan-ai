import 'package:flutter/material.dart';

import '../models/productividad_data.dart';
import '../models/entrada_diario.dart';
import '../models/task.dart';
import '../services/herramientas_service.dart';
import '../services/actividad_diaria_service.dart';
import '../services/tasks_service.dart';

/// Datos de presentación de cada cuadrante (mismos colores de la matriz).
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


/// Color asociado a la clasificación de la tarea en la matriz.
Color _colorDeTarea(Task t) => _cuadrantes
    .firstWhere((c) => c.clave == t.cuadrante,
        orElse: () => const _Cuadrante('', '', '', Color(0xFF8D9BC8)))
    .color;

String _etiquetaCuadrante(Task t) {
  for (final c in _cuadrantes) {
    if (c.clave == t.cuadrante) return c.subtitulo;
  }
  return 'Sin clasificar';
}

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  /// Sube cada vez que se entra a Tareas para sincronizar la matriz.
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
  HerramientasData? _herramientas;

  @override
  void initState() {
    super.initState();
    TasksScreen.recargar.addListener(_sincronizarConMatriz);
    _iniciar();
  }

  Future<void> _iniciar() async {
    await _service.cargar();
    if (mounted) setState(() => _loading = false);
    await _sincronizarConMatriz();
  }

  /// Sincroniza las tareas existentes de la Matriz de Eisenhower.
  Future<void> _sincronizarConMatriz() async {
    if (await HerramientasService.tieneDatosGuardados()) {
      final data = await HerramientasService.cargar();
      await _service.sincronizarMatriz(data.matrizEisenhower);
      if (mounted) setState(() => _herramientas = data);
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
    final data = await HerramientasService.cargar();
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
    await HerramientasService.guardar(data);
    if (mounted) setState(() => _herramientas = data);
  }

  Future<void> _confirmarEliminarHabito(HabitoSeguimiento habito) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar hábito'),
        content: Text(
          '¿Quieres eliminar "${habito.nombre}"? Su historial quedará '
          'conservado para el indicador de Mi Pulso.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    final data = await HerramientasService.cargar();
    final ahora = DateTime.now();
    final registros = Map<String, bool>.from(habito.registros);
    await ActividadDiariaService.registrar(
      origen: 'habito',
      origenId: habito.id,
      titulo: habito.nombre,
      accion: 'habito_eliminado',
      fecha: ahora,
      detalles: {
        'tipo': habito.tipo,
        'registros': registros,
        'fechas_no_cumplidas': registros.entries
            .where((e) => !e.value)
            .map((e) => e.key)
            .toList(),
      },
    );
    data.habitos.removeWhere((h) => h.id == habito.id);
    await HerramientasService.guardar(data);
    if (mounted) {
      setState(() => _herramientas = data);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hábito eliminado.')),
      );
    }
  }

  Future<void> _registrarHabito(HabitoSeguimiento habito, bool valor) async {
    final data = await HerramientasService.cargar();
    final actual = data.habitos.where((h) => h.id == habito.id).toList();
    if (actual.isEmpty) return;
    final fecha = DateTime.now();
    final clave = EntradaDiario.claveFecha(fecha);
    final estadoAnterior = actual.first.registros[clave] ?? false;
    actual.first.registros[clave] = valor;
    if (valor && !estadoAnterior) {
      await ActividadDiariaService.registrar(
        origen: 'habito',
        origenId: habito.id,
        titulo: habito.nombre,
        accion: 'cumplida',
        fecha: fecha,
        detalles: {'tipo': habito.tipo},
      );
    } else if (!valor && estadoAnterior) {
      await ActividadDiariaService.registrar(
        origen: 'habito',
        origenId: habito.id,
        titulo: habito.nombre,
        accion: 'desmarcada',
        fecha: fecha,
        detalles: {'tipo': habito.tipo},
      );
    }
    await HerramientasService.guardar(data);
    if (mounted) setState(() => _herramientas = data);
  }

  Widget _buildHabitos(ColorScheme scheme) {
    final habitos = _herramientas?.habitos ?? [];
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
              secondary: IconButton(
                tooltip: 'Eliminar hábito',
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => _confirmarEliminarHabito(h),
              ),
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
                  'Viene de tu Matriz de Eisenhower, así que '
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
    TasksScreen.recargar.removeListener(_sincronizarConMatriz);
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
                final hoy = EntradaDiario.claveFecha(DateTime.now());
                // Las completadas se muestran solo el día en que se hicieron.
                // Su registro histórico permanece disponible en Mi Pulso.
                final tasks = _service.tasks
                    .where((t) => !t.done || t.fecha == hoy)
                    .toList();
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

  /// Tarjeta de un cuadrante: con la misma estructura de la matriz (lista + campo con +).
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

  /// Una tarea de la matriz: marcar como realizada, clasificar o eliminar.
  Widget _buildFila(Task task, ColorScheme scheme, {Widget? clasificador}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _service.alternar(task),
            child: Icon(
              task.done ? Icons.check_circle : Icons.circle_outlined,
              color: task.done ? scheme.primary : Colors.white.withValues(alpha: 0.55),
              size: 22,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: _colorDeTarea(task), shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => _service.alternar(task),
              child: Text(
                task.title,
                style: TextStyle(
                  fontSize: 14,
                  decoration: task.done ? TextDecoration.lineThrough : null,
                  color: task.done
                      ? Colors.white.withValues(alpha: 0.62)
                      : Colors.white.withValues(alpha: 0.9),
                ),
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
              for (final bloque in const [
                ('manana', 'Mañana'),
                ('tarde', 'Tarde'),
                ('noche', 'Noche'),
              ])
                PopupMenuItem(
                  value: bloque.$1,
                  child: Text('Llevar a hoy · ${bloque.$2}'),
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
