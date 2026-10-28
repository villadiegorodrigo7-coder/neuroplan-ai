import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/cuadernillo_data.dart';
import '../services/auto_guardado.dart';
import '../services/cuadernillo_service.dart';
import '../services/tasks_service.dart';

const Color kMorado = Color(0xFF8C7CFF);
const Color kFondo = Color(0xFF0F0F1B);
const Color kTarjeta = Color(0xFF1B1B2F);
const Color kTextoSecundario = Color(0xFFBDBBD6);

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

  /// Guardado automático con debounce (ver services/auto_guardado.dart).
  late final AutoGuardado _auto = AutoGuardado(
    obtenerDatos: () => _data,
    sincronizar: _sincronizar,
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
      _cargando = false;
    });
  }

  /// Se ejecuta justo antes de cada escritura. Hace dos cosas:
  ///  1. Confirma los textos escritos que el usuario aún no agregó con el
  ///     botón + (solo al salir o pasar a segundo plano, nunca mientras
  ///     escribe, para no guardar tareas a medias).
  ///  2. Pasa la matriz a la pantalla de Tareas (TasksService), para que
  ///     las tareas del cuadernillo aparezcan en "Tareas".
  void _sincronizar(MotivoGuardado motivo) {
    final m = _data.matrizEisenhower;
    if (motivo != MotivoGuardado.debounce) {
      final refrescar = motivo != MotivoGuardado.cierre;
      _confirmarBorrador(m.urgenteImportante, _controllerUI, refrescar);
      _confirmarBorrador(m.importanteNoUrgente, _controllerINU, refrescar);
      _confirmarBorrador(m.urgenteNoImportante, _controllerUNI, refrescar);
      _confirmarBorrador(m.niUrgenteNiImportante, _controllerNN, refrescar);
    }
    // No se espera (fire and forget): no depende del estado del widget.
    unawaited(TasksService.instance.sincronizarMatriz(m));
  }

  void _confirmarBorrador(
    List<String> lista,
    TextEditingController controller,
    bool refrescar,
  ) {
    final texto = controller.text.trim();
    if (texto.isEmpty) return;
    lista.add(texto);
    controller.clear();
    // No se puede llamar setState mientras la pantalla se está cerrando.
    if (refrescar && mounted) setState(() {});
  }

  Future<void> _guardar({bool completar = false}) async {
    if (completar) _data.etapa2Completada = true;
    setState(() => _guardando = true);
    await _auto.guardarAhora();
    if (mounted) setState(() => _guardando = false);
  }

  void _agregarTarea(List<String> lista, TextEditingController controller) {
    final texto = controller.text.trim();
    if (texto.isEmpty) return;
    setState(() {
      lista.add(texto);
      controller.clear();
    });
    _auto.programar(); // cambio en el modelo => guardado automático
  }

  void _eliminarTarea(List<String> lista, int index) {
    setState(() => lista.removeAt(index));
    _auto.programar();
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
    // Primero: cancela el timer y guarda lo pendiente (antes de liberar
    // los controllers, porque _sincronizar los lee).
    _auto.dispose();
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
