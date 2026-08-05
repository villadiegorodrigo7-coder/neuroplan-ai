import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/cuadernillo_data.dart';
import '../services/cuadernillo_service.dart';

const Color kMorado = Color(0xFF8C7CFF);
const Color kFondo = Color(0xFF12121E);
const Color kTarjeta = Color(0xFF1C1C2E);
const Color kTextoSecundario = Color(0xFFB0AEC5);

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

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final data = await CuadernilloService.cargar();
    setState(() {
      _data = data;
      _cargando = false;
      _notaController.text = _data.seguimiento30Dias.registros[_diaSeleccionado].nota;
    });
  }

  RegistroDiario get _registroActual => _data.seguimiento30Dias.registros[_diaSeleccionado];

  void _cambiarDia(int index) {
    _registroActual.nota = _notaController.text;
    setState(() {
      _diaSeleccionado = index;
      _notaController.text = _registroActual.nota;
    });
  }

  void _agregarTarea() {
    final texto = _nuevaTareaController.text.trim();
    if (texto.isEmpty) return;
    setState(() {
      _registroActual.tareas.add(TareaChecklist(texto: texto));
      _nuevaTareaController.clear();
    });
  }

  void _toggleTarea(int index) {
    setState(() {
      _registroActual.tareas[index].completada = !_registroActual.tareas[index].completada;
    });
  }

  void _eliminarTarea(int index) {
    setState(() => _registroActual.tareas.removeAt(index));
  }

  Future<void> _guardar({bool completar = false}) async {
    _registroActual.nota = _notaController.text;
    setState(() => _guardando = true);
    if (completar) _data.etapa4Completada = true;
    await CuadernilloService.guardar(_data);
    setState(() => _guardando = false);
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
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => _cambiarDia(index),
                      child: Container(
                        width: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: activo ? kMorado : kTarjeta,
                          borderRadius: BorderRadius.circular(12),
                          border: registrado && !activo ? Border.all(color: kMorado, width: 1) : null,
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
                    'Día ${_diaSeleccionado + 1}',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  _buildChecklist(registro),
                  const SizedBox(height: 20),
                  _buildSlider('Estado de ánimo', registro.estadoAnimo, (v) {
                    setState(() => registro.estadoAnimo = v);
                  }),
                  _buildSlider('Nivel de cumplimiento (%)', registro.nivelCumplimiento, (v) {
                    setState(() => registro.nivelCumplimiento = v);
                  }, max: 100, divisions: 10, sufijo: '%'),
                  const SizedBox(height: 8),
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
