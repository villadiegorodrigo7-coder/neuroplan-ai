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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Puedes llevar hasta tres hábitos en cada categoría.'),
          ),
        );
      }
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

    Widget grupo(String tipo, String titulo, Color color, IconData icono) {
      final lista = habitos.where((h) => h.tipo == tipo).toList();
      final hechos = lista.where((h) => h.registros[hoy] == true).length;
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            Color.lerp(const Color(0xFF151A35), color, 0.22)!,
            const Color(0xFF151A35),
          ]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.55)),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.13),
            blurRadius: 22, offset: const Offset(0, 6))],
        ),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          key: PageStorageKey('habitos_$tipo'),
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          collapsedIconColor: color,
          iconColor: color,
          leading: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.27),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.30),
                blurRadius: 15, spreadRadius: 1)]),
            child: Icon(icono, color: color, size: 24),
          ),
          title: Text(titulo, style: const TextStyle(
            fontWeight: FontWeight.w800, fontSize: 12.5)),
          subtitle: Text(tipo == 'incorporar'
              ? '${lista.length} hábitos activos'
              : '${lista.length} hábitos en proceso',
            style: const TextStyle(color: Color(0xFFC1C8E1), fontSize: 11)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('$hechos/${lista.length}', style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(width: 6),
            Icon(Icons.keyboard_arrow_down_rounded, color: color),
          ]),
          children: [
            for (final h in lista)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: h.registros[hoy] ?? false,
                onChanged: (v) => _registrarHabito(h, v ?? false),
                title: Text(h.nombre, style: const TextStyle(fontSize: 13)),
                subtitle: Text(tipo == 'incorporar'
                    ? 'Lo hice hoy' : 'Hoy logré evitarlo',
                    style: const TextStyle(fontSize: 11)),
                controlAffinity: ListTileControlAffinity.leading,
                secondary: IconButton(
                  tooltip: 'Eliminar hábito',
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFFF7891)),
                  onPressed: () => _confirmarEliminarHabito(h),
                ),
              ),
            if (lista.isEmpty)
              const Padding(
                padding: EdgeInsets.all(10),
                child: Text('Todavía no hay hábitos aquí.',
                  style: TextStyle(color: Color(0xFFC1C8E1), fontSize: 12)),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: lista.length >= 3 ? null : () => _agregarHabito(tipo),
                icon: const Icon(Icons.add_rounded, size: 17),
                label: const Text('Agregar hábito'),
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      final incorporar = grupo('incorporar', 'Seguimiento de hábitos',
          const Color(0xFF54F0AF), Icons.spa_rounded);
      final alejar = grupo('alejar', 'Hábitos por alejar',
          const Color(0xFFD08BFF), Icons.track_changes_rounded);
      if (constraints.maxWidth < 510) {
        return Column(children: [incorporar, alejar]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: incorporar),
        const SizedBox(width: 12),
        Expanded(child: alejar),
      ]);
    });
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
                final tasks = _service.tasks
                    .where((t) => !t.done || t.fecha == hoy)
                    .toList();
                final pending = tasks.where((t) => !t.done).length;
                final sinClasificar = tasks
                    .where((t) => !TasksService.cuadrantesSincronizados
                        .containsKey(t.cuadrante)).toList();
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                  children: [
                    const SizedBox(height: 6),
                    Center(child: Container(
                      width: 55, height: 55,
                      decoration: BoxDecoration(
                        color: const Color(0xFF9C43E6).withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFD276FF).withValues(alpha: 0.72)),
                        boxShadow: [BoxShadow(color: const Color(0xFFC65CFF).withValues(alpha: 0.33),
                          blurRadius: 24, spreadRadius: 2)]),
                      child: const Icon(Icons.check_circle_rounded,
                        color: Color(0xFFDF9EFF), size: 32))),
                    const SizedBox(height: 9),
                    const Center(child: Text('Tu espacio de acción',
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800))),
                    const SizedBox(height: 5),
                    const Center(child: Text('Prioriza, organiza y avanza a tu ritmo',
                      style: TextStyle(fontSize: 12, color: Color(0xFFC1C8E1)))),
                    const SizedBox(height: 19),
                    _buildResumen(tasks, pending),
                    const SizedBox(height: 15),
                    _buildHabitos(scheme),
                    const SizedBox(height: 6),
                    LayoutBuilder(builder: (context, constraints) {
                      return GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        mainAxisExtent: constraints.maxWidth < 370 ? 139 : 130,
                        children: [
                          for (final c in _cuadrantes)
                            _buildCuadranteTarjeta(
                              c,
                              tasks.where((t) => t.cuadrante == c.clave).toList(),
                              scheme,
                            ),
                        ],
                      );
                    }),
                    if (sinClasificar.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _buildSinClasificarResumido(sinClasificar, scheme),
                    ],
                    const SizedBox(height: 20),
                    const Center(child: Text('Un paso, un día, un compás.',
                      style: TextStyle(fontSize: 11, color: Color(0xFFB9A4DF)))),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildCuadranteTarjeta(
      _Cuadrante c, List<Task> tareas, ColorScheme scheme) {
    final icono = c.clave == 'urgenteImportante'
        ? Icons.bolt_rounded
        : c.clave == 'importanteNoUrgente'
            ? Icons.flag_rounded
            : c.clave == 'urgenteNoImportante'
                ? Icons.hourglass_bottom_rounded
                : Icons.nights_stay_rounded;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _abrirCuadrante(c, scheme),
        child: Ink(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Color.lerp(const Color(0xFF151A35), c.color, 0.26)!,
              const Color(0xFF171B37),
            ]),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.color.withValues(alpha: 0.72)),
            boxShadow: [BoxShadow(color: c.color.withValues(alpha: 0.14),
              blurRadius: 18, offset: const Offset(0, 5))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: c.color.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: c.color.withValues(alpha: 0.28),
                    blurRadius: 13, spreadRadius: 1)]),
                child: Icon(icono, color: c.color, size: 23)),
              const SizedBox(height: 7),
              Expanded(child: Text(c.titulo, maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
              Row(children: [
                Expanded(child: Text(
                  '${tareas.length} ${tareas.length == 1 ? "tarea" : "tareas"}',
                  style: TextStyle(fontSize: 11, color: c.color,
                    fontWeight: FontWeight.w700))),
                Icon(Icons.keyboard_arrow_down_rounded, color: c.color, size: 18),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _abrirCuadrante(_Cuadrante c, ColorScheme scheme) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF10162C),
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.73,
        child: ListenableBuilder(
          listenable: _service,
          builder: (context, _) {
            final hoy = EntradaDiario.claveFecha(DateTime.now());
            final tareas = _service.tasks.where((t) =>
              t.cuadrante == c.clave && (!t.done || t.fecha == hoy)).toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
              children: [
                Center(child: Container(width: 42, height: 4,
                  decoration: BoxDecoration(color: Colors.white24,
                    borderRadius: BorderRadius.circular(4)))),
                const SizedBox(height: 17),
                _buildCuadrante(c, tareas, scheme),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSinClasificarResumido(List<Task> tareas, ColorScheme scheme) =>
      ExpansionTile(
        initiallyExpanded: false,
        collapsedIconColor: scheme.primary,
        title: const Text('Sin clasificar',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        subtitle: Text('${tareas.length} tareas pendientes de clasificación',
          style: const TextStyle(fontSize: 11)),
        children: [_buildSinClasificar(tareas, scheme)],
      );

  Widget _buildResumen(List<Task> tasks, int pendientes) {
    final completadas = tasks.where((t) => t.done).length;
    final total = tasks.length;
    final progreso = total == 0 ? 0.0 : completadas / total;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF202B55), Color(0xFF171D3B), Color(0xFF25204D)],
        ),
        border: Border.all(color: const Color(0xFF8C7CFF).withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6657D9).withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFB969F8).withValues(alpha: 0.30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.track_changes_rounded,
                    color: Color(0xFFECADFF), size: 23),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tu espacio de acción',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    SizedBox(height: 2),
                    Text('Prioriza con intención, avanza a tu ritmo',
                        style: TextStyle(fontSize: 11, color: Color(0xFFB9C4E5))),
                  ],
                ),
              ),
              Text('$pendientes pendientes',
                  style: const TextStyle(
                    color: Color(0xFFB9AEFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ),
          const SizedBox(height: 17),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progreso,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.10),
              valueColor: const AlwaysStoppedAnimation(Color(0xFFB969F8)),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Text('$completadas completadas',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF9FEAF4))),
              const Spacer(),
              Text('$total en total',
                  style: const TextStyle(fontSize: 11, color: Color(0xFFB9C4E5))),
            ],
          ),
        ],
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(scheme.surfaceContainerHighest, c.color, 0.10)!,
            scheme.surfaceContainerHighest,
          ],
        ),
        borderRadius: BorderRadius.circular(19),
        border: Border(
          left: BorderSide(color: c.color, width: 4),
          top: BorderSide(color: c.color.withValues(alpha: 0.20)),
          right: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        boxShadow: [
          BoxShadow(color: c.color.withValues(alpha: 0.07), blurRadius: 16, offset: const Offset(0, 6)),
        ],
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
