import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/cuadernillo_data.dart';
import '../services/cuadernillo_service.dart';
import 'cuadernillo_screen.dart';
import 'etapa2_priorizar_screen.dart';
import 'etapa3_organizar_screen.dart';
import 'etapa4_seguimiento_screen.dart';
import 'etapa5_evaluar_screen.dart';

const Color kMorado = Color(0xFF8C7CFF);
const Color kFondo = Color(0xFF12121E);
const Color kTarjeta = Color(0xFF1C1C2E);
const Color kTextoSecundario = Color(0xFFB0AEC5);

class CuadernilloHomeScreen extends StatefulWidget {
  const CuadernilloHomeScreen({super.key});

  @override
  State<CuadernilloHomeScreen> createState() => _CuadernilloHomeScreenState();
}

class _CuadernilloHomeScreenState extends State<CuadernilloHomeScreen> {
  bool _cargando = true;
  CuadernilloData? _data;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final data = await CuadernilloService.cargar();
    setState(() {
      _data = data;
      _cargando = false;
    });
  }

  Future<void> _abrirEtapa(Widget pantalla) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => pantalla),
    );
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando || _data == null) {
      return const Scaffold(
        backgroundColor: kFondo,
        body: Center(child: CircularProgressIndicator(color: kMorado)),
      );
    }

    final etapas = [
      _EtapaInfo(
        numero: 1,
        titulo: 'Diagnosticar',
        descripcion: 'Evalúa cómo estás hoy',
        icono: Icons.explore_outlined,
        completada: _data!.etapa1Completada,
        onTap: () => _abrirEtapa(const CuadernilloScreen()),
      ),
      _EtapaInfo(
        numero: 2,
        titulo: 'Priorizar',
        descripcion: 'Clasifica tus tareas por importancia',
        icono: Icons.flag_outlined,
        completada: _data!.etapa2Completada,
        onTap: () => _abrirEtapa(const Etapa2PriorizarScreen()),
      ),
      _EtapaInfo(
        numero: 3,
        titulo: 'Organizar',
        descripcion: 'Arma tu rutina semanal',
        icono: Icons.calendar_view_week_outlined,
        completada: _data!.etapa3Completada,
        onTap: () => _abrirEtapa(const Etapa3OrganizarScreen()),
      ),
      _EtapaInfo(
        numero: 4,
        titulo: 'Hacer seguimiento',
        descripcion: 'Registra tu avance día a día (30 días)',
        icono: Icons.checklist_outlined,
        completada: _data!.etapa4Completada,
        onTap: () => _abrirEtapa(const Etapa4SeguimientoScreen()),
      ),
      _EtapaInfo(
        numero: 5,
        titulo: 'Evaluar',
        descripcion: 'Reflexiona sobre tu proceso de 30 días',
        icono: Icons.insights_outlined,
        completada: _data!.etapa5Completada,
        onTap: () => _abrirEtapa(const Etapa5EvaluarScreen()),
      ),
    ];

    return Scaffold(
      backgroundColor: kFondo,
      appBar: AppBar(
        backgroundColor: kFondo,
        elevation: 0,
        title: Text(
          'Cuadernillo NEUROPLAN',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Tu método de organización personal de 30 días',
              style: GoogleFonts.inter(color: kTextoSecundario, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ...etapas.map((e) => _buildTarjetaEtapa(e)),
          ],
        ),
      ),
    );
  }

  Widget _buildTarjetaEtapa(_EtapaInfo e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: kTarjeta,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: e.onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: e.completada ? kMorado : kMorado.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    e.completada ? Icons.check : e.icono,
                    color: e.completada ? Colors.white : kMorado,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ETAPA ${e.numero} · ${e.titulo.toUpperCase()}',
                        style: GoogleFonts.inter(
                          color: kMorado,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        e.descripcion,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.4)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EtapaInfo {
  final int numero;
  final String titulo;
  final String descripcion;
  final IconData icono;
  final bool completada;
  final VoidCallback onTap;

  _EtapaInfo({
    required this.numero,
    required this.titulo,
    required this.descripcion,
    required this.icono,
    required this.completada,
    required this.onTap,
  });
}
