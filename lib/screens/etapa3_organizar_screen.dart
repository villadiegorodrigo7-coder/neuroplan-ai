import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/agenda_event.dart';
import '../models/task.dart';
import '../services/agenda_store.dart';
import '../services/tasks_service.dart';
import '../theme/app_theme.dart';

const Color kMorado = AppColors.primario;
const Color kFondo = AppColors.fondo;
const Color kTarjeta = AppColors.superficie;
const Color kTextoSecundario = AppColors.textoSecundario;

class Etapa3OrganizarScreen extends StatefulWidget {
  const Etapa3OrganizarScreen({super.key});

  @override
  State<Etapa3OrganizarScreen> createState() => _Etapa3OrganizarScreenState();
}

class _Etapa3OrganizarScreenState extends State<Etapa3OrganizarScreen> {
  bool _cargando = true;
  late DateTime _lunes;

  static const _dias = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves',
    'Viernes', 'Sábado', 'Domingo',
  ];

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _lunes = DateTime(hoy.year, hoy.month, hoy.day)
        .subtract(Duration(days: hoy.weekday - 1));
    AgendaStore.instance.addListener(_actualizar);
    TasksService.instance.addListener(_actualizar);
    _cargar();
  }

  Future<void> _cargar() async {
    await Future.wait([
      AgendaStore.instance.cargar(),
      TasksService.instance.cargar(),
    ]);
    if (mounted) setState(() => _cargando = false);
  }

  void _actualizar() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AgendaStore.instance.removeListener(_actualizar);
    TasksService.instance.removeListener(_actualizar);
    super.dispose();
  }

  void _semanaAnterior() =>
      setState(() => _lunes = _lunes.subtract(const Duration(days: 7)));

  void _semanaSiguiente() =>
      setState(() => _lunes = _lunes.add(const Duration(days: 7)));

  @override
  Widget build(BuildContext context) {
    final domingo = _lunes.add(const Duration(days: 6));
    final rango = '${DateFormat('dd/MM').format(_lunes)} – '
        '${DateFormat('dd/MM/yyyy').format(domingo)}';

    return Scaffold(
      backgroundColor: kFondo,
      appBar: AppBar(
        backgroundColor: kFondo,
        elevation: 0,
        title: Text(
          'Etapa 3 · Organizar',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: kMorado))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tu semana, organizada',
                        style: GoogleFonts.inter(
                          color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'La Agenda reserva el tiempo. Las Tareas ocupan los espacios disponibles. Los hábitos acompañan todo el proceso.',
                        style: GoogleFonts.inter(color: kTextoSecundario, fontSize: 13, height: 1.45),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _semanaAnterior,
                            icon: const Icon(Icons.chevron_left, color: Colors.white),
                            tooltip: 'Semana anterior',
                          ),
                          Expanded(
                            child: Text(
                              rango,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ),
                          IconButton(
                            onPressed: _semanaSiguiente,
                            icon: const Icon(Icons.chevron_right, color: Colors.white),
                            tooltip: 'Semana siguiente',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: 7,
                    itemBuilder: (context, index) {
                      final dia = _lunes.add(Duration(days: index));
                      return _buildDia(dia, _dias[index]);
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: kMorado,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                'Volver',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDia(DateTime dia, String nombre) {
    final agenda = AgendaStore.instance.eventosEnDia(dia);
    final clave = DateFormat('yyyy-MM-dd').format(dia);
    final tareas = TasksService.instance.tasks
        .where((t) => t.fecha == clave && t.bloque.isNotEmpty)
        .toList()
      ..sort((a, b) => _ordenBloque(a.bloque).compareTo(_ordenBloque(b.bloque)));

    final hoy = DateUtils.isSameDay(dia, DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: kTarjeta,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hoy ? kMorado.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  nombre,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                DateFormat('dd/MM').format(dia),
                style: GoogleFonts.inter(color: kTextoSecundario, fontSize: 12),
              ),
              if (hoy) ...[
                const SizedBox(width: 8),
                const Icon(Icons.circle, color: kMorado, size: 7),
                const SizedBox(width: 4),
                Text('Hoy', style: GoogleFonts.inter(color: kMorado, fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ],
          ),
          const SizedBox(height: 10),
          if (agenda.isEmpty && tareas.isEmpty)
            Text(
              'Sin compromisos ni tareas asignadas.',
              style: GoogleFonts.inter(color: kTextoSecundario, fontSize: 12),
            ),
          for (final evento in agenda) _filaAgenda(evento),
          for (final tarea in tareas) _filaTarea(tarea),
        ],
      ),
    );
  }

  Widget _filaAgenda(AgendaEvent evento) {
    final hora = '${DateFormat('HH:mm').format(evento.date)} – '
        '${DateFormat('HH:mm').format(evento.endDate)}';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.event_available_outlined, color: kMorado, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(evento.title, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                Text(hora, style: GoogleFonts.inter(color: kTextoSecundario, fontSize: 11)),
              ],
            ),
          ),
          Text('Agenda', style: GoogleFonts.inter(color: kMorado, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _filaTarea(Task tarea) {
    final bloque = _nombreBloque(tarea.bloque);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            tarea.done ? Icons.check_circle : Icons.task_alt,
            color: tarea.done ? Colors.greenAccent : Colors.white70,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              tarea.title,
              style: GoogleFonts.inter(
                color: tarea.done ? kTextoSecundario : Colors.white,
                fontSize: 13,
                decoration: tarea.done ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          Text(bloque, style: GoogleFonts.inter(color: kTextoSecundario, fontSize: 10)),
        ],
      ),
    );
  }

  int _ordenBloque(String bloque) {
    switch (bloque) {
      case 'manana': return 0;
      case 'tarde': return 1;
      default: return 2;
    }
  }

  String _nombreBloque(String bloque) {
    switch (bloque) {
      case 'manana': return 'Mañana';
      case 'tarde': return 'Tarde';
      case 'noche': return 'Noche';
      default: return bloque;
    }
  }
}
