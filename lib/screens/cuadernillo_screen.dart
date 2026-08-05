import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/cuadernillo_data.dart';
import '../services/cuadernillo_service.dart';

// Colores del tema (mismo morado/azul del resto de la app)
const Color kMorado = Color(0xFF8C7CFF);
const Color kFondo = Color(0xFF12121E);
const Color kTarjeta = Color(0xFF1C1C2E);
const Color kTextoSecundario = Color(0xFFB0AEC5);

class CuadernilloScreen extends StatefulWidget {
  const CuadernilloScreen({super.key});

  @override
  State<CuadernilloScreen> createState() => _CuadernilloScreenState();
}

class _CuadernilloScreenState extends State<CuadernilloScreen> {
  bool _cargando = true;
  bool _guardando = false;
  int _pasoActual = 0; // 0 = Diagnostico, 1 = RuedaVida, 2 = ConsumoTiempo

  late CuadernilloData _data;

  // Controladores para los 4 campos de texto de Consumo de Tiempo
  final _redesController = TextEditingController();
  final _distraccionesController = TextEditingController();
  final _obligacionesController = TextEditingController();
  final _habitosController = TextEditingController();

  // Controlador para la nota del Diagnostico Inicial
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
      _notaController.text = _data.diagnosticoInicial.nota;
      _redesController.text = _data.consumoTiempo.redesSociales;
      _distraccionesController.text = _data.consumoTiempo.distracciones;
      _obligacionesController.text = _data.consumoTiempo.obligaciones;
      _habitosController.text = _data.consumoTiempo.habitos;
      _cargando = false;
    });
  }

  Future<void> _guardarProgreso({bool marcarCompletada = false}) async {
    setState(() => _guardando = true);

    _data.diagnosticoInicial.nota = _notaController.text;
    _data.consumoTiempo.redesSociales = _redesController.text;
    _data.consumoTiempo.distracciones = _distraccionesController.text;
    _data.consumoTiempo.obligaciones = _obligacionesController.text;
    _data.consumoTiempo.habitos = _habitosController.text;

    if (marcarCompletada) {
      _data.etapa1Completada = true;
    }

    await CuadernilloService.guardar(_data);

    setState(() => _guardando = false);
  }

  void _irSiguiente() async {
    await _guardarProgreso();
    if (_pasoActual < 2) {
      setState(() => _pasoActual++);
    } else {
      await _guardarProgreso(marcarCompletada: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Etapa 1 completada! Tu progreso fue guardado.'),
            backgroundColor: kMorado,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  void _irAtras() async {
    if (_pasoActual > 0) {
      await _guardarProgreso();
      setState(() => _pasoActual--);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _redesController.dispose();
    _distraccionesController.dispose();
    _obligacionesController.dispose();
    _habitosController.dispose();
    _notaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        backgroundColor: kFondo,
        body: Center(
          child: CircularProgressIndicator(color: kMorado),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kFondo,
      appBar: AppBar(
        backgroundColor: kFondo,
        elevation: 0,
        title: Text(
          'Cuadernillo NEUROPLAN',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildEncabezadoEtapa(),
            _buildIndicadorPasos(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: _buildContenidoPaso(),
              ),
            ),
            _buildBarraInferior(),
          ],
        ),
      ),
    );
  }

  Widget _buildEncabezadoEtapa() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ETAPA 1 · DIAGNOSTICAR',
            style: GoogleFonts.inter(
              color: kMorado,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _tituloPaso(),
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _descripcionPaso(),
            style: GoogleFonts.inter(
              color: kTextoSecundario,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _tituloPaso() {
    switch (_pasoActual) {
      case 0:
        return 'Diagnóstico Inicial';
      case 1:
        return 'Rueda de la Vida';
      default:
        return 'Consumo de Tiempo';
    }
  }

  String _descripcionPaso() {
    switch (_pasoActual) {
      case 0:
        return 'Evalúa del 1 al 10 cómo te sientes hoy en cada área.';
      case 1:
        return 'Califica del 1 al 10 tu satisfacción en cada área de tu vida.';
      default:
        return 'Describe con tus palabras en qué se te va el tiempo.';
    }
  }

  Widget _buildIndicadorPasos() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: List.generate(3, (index) {
          final activo = index <= _pasoActual;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
              decoration: BoxDecoration(
                color: activo ? kMorado : kTarjeta,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildContenidoPaso() {
    switch (_pasoActual) {
      case 0:
        return _buildPasoDiagnostico();
      case 1:
        return _buildPasoRuedaVida();
      default:
        return _buildPasoConsumoTiempo();
    }
  }

  // ---------- PASO 1: Diagnostico Inicial ----------
  Widget _buildPasoDiagnostico() {
    final d = _data.diagnosticoInicial;
    return Column(
      children: [
        _buildSlider('Energía', d.energia, (v) {
          setState(() => d.energia = v);
        }),
        _buildSlider('Estrés', d.estres, (v) {
          setState(() => d.estres = v);
        }),
        _buildSlider('Claridad mental', d.claridadMental, (v) {
          setState(() => d.claridadMental = v);
        }),
        _buildSlider('Organización', d.organizacion, (v) {
          setState(() => d.organizacion = v);
        }),
        _buildSlider('Motivación', d.motivacion, (v) {
          setState(() => d.motivacion = v);
        }),
        _buildSlider('Satisfacción general', d.satisfaccionGeneral, (v) {
          setState(() => d.satisfaccionGeneral = v);
        }),
        const SizedBox(height: 8),
        _buildCampoTexto(
          controller: _notaController,
          label: 'Nota adicional (opcional)',
          hint: 'Algo más que quieras registrar sobre cómo te sientes hoy...',
          lineas: 3,
        ),
      ],
    );
  }

  // ---------- PASO 2: Rueda de la Vida ----------
  Widget _buildPasoRuedaVida() {
    final r = _data.ruedaVida;
    return Column(
      children: [
        _buildSlider('Salud', r.salud, (v) => setState(() => r.salud = v)),
        _buildSlider(
            'Estudios', r.estudios, (v) => setState(() => r.estudios = v)),
        _buildSlider(
            'Trabajo', r.trabajo, (v) => setState(() => r.trabajo = v)),
        _buildSlider(
            'Finanzas', r.finanzas, (v) => setState(() => r.finanzas = v)),
        _buildSlider(
            'Familia', r.familia, (v) => setState(() => r.familia = v)),
        _buildSlider(
            'Amigos', r.amigos, (v) => setState(() => r.amigos = v)),
        _buildSlider(
            'Descanso', r.descanso, (v) => setState(() => r.descanso = v)),
        _buildSlider('Crecimiento personal', r.crecimiento,
            (v) => setState(() => r.crecimiento = v)),
      ],
    );
  }

  // ---------- PASO 3: Consumo de Tiempo ----------
  Widget _buildPasoConsumoTiempo() {
    return Column(
      children: [
        _buildCampoTexto(
          controller: _redesController,
          label: 'Redes sociales',
          hint: '¿Cuánto tiempo y en qué apps se te va el día?',
          lineas: 3,
        ),
        const SizedBox(height: 16),
        _buildCampoTexto(
          controller: _distraccionesController,
          label: 'Distracciones',
          hint: '¿Qué te distrae más seguido durante el día?',
          lineas: 3,
        ),
        const SizedBox(height: 16),
        _buildCampoTexto(
          controller: _obligacionesController,
          label: 'Obligaciones',
          hint: 'Tareas, trabajo, estudio, responsabilidades diarias...',
          lineas: 3,
        ),
        const SizedBox(height: 16),
        _buildCampoTexto(
          controller: _habitosController,
          label: 'Hábitos',
          hint: 'Rutinas actuales, buenas o malas, que ocupan tu tiempo...',
          lineas: 3,
        ),
      ],
    );
  }

  // ---------- WIDGETS REUTILIZABLES ----------

  Widget _buildSlider(String label, int valor, ValueChanged<int> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kTarjeta,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kMorado,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$valor',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
              min: 1,
              max: 10,
              divisions: 9,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampoTexto({
    required TextEditingController controller,
    required String label,
    required String hint,
    int lineas = 3,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: kTarjeta,
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextField(
            controller: controller,
            maxLines: lineas,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(
                color: kTextoSecundario,
                fontSize: 13,
              ),
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
      decoration: BoxDecoration(
        color: kFondo,
        border: Border(top: BorderSide(color: kTarjeta, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _guardando ? null : _irAtras,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: kMorado),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                _pasoActual == 0 ? 'Salir' : 'Atrás',
                style: GoogleFonts.inter(
                  color: kMorado,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _guardando ? null : _irSiguiente,
              style: ElevatedButton.styleFrom(
                backgroundColor: kMorado,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _guardando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _pasoActual == 2 ? 'Finalizar' : 'Siguiente',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
