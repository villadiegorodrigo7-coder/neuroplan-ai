import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/cuadernillo_data.dart';
import '../models/entrada_diario.dart';
import '../services/diario_store.dart';
import '../services/auto_guardado.dart';
import '../services/cuadernillo_service.dart';
import 'mi_diario_card.dart';

const Color kMorado = AppColors.primario;
const Color kFondo = AppColors.fondo;
const Color kTarjeta = AppColors.superficie;
const Color kTextoSecundario = AppColors.textoSecundario;

const List<String> _mesesCorto = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

class Etapa4SeguimientoScreen extends StatefulWidget {
  const Etapa4SeguimientoScreen({super.key});

  @override
  State<Etapa4SeguimientoScreen> createState() => _Etapa4SeguimientoScreenState();
}

class _Etapa4SeguimientoScreenState extends State<Etapa4SeguimientoScreen> {
  bool _cargando = true;
  bool _guardando = false;
  late CuadernilloData _data;
  int _diaSeleccionado = 0;

  final _nuevaTareaController = TextEditingController();
  final _notaController = TextEditingController();

  /// Guardado automático con debounce (ver services/auto_guardado.dart).
  late final AutoGuardado _auto = AutoGuardado(
    obtenerDatos: () => _data,
    sincronizar: _sincronizar,
  );

  @override
  void initState() {
    super.initState();
    DiarioStore.instance.addListener(_alCambiarDiario);
    _cargarDatos();
  }

  /// Mi diario cambió (desde esta pantalla u otra): se repintan los colores.
  void _alCambiarDiario() {
    if (mounted) setState(() {});
  }

  Future<void> _cargarDatos() async {
    final data = await CuadernilloService.cargar();
    try {
      await DiarioStore.instance.cargar();
    } catch (_) {
      // Sin diario cargado, los días salen sin color.
    }

    // Si el ciclo no tiene fecha de inicio, se toma el primer día en que hay
    // algo escrito en Mi diario o, si no hay nada, hoy. Se puede cambiar.
    var guardarInicio = false;
    if (data.seguimiento30Dias.fechaInicio.isEmpty) {
      final fechas = DiarioStore.instance.entradas.map((e) => e.fecha).toList()
        ..sort();
      data.seguimiento30Dias.fechaInicio =
          fechas.isNotEmpty ? fechas.first : EntradaDiario.claveFecha(DateTime.now());
      guardarInicio = true;
    }

    if (!mounted) return;
    setState(() {
      _data = data;
      _cargando = false;
      _notaController.text = _data.seguimiento30Dias.registros[_diaSeleccionado].nota;
    });
    if (guardarInicio) _auto.programar();
  }

  /// Fecha de calendario que corresponde al día [index] (0 a 29) del ciclo.
  DateTime _fechaDelDia(int index) {
    final inicio = DateTime.tryParse(_data.seguimiento30Dias.fechaInicio) ??
        DateTime.now();
    return DateTime(inicio.year, inicio.month, inicio.day + index);
  }

  String _fechaCorta(DateTime d) => '${d.day} de ${_mesesCorto[d.month - 1]}';

  Future<void> _cambiarInicio() async {
    final actual = _fechaDelDia(0);
    final elegida = await showDatePicker(
      context: context,
      initialDate: actual,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      helpText: '¿Qué día empezó tu ciclo?',
    );
    if (elegida == null || !mounted) return;
    setState(() {
      _data.seguimiento30Dias.fechaInicio = EntradaDiario.claveFecha(elegida);
    });
    _auto.programar();
  }

  RegistroDiario get _registroActual => _data.seguimiento30Dias.registros[_diaSeleccionado];

  /// Se ejecuta justo antes de cada escritura: copia la nota del día
  /// visible al modelo. Si el usuario escribió una tarea pero no pulsó +,
  /// se confirma solo al salir o al pasar a segundo plano (nunca mientras
  /// escribe, para no guardar tareas a medias).
  void _sincronizar(MotivoGuardado motivo) {
    _registroActual.nota = _notaController.text;
    if (motivo == MotivoGuardado.debounce) return;
    final texto = _nuevaTareaController.text.trim();
    if (texto.isEmpty) return;
    _registroActual.tareas.add(TareaChecklist(texto: texto));
    _nuevaTareaController.clear();
    // No se puede llamar setState mientras la pantalla se está cerrando.
    if (motivo != MotivoGuardado.cierre && mounted) setState(() {});
  }

  void _cambiarDia(int index) {
    _registroActual.nota = _notaController.text;
    setState(() {
      _diaSeleccionado = index;
      _notaController.text = _registroActual.nota;
    });
    _auto.programar();
  }

  void _agregarTarea() {
    final texto = _nuevaTareaController.text.trim();
    if (texto.isEmpty) return;
    setState(() {
      _registroActual.tareas.add(TareaChecklist(texto: texto));
      _nuevaTareaController.clear();
    });
    _auto.programar();
  }

  void _toggleTarea(int index) {
    setState(() {
      _registroActual.tareas[index].completada = !_registroActual.tareas[index].completada;
    });
    _auto.programar();
  }

  void _eliminarTarea(int index) {
    setState(() => _registroActual.tareas.removeAt(index));
    _auto.programar();
  }

  Future<void> _guardar({bool completar = false}) async {
    if (completar) _data.etapa4Completada = true;
    setState(() => _guardando = true);
    await _auto.guardarAhora(); // copia la nota al modelo y guarda
    if (mounted) setState(() => _guardando = false);
  }

