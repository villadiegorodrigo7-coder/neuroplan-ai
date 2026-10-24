import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/entrada_diario.dart';
import '../services/diario_service.dart';
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

/// Tarjeta "Mi diario" del Perfil: lo que se llena cada día.
class MiDiarioCard extends StatefulWidget {
  const MiDiarioCard({super.key});

  @override
  State<MiDiarioCard> createState() => _MiDiarioCardState();
}

class _MiDiarioCardState extends State<MiDiarioCard> {
  final TextEditingController _prioridadCtrl = TextEditingController();
  final TextEditingController _reflexionCtrl = TextEditingController();
  final TextEditingController _notaCtrl = TextEditingController();

  List<EntradaDiario> _lista = [];
  EntradaDiario? _hoy;
  Timer? _debounce;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (uid.isEmpty) {
      if (mounted) setState(() => _cargando = false);
      return;
    }

    final fecha = EntradaDiario.claveFecha(DateTime.now());
    final id = EntradaDiario.idPara(uid, fecha);

    var lista = <EntradaDiario>[];
    try {
      lista = List<EntradaDiario>.of(await DiarioService.cargar());
    } catch (_) {
      // Si algo falla, se empieza con el día en blanco.
    }
    if (!mounted) return;

    final existentes = lista.where((e) => e.id == id);
    final hoy = existentes.isNotEmpty
        ? existentes.first
        : EntradaDiario(id: id, fecha: fecha);

    setState(() {
      _lista = lista;
      _hoy = hoy;
      _prioridadCtrl.text = hoy.prioridad;
      _reflexionCtrl.text = hoy.reflexion;
      _cargando = false;
    });
  }

  /// Se llama después de cualquier cambio: actualiza la lista y programa el
  /// guardado (queda en el dispositivo y se sube a la nube en segundo plano).
  void _cambio() {
    final hoy = _hoy;
    if (hoy == null) return;
    if (!hoy.tieneAlgo) {
      _lista.remove(hoy);
    } else if (!_lista.contains(hoy)) {
      _lista.add(hoy);
    }
    if (mounted) setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), _guardarYa);
  }

  Future<void> _guardarYa() async {
    _debounce?.cancel();
    _debounce = null;
    try {
      await DiarioService.guardar(List<EntradaDiario>.of(_lista));
    } catch (_) {
      // Queda guardado en el dispositivo; se reintenta más tarde.
    }
  }

  @override
  void dispose() {
    if (_debounce?.isActive ?? false) {
      _guardarYa();
    }
    _debounce?.cancel();
    _prioridadCtrl.dispose();
    _reflexionCtrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Acciones
  // ------------------------------------------------------------------

  void _setSemaforo(String clave) {
    final hoy = _hoy;
    if (hoy == null) return;
    hoy.semaforo = hoy.semaforo == clave ? '' : clave;
    _cambio();
  }

  void _setEnergia(int nivel) {
    final hoy = _hoy;
    if (hoy == null) return;
    hoy.energia = hoy.energia == nivel ? 0 : nivel;
    _cambio();
  }

  void _setEstado(int nivel) {
    final hoy = _hoy;
    if (hoy == null) return;
    hoy.estado = hoy.estado == nivel ? 0 : nivel;
    _cambio();
  }

  void _agregarNota() {
    final hoy = _hoy;
    final texto = _notaCtrl.text.trim();
    if (hoy == null || texto.isEmpty) return;
    hoy.notas.add(NotaDiario(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      texto: texto,
    ));
    _notaCtrl.clear();
    _cambio();
  }

  void _borrarNota(NotaDiario nota) {
    final hoy = _hoy;
    if (hoy == null) return;
    hoy.notas.remove(nota);
    _cambio();
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

    final hoy = _hoy;
    if (elegida != null && hoy != null) {
      _prioridadCtrl.text = elegida;
      hoy.prioridad = elegida;
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

  Widget _botonSemaforo(int i, EntradaDiario hoy) {
    final clave = kSemaforos[i];
    final color = colorDeSemaforo(clave) ?? Colors.grey;
    final seleccionado = hoy.semaforo == clave;
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

  Widget _barraEnergia(EntradaDiario hoy, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(5, (i) {
            final lleno = i < hoy.energia;
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
        if (hoy.energia > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              kNivelesEnergia[hoy.energia - 1],
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
    final hoy = _hoy;

    if (_cargando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (hoy == null) return const SizedBox.shrink();

    final indiceSemaforo = kSemaforos.indexOf(hoy.semaforo);

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
          Text(_fechaLarga(DateTime.now()), style: TextStyle(color: apagado)),

          _titulo('Mi prioridad de hoy'),
          CampoDictado(
            controller: _prioridadCtrl,
            hint: '¿Qué es lo más importante hoy?',
            maxLines: 2,
            onChanged: (v) {
              hoy.prioridad = v.trim();
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

          _titulo('¿Cómo te fue hoy con tu ritmo?'),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                Expanded(child: _botonSemaforo(i, hoy)),
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
          _barraEnergia(hoy, scheme),

          _titulo('Estado emocional'),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (var i = 0; i < 5; i++)
                ChoiceChip(
                  label: Text(kNivelesEstado[i]),
                  selected: hoy.estado == i + 1,
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
              hoy.reflexion = v.trim();
              _cambio();
            },
          ),

          _titulo('Notas de hoy'),
          for (final nota in hoy.notas)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_hora(nota.creada),
                      style: TextStyle(fontSize: 12.5, color: apagado)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(nota.texto)),
                  InkWell(
                    onTap: () => _borrarNota(nota),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(Icons.close, size: 18, color: apagado),
                    ),
                  ),
                ],
              ),
            ),
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
        ],
      ),
    );
  }
}
