import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/cuadernillo_data.dart';
import '../services/cuadernillo_service.dart';

const Color kMorado = Color(0xFF8C7CFF);
const Color kFondo = Color(0xFF12121E);
const Color kTarjeta = Color(0xFF1C1C2E);
const Color kTextoSecundario = Color(0xFFB0AEC5);

class Etapa2PriorizarScreen extends StatefulWidget {
  const Etapa2PriorizarScreen({super.key});

  @override
  State<Etapa2PriorizarScreen> createState() => _Etapa2PriorizarScreenState();
}

class _Etapa2PriorizarScreenState extends State<Etapa2PriorizarScreen> {
  bool _cargando = true;
  bool _guardando = false;
  late CuadernilloData _data;

  final _controllerUI = TextEditingController();
  final _controllerINU = TextEditingController();
  final _controllerUNI = TextEditingController();
  final _controllerNN = TextEditingController();

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
    });
  }

  Future<void> _guardar({bool completar = false}) async {
    setState(() => _guardando = true);
    if (completar) _data.etapa2Completada = true;
    await CuadernilloService.guardar(_data);
    setState(() => _guardando = false);
  }

  void _agregarTarea(List<String> lista, TextEditingController controller) {
    final texto = controller.text.trim();
    if (texto.isEmpty) return;
    setState(() {
      lista.add(texto);
      controller.clear();
    });
  }

  void _eliminarTarea(List<String> lista, int index) {
    setState(() => lista.removeAt(index));
  }

  Future<void> _finalizar() async {
    await _guardar(completar: true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Etapa 2 completada! Tu progreso fue guardado.'),
          backgroundColor: kMorado,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _controllerUI.dispose();
    _controllerINU.dispose();
    _controllerUNI.dispose();
    _controllerNN.dispose();
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

    final m = _data.matrizEisenhower;

    return Scaffold(
      backgroundColor: kFondo,
      appBar: AppBar(
        backgroundColor: kFondo,
        elevation: 0,
        title: Text(
          'Etapa 2 · Priorizar',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Clasifica tus tareas del mes según su urgencia e importancia.',
                  style: GoogleFonts.inter(color: kTextoSecundario, fontSize: 14),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  _buildCuadrante(
                    titulo: 'Urgente e Importante',
                    subtitulo: 'Hazlo ya',
                    lista: m.urgenteImportante,
                    controller: _controllerUI,
                    color: const Color(0xFFFF6B6B),
                  ),
                  const SizedBox(height: 16),
                  _buildCuadrante(
                    titulo: 'Importante, no Urgente',
                    subtitulo: 'Planifícalo',
                    lista: m.importanteNoUrgente,
                    controller: _controllerINU,
                    color: kMorado,
                  ),
                  const SizedBox(height: 16),
                  _buildCuadrante(
                    titulo: 'Urgente, no Importante',
                    subtitulo: 'Delégalo',
                    lista: m.urgenteNoImportante,
                    controller: _controllerUNI,
                    color: const Color(0xFFFFB74D),
                  ),
                  const SizedBox(height: 16),
                  _buildCuadrante(
                    titulo: 'Ni Urgente ni Importante',
                    subtitulo: 'Elimínalo',
                    lista: m.niUrgenteNiImportante,
                    controller: _controllerNN,
                    color: kTextoSecundario,
                  ),
                ],
              ),
            ),
            _buildBarraInferior(),
          ],
        ),
      ),
    );
  }

  Widget _buildCuadrante({
    required String titulo,
    required String subtitulo,
    required List<String> lista,
    required TextEditingController controller,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kTarjeta,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          Text(
            subtitulo,
            style: GoogleFonts.inter(color: kTextoSecundario, fontSize: 12),
          ),
          const SizedBox(height: 12),
          ...lista.asMap().entries.map((entry) {
            final index = entry.key;
            final texto = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      texto,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _eliminarTarea(lista, index),
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
                  controller: controller,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Agregar tarea...',
                    hintStyle: GoogleFonts.inter(color: kTextoSecundario, fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onSubmitted: (_) => _agregarTarea(lista, controller),
                ),
              ),
              GestureDetector(
                onTap: () => _agregarTarea(lista, controller),
                child: Icon(Icons.add_circle, color: color, size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBarraInferior() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: kFondo,
        border: Border(top: BorderSide(color: kTarjeta, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _guardando
                  ? null
                  : () async {
                      await _guardar();
                      if (mounted) Navigator.of(context).pop();
                    },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: kMorado),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Guardar y salir', style: GoogleFonts.inter(color: kMorado, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _guardando ? null : _finalizar,
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
                  : Text('Finalizar', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
