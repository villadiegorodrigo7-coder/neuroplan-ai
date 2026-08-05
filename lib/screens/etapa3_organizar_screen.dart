import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/cuadernillo_data.dart';
import '../services/cuadernillo_service.dart';

const Color kMorado = Color(0xFF8C7CFF);
const Color kFondo = Color(0xFF12121E);
const Color kTarjeta = Color(0xFF1C1C2E);
const Color kTextoSecundario = Color(0xFFB0AEC5);

class Etapa3OrganizarScreen extends StatefulWidget {
  const Etapa3OrganizarScreen({super.key});

  @override
  State<Etapa3OrganizarScreen> createState() => _Etapa3OrganizarScreenState();
}

class _Etapa3OrganizarScreenState extends State<Etapa3OrganizarScreen> {
  bool _cargando = true;
  bool _guardando = false;
  late CuadernilloData _data;
  int _diaSeleccionado = 0;

  final _mananaController = TextEditingController();
  final _tardeController = TextEditingController();
  final _nocheController = TextEditingController();

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
      _cargarDiaEnControladores();
    });
  }

  void _cargarDiaEnControladores() {
    final dia = _data.rutinaSemanal.dias[_diaSeleccionado];
    _mananaController.text = dia.manana;
    _tardeController.text = dia.tarde;
    _nocheController.text = dia.noche;
  }

  void _guardarDiaActual() {
    final dia = _data.rutinaSemanal.dias[_diaSeleccionado];
    dia.manana = _mananaController.text;
    dia.tarde = _tardeController.text;
    dia.noche = _nocheController.text;
  }

  void _cambiarDia(int index) {
    _guardarDiaActual();
    setState(() {
      _diaSeleccionado = index;
      _cargarDiaEnControladores();
    });
  }

  Future<void> _guardar({bool completar = false}) async {
    _guardarDiaActual();
    setState(() => _guardando = true);
    if (completar) _data.etapa3Completada = true;
    await CuadernilloService.guardar(_data);
    setState(() => _guardando = false);
  }

  Future<void> _finalizar() async {
    await _guardar(completar: true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Etapa 3 completada! Tu progreso fue guardado.'),
          backgroundColor: kMorado,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _mananaController.dispose();
    _tardeController.dispose();
    _nocheController.dispose();
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
        title: Text('Etapa 3 · Organizar',
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
                  'Arma tu rutina semanal por bloques de tiempo.',
                  style: GoogleFonts.inter(color: kTextoSecundario, fontSize: 14),
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _data.rutinaSemanal.dias.length,
                itemBuilder: (context, index) {
                  final activo = index == _diaSeleccionado;
                  final dia = _data.rutinaSemanal.dias[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => _cambiarDia(index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: activo ? kMorado : kTarjeta,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          dia.dia.substring(0, 3),
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
                  _buildBloque('Mañana', Icons.wb_sunny_outlined, _mananaController),
                  const SizedBox(height: 16),
                  _buildBloque('Tarde', Icons.wb_cloudy_outlined, _tardeController),
                  const SizedBox(height: 16),
                  _buildBloque('Noche', Icons.nights_stay_outlined, _nocheController),
                ],
              ),
            ),
            _buildBarraInferior(),
          ],
        ),
      ),
    );
  }

  Widget _buildBloque(String titulo, IconData icono, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icono, color: kMorado, size: 18),
            const SizedBox(width: 8),
            Text(titulo, style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: kTarjeta, borderRadius: BorderRadius.circular(16)),
          child: TextField(
            controller: controller,
            maxLines: 3,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Qué harás en este bloque...',
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
