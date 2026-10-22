import 'package:flutter/material.dart';

import '../models/task.dart';
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

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    await _service.cargar();
    if (mounted) setState(() => _loading = false);

    // Trae las tareas que el usuario ya tenía en la Matriz de Eisenhower
    // (Etapa 2). Solo si hay Cuadernillo guardado: si no, una lectura
    // vacía borraría por error las tareas ya sincronizadas.
    if (await CuadernilloService.tieneDatosGuardados()) {
      final data = await CuadernilloService.cargar();
      await _service.sincronizarMatriz(data.matrizEisenhower);
    }
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
                            color: Colors.white.withValues(alpha: 0.5),
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
                  fontSize: 12, color: Colors.white.withValues(alpha: 0.55))),
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
                        fontSize: 13, color: Colors.white.withValues(alpha: 0.4)),
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
                  fontSize: 12, color: Colors.white.withValues(alpha: 0.55))),
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
                  : Colors.white.withValues(alpha: 0.35),
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => _service.alternar(task),
              child: Text(
                task.title,
                style: TextStyle(
                  fontSize: 14,
                  decoration: task.done ? TextDecoration.lineThrough : null,
                  color: task.done
                      ? Colors.white.withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
          if (clasificador != null) clasificador,
          GestureDetector(
            onTap: () => _confirmDeleteTask(task),
            child: Icon(Icons.close,
                color: Colors.white.withValues(alpha: 0.4), size: 18),
          ),
        ],
      ),
    );
  }
}