  Future<void> _finalizar() async {
    await _guardar(completar: true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Etapa 4 marcada como completada!'),
          backgroundColor: kMorado,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    // Primero: cancela el timer y guarda lo pendiente (antes de liberar
    // los controllers, porque la sincronización los lee).
    DiarioStore.instance.removeListener(_alCambiarDiario);
    _auto.dispose();
    _nuevaTareaController.dispose();
    _notaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        backgroundColor: kFondo,
        body: Center(child: CircularProgressIndicator(color: kMorado)),
      );
    }

    final registro = _registroActual;

    return Scaffold(
      backgroundColor: kFondo,
      appBar: AppBar(
        backgroundColor: kFondo,
        elevation: 0,
        title: Text('Etapa 4 · Seguimiento',
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Registra tu avance de cada uno de los 30 días.',
                  style: GoogleFonts.inter(color: kTextoSecundario, fontSize: 14),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tu ciclo empezó el ${_fechaCorta(_fechaDelDia(0))}.',
                      style: GoogleFonts.inter(color: kTextoSecundario, fontSize: 12.5),
                    ),
                  ),
                  TextButton(
                    onPressed: _cambiarInicio,
                    child: Text('Cambiar',
                        style: GoogleFonts.inter(color: kMorado, fontSize: 13)),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _data.seguimiento30Dias.registros.length,
                itemBuilder: (context, index) {
                  final activo = index == _diaSeleccionado;
                  final registrado = _data.seguimiento30Dias.registros[index].nivelCumplimiento > 0 ||
                      _data.seguimiento30Dias.registros[index].tareas.isNotEmpty;
                  // Color del semáforo de Mi diario para la fecha de este día.
                  final entradaDia = DiarioStore.instance
                      .de(EntradaDiario.claveFecha(_fechaDelDia(index)));
                  final colorDia =
                      entradaDia == null ? null : colorDeSemaforo(entradaDia.semaforo);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => _cambiarDia(index),
                      child: Container(
                        width: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: activo
                              ? kMorado
                              : (colorDia != null
                                  ? colorDia.withValues(alpha: 0.35)
                                  : kTarjeta),
                          borderRadius: BorderRadius.circular(12),
                          border: colorDia != null
                              ? Border.all(color: colorDia, width: activo ? 2.5 : 1.5)
                              : (registrado && !activo
                                  ? Border.all(color: kMorado, width: 1)
                                  : null),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  Text(
                    'Día ${_diaSeleccionado + 1} · ${_fechaCorta(_fechaDelDia(_diaSeleccionado))}',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  _buildChecklist(registro),
                  const SizedBox(height: 20),
                  // El ánimo y el cumplimiento de antes se reemplazan por Mi
                  // diario: semáforo, energía y estado emocional de este día.
                  MiDiarioCard(
                    key: ValueKey(EntradaDiario.claveFecha(_fechaDelDia(_diaSeleccionado))),
                    fecha: _fechaDelDia(_diaSeleccionado),
                    compacto: true,
                  ),
                  const SizedBox(height: 16),
                  _buildCampoTexto(_notaController, 'Nota del día', '¿Cómo te fue hoy?'),
                ],
              ),
            ),
            _buildBarraInferior(),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklist(RegistroDiario registro) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: kTarjeta, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tareas del día', style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...registro.tareas.asMap().entries.map((entry) {
            final index = entry.key;
            final tarea = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _toggleTarea(index),
                    child: Icon(
                      tarea.completada ? Icons.check_box : Icons.check_box_outline_blank,
                      color: tarea.completada ? kMorado : kTextoSecundario,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tarea.texto,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        decoration: tarea.completada ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _eliminarTarea(index),
                    child: Icon(Icons.close, color: kTextoSecundario, size: 18),
                  ),
                ],
              ),
            );
          }),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nuevaTareaController,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Agregar tarea del día...',
                    hintStyle: GoogleFonts.inter(color: kTextoSecundario, fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onSubmitted: (_) => _agregarTarea(),
                ),
              ),
              GestureDetector(
                onTap: _agregarTarea,
                child: const Icon(Icons.add_circle, color: kMorado, size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(String label, int valor, ValueChanged<int> onChanged,
      {int max = 10, int divisions = 9, String sufijo = ''}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: kTarjeta, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: kMorado, borderRadius: BorderRadius.circular(10)),
                child: Text('$valor$sufijo',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: kMorado,
              inactiveTrackColor: kFondo,
              thumbColor: kMorado,
              overlayColor: kMorado.withOpacity(0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: valor.toDouble(),
              min: 0,
              max: max.toDouble(),
              divisions: divisions,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampoTexto(TextEditingController controller, String label, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: kTarjeta, borderRadius: BorderRadius.circular(16)),
          child: TextField(
            controller: controller,
            maxLines: 3,
            onChanged: (_) => _auto.programar(), // guardado automático
            style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(color: kTextoSecundario, fontSize: 13),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBarraInferior() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(color: kFondo, border: Border(top: BorderSide(color: kTarjeta, width: 1))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _guardando
                  ? null
                  : () async {
                      await _guardar();
                      if (mounted) Navigator.of(context).pop();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: kMorado,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _guardando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Guardar día ${_diaSeleccionado + 1} y salir',
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _guardando ? null : _finalizar,
            child: Text('Marcar Etapa 4 como completada',
                style: GoogleFonts.inter(color: kTextoSecundario, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
