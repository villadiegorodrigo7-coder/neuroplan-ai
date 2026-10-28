import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/cuadernillo_data.dart';
import '../services/auto_guardado.dart';
import '../services/cuadernillo_service.dart';

const Color kMorado = AppColors.primario;
const Color kFondo = AppColors.fondo;
const Color kTarjeta = AppColors.superficie;
const Color kTextoSecundario = AppColors.textoSecundario;

class Etapa5EvaluarScreen extends StatefulWidget {
  const Etapa5EvaluarScreen({super.key});

  @override
  State<Etapa5EvaluarScreen> createState() => _Etapa5EvaluarScreenState();
}

class _Etapa5EvaluarScreenState extends State<Etapa5EvaluarScreen> {
  bool _cargando = true;
  bool _guardando = false;
  late CuadernilloData _data;

  final _queFuncionoController = TextEditingController();
  final _queNoFuncionoController = TextEditingController();
  final _proximosPasosController = TextEditingController();

  /// Guardado automático con debounce (ver services/auto_guardado.dart).
  late final AutoGuardado _auto = AutoGuardado(
    obtenerDatos: () => _data,
    sincronizar: (_) => _copiarControladoresAlModelo(),
  );

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final data = await CuadernilloService.cargar();
    setState(() {
      _data = data;
      _queFuncionoController.text = _data.evaluacionFinal.queFunciono;
      _queNoFuncionoController.text = _data.evaluacionFinal.queNoFunciono;
      _proximosPasosController.text = _data.evaluacionFinal.proximosPasos;
      _cargando = false;
    });
  }

  /// Copia los 3 textos al modelo. Se ejecuta antes de cada escritura.
  void _copiarControladoresAlModelo() {
    _data.evaluacionFinal.queFunciono = _queFuncionoController.text;
    _data.evaluacionFinal.queNoFunciono = _queNoFuncionoController.text;
    _data.evaluacionFinal.proximosPasos = _proximosPasosController.text;
  }

  Future<void> _guardar({bool completar = false}) async {
    if (completar) _data.etapa5Completada = true;
    setState(() => _guardando = true);
    await _auto.guardarAhora(); // copia los textos al modelo y guarda
    if (mounted) setState(() => _guardando = false);
  }

  Future<void> _finalizar() async {
    await _guardar(completar: true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Felicidades! Completaste las 5 etapas del Cuadernillo NEUROPLAN.'),
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
    _auto.dispose();
    _queFuncionoController.dispose();
    _queNoFuncionoController.dispose();
    _proximosPasosController.dispose();
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

    return Scaffold(
      backgroundColor: kFondo,
      appBar: AppBar(
        backgroundColor: kFondo,
        elevation: 0,
        title: Text('Etapa 5 · Evaluar',
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
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
                  'Reflexiona sobre tu proceso de 30 días.',
                  style: GoogleFonts.inter(color: kTextoSecundario, fontSize: 14),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  _buildCampo(_queFuncionoController, '¿Qué funcionó?', 'Lo que te dio buenos resultados...'),
                  const SizedBox(height: 16),
                  _buildCampo(_queNoFuncionoController, '¿Qué no funcionó?', 'Lo que no salió como esperabas...'),
                  const SizedBox(height: 16),
                  _buildCampo(_proximosPasosController, 'Próximos pasos', '¿Qué harás a partir de ahora?'),
                ],
              ),
            ),
            _buildBarraInferior(),
          ],
        ),
      ),
    );
  }

  Widget _buildCampo(TextEditingController controller, String label, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: kTarjeta, borderRadius: BorderRadius.circular(16)),
          child: TextField(
            controller: controller,
            maxLines: 4,
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
