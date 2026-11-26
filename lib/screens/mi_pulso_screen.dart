import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/chat_conversation.dart';
import '../models/entrada_diario.dart';
import '../models/productividad_data.dart';
import '../models/task.dart';
import '../services/agenda_store.dart';
import '../services/chat_history_service.dart';
import '../services/concierto_final_service.dart';
import '../services/diario_store.dart';
import '../services/gemini_service.dart';
import '../services/herramientas_service.dart';
import '../services/tasks_service.dart';
import '../widgets/panel_cuenta.dart';
import '../widgets/pulso_painter.dart';
import '../widgets/radar_diagnostico_painter.dart';
import 'chat_screen.dart';
import 'concierto_final_screen.dart';

/// Mi pulso reúne dos dimensiones complementarias: la experiencia diaria
/// (Mi ritmo) y las intenciones elegidas (Mis intenciones).
class MiPulsoScreen extends StatefulWidget {
  const MiPulsoScreen({super.key});

  @override
  State<MiPulsoScreen> createState() => _MiPulsoScreenState();
}

class _MiPulsoScreenState extends State<MiPulsoScreen> {
  static const Color _sinRegistro = Color(0xFF30384D);
  DateTime _seleccionado = DateTime.now();
  bool _cargando = true;
  DateTime? _inicioCiclo;
  CicloNeuroplan? _cicloActual;
  HerramientasData? _herramientas;
  bool _preparandoConcierto = false;

  DateTime get _hoy => DateTime.now();
  int get _duracionCiclo => _cicloActual?.duracionDias ?? 30;

  List<DateTime> get _dias {
    final inicio = _inicioCiclo;
    if (inicio == null) return [];
    return List.generate(_duracionCiclo, (i) => inicio.add(Duration(days: i)));
  }

  String _clave(DateTime d) => EntradaDiario.claveFecha(d);

  @override
  void initState() {
    super.initState();
    DiarioStore.instance.addListener(_actualizar);
    TasksService.instance.addListener(_actualizar);
    AgendaStore.instance.addListener(_actualizar);
    HerramientasService.cambios.addListener(_actualizarHerramientas);
    _cargar();
  }

  Future<void> _cargar() async {
    await Future.wait([
      DiarioStore.instance.cargar(),
      TasksService.instance.cargar(),
      AgendaStore.instance.cargar(),
    ]);

    // La existencia y las fechas del ciclo provienen del servicio central.
    // Nunca inferimos el inicio a partir de entradas antiguas del diario.
    final herramientas = await HerramientasService.cargar();
    final datos = await _recuperarRuedaDesdeDiagnostico(herramientas);
    if (!mounted) return;

    setState(() {
      _aplicarHerramientas(datos);
      _cargando = false;
    });
  }

  /// Si el diagnóstico ya terminó en Ágora pero la propuesta visual no se
  /// alcanzó a guardar, Mi Pulso la recupera al abrirse. Así no depende de que
  /// ChatScreen siga montada cuando termina la conversación.
  Future<HerramientasData> _recuperarRuedaDesdeDiagnostico(
    HerramientasData data,
  ) async {
    final existente = data.diagnosticoConversacional;
    if (existente != null &&
        (existente.valoresPropuestos.isNotEmpty || existente.confirmado)) {
      return data;
    }

    try {
      final conversaciones = await ChatHistoryService.loadConversations();
      ChatConversation? diagnostico;
      for (final conv in conversaciones) {
        if (conv.title == 'Diagnóstico inicial') {
          diagnostico = conv;
          break;
        }
      }
      if (diagnostico == null) return data;

      final historial = diagnostico.messages
          .where((m) => m.role != 'system' && m.content.trim().isNotEmpty)
          .map(
            (m) => <String, String>{
              'role': m.role == 'user' ? 'user' : 'model',
              'content': m.content,
            },
          )
          .toList();
      if (historial.where((m) => m['role'] == 'user').length < 3) {
        return data;
      }

      final tieneMarcador = diagnostico.diagnosticoCompleto ||
          diagnostico.messages.any(
            (m) => m.content.contains('[[DIAGNOSTICO_COMPLETO]]'),
          );
      final completo = tieneMarcador ||
          await GeminiService.diagnosticoConversacionalCompleto(historial);
      if (!completo) return data;

      // Persistir el cierre antes de solicitar la propuesta evita que una
      // falla temporal de Gemini obligue a clasificar otra vez el historial.
      diagnostico.diagnosticoCompleto = true;
      if (!diagnostico.messages.any(
        (m) => m.role == 'system' && m.content == 'DIAGNOSTICO_COMPLETO',
      )) {
        diagnostico.messages.add(
          ChatMessageData(role: 'system', content: 'DIAGNOSTICO_COMPLETO'),
        );
      }
      await ChatHistoryService.saveConversations(conversaciones);

      final propuesta = await GeminiService.proponerDiagnosticoConversacional(
        historial,
      );
      if (propuesta == null) return data;

      data.diagnosticoConversacional = DiagnosticoConversacional(
        valoresPropuestos: Map<String, int>.from(
          propuesta['valoresPropuestos'] as Map,
        ),
        fundamentos: Map<String, String>.from(propuesta['fundamentos'] as Map),
        resumen: (propuesta['resumen'] ?? '').toString(),
      );
      await HerramientasService.guardar(data);
      return data;
    } catch (error, stackTrace) {
      debugPrint('No se pudo recuperar la Rueda de la Vida: $error');
      debugPrintStack(stackTrace: stackTrace);
      return data;
    }
  }

  CicloNeuroplan? _cicloVisible(HerramientasData data) {
    final activo = HerramientasService.cicloActivo(data);
    if (activo != null) return activo;
    return data.ciclos.isEmpty ? null : data.ciclos.last;
  }

  bool get _cicloFinalizado =>
      _cicloActual?.estado == 'cerrado' &&
      (_cicloActual?.conciertoFinalCompletado ?? false);

  void _actualizar() {
    if (mounted) setState(() {});
  }

  Future<void> _actualizarHerramientas() async {
    final data = await HerramientasService.cargar();
    if (!mounted) return;
    setState(() => _aplicarHerramientas(data));
  }

  void _aplicarHerramientas(HerramientasData data) {
    final ciclo = _cicloVisible(data);
    final inicio = ciclo?.inicio;
    _herramientas = data;
    _cicloActual = inicio == null ? null : ciclo;
    _inicioCiclo =
        inicio == null ? null : DateTime(inicio.year, inicio.month, inicio.day);

    final hoy = _hoy;
    final dias = _dias;
    final inicioLocal = _inicioCiclo;
    if (inicioLocal == null || dias.isEmpty) {
      _seleccionado = hoy;
      return;
    }

    final fechaHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final diferencia = fechaHoy.difference(inicioLocal).inDays;
    _seleccionado = dias[diferencia.clamp(0, dias.length - 1)];
  }

  @override
  void dispose() {
    DiarioStore.instance.removeListener(_actualizar);
    TasksService.instance.removeListener(_actualizar);
    AgendaStore.instance.removeListener(_actualizar);
    HerramientasService.cambios.removeListener(_actualizarHerramientas);
    super.dispose();
  }

  EntradaDiario? _entrada(DateTime d) {
    final key = _clave(d);
    for (final e in DiarioStore.instance.entradas) {
      if (e.fecha == key) return e;
    }
    return null;
  }

  List<Task> _tareas(DateTime d) =>
      TasksService.instance.tasks.where((t) => t.fecha == _clave(d)).toList();

  static const Color _diaTranscurrido = Color(0xFFFF9800);

  int get _diasTranscurridos {
    final inicio = _inicioCiclo;
    if (inicio == null) return 0;
    final hoy = DateTime(_hoy.year, _hoy.month, _hoy.day);
    final diferencia = hoy.difference(inicio).inDays;
    return (diferencia + 1).clamp(0, _duracionCiclo);
  }

  // Durante el ciclo muestra el avance; al completarlo conserva la historia
  // diaria mediante los colores del semáforo registrados en el diario.
  Color _colorDia(DateTime d) {
    if (_cicloFinalizado) {
      final semaforo = _entrada(d)?.semaforo ?? '';
      return colorDeSemaforo(semaforo) ?? _sinRegistro;
    }
    final hoy = DateTime(_hoy.year, _hoy.month, _hoy.day);
    return !d.isAfter(hoy) ? _diaTranscurrido : _sinRegistro;
  }

  String _fechaLarga(DateTime d) {
    const dias = [
      'lunes',
      'martes',
      'miércoles',
      'jueves',
      'viernes',
      'sábado',
      'domingo',
    ];
    const meses = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    final dia = dias[d.weekday - 1];
    return '${dia[0].toUpperCase()}${dia.substring(1)} ${d.day} de ${meses[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi pulso'),
        actions: [
          IconButton(
            tooltip: 'Cuenta',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => mostrarPanelCuenta(context),
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final resumen = Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 6, child: _panelIndicadores(scheme)),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 5,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: _anillo(scheme),
                      ),
                    ),
                  ],
                );
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    _encabezadoPulso(scheme),
                    const SizedBox(height: 18),
                    // La Rueda de la Vida queda al frente para que sea
                    // visible al entrar a Mi pulso, sin tener que buscarla
                    // debajo del seguimiento de 30 días.
                    _composicionDiagnostica(scheme),
                    const SizedBox(height: 22),
                    if (_cicloActual == null) ...[
                      _invitacionIniciarCiclo(scheme),
                    ] else ...[
                      Text(
                        'Tu recorrido · ciclo de $_duracionCiclo días',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_cicloActual?.puedeRealizarConciertoFinal ==
                          true) ...[
                        _invitacionConciertoFinal(scheme),
                        const SizedBox(height: 22),
                      ] else if (_cicloActual?.estado == 'activo' &&
                          _diasTranscurridos > 15 &&
                          _diasTranscurridos <= _duracionCiclo &&
                          !(_cicloActual?.conciertoFinalCompletado ?? false)) ...[
                        _invitacionVistaPrevia(scheme),
                        const SizedBox(height: 22),
                      ],
                      resumen,
                      const SizedBox(height: 22),
                      _tareasDelDia(scheme),
                    ],
                  ],
                );
              },
            ),
    );
  }

  Widget _encabezadoPulso(ColorScheme scheme) {
    final ciclo = _cicloActual;
    final transcurridos = _diasTranscurridos;
    final progreso = ciclo == null ? 0.0 : transcurridos / _duracionCiclo;
    final subtitulo = ciclo == null
        ? 'Un espacio para observar tu tiempo, tu energía y tus decisiones.'
        : _cicloFinalizado
            ? 'Este fue tu recorrido. Cada color conserva la memoria de tus días.'
            : 'Tu ciclo está en marcha. Cada día forma parte de tu recorrido.';
    return Container(
      padding: const EdgeInsets.fromLTRB(19, 19, 19, 17),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF172B4B), Color(0xFF171D3B), Color(0xFF29204D)],
        ),
        border: Border.all(
          color: const Color(0xFF6FDFF2).withValues(alpha: 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6957D8).withValues(alpha: 0.14),
            blurRadius: 25,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: const Color(0xFF62DDF0).withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.graphic_eq_rounded,
                  color: Color(0xFF75E5F2),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MI PULSO',
                      style: TextStyle(
                        color: Color(0xFF8CEBFF),
                        fontSize: 10,
                        letterSpacing: 2.1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Tu vida, en su propio ritmo',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (ciclo != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: (_cicloFinalizado
                            ? const Color(0xFF34D399)
                            : const Color(0xFFFFA94D))
                        .withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: (_cicloFinalizado
                              ? const Color(0xFF34D399)
                              : const Color(0xFFFFA94D))
                          .withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    _cicloFinalizado ? 'CICLO COMPLETADO' : 'CICLO ACTIVO',
                    style: TextStyle(
                      color: _cicloFinalizado
                          ? const Color(0xFF7BE5B7)
                          : const Color(0xFFFFC078),
                      fontSize: 9,
                      letterSpacing: 0.7,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            subtitulo,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          if (ciclo != null) ...[
            const SizedBox(height: 17),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$transcurridos',
                  style: const TextStyle(
                    fontSize: 31,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFFB45C),
                  ),
                ),
                const SizedBox(width: 7),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    'de $_duracionCiclo días',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.70),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${(progreso * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF8CEBFF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: progreso.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.11),
                valueColor: const AlwaysStoppedAnimation(Color(0xFFFFA94D)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Vista de lectura sin acciones de cierre ni cambios en el ciclo.
  Future<void> _abrirVistaPreviaConcierto() async {
    final ciclo = _cicloActual;
    if (ciclo == null || ciclo.estado != 'activo' ||
        _diasTranscurridos <= 15 ||
        _diasTranscurridos > ciclo.duracionDias ||
        ciclo.conciertoFinalCompletado || _preparandoConcierto) {
      return;
    }
    setState(() => _preparandoConcierto = true);
    try {
      final snapshot = await ConciertoFinalService.preparar(
        cicloId: ciclo.id, vistaPrevia: true);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ConciertoFinalScreen(snapshot: snapshot)));
    } catch (error, stackTrace) {
      debugPrint('Vista previa Concierto Final: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No pudimos cargar tu vista previa. Inténtalo de nuevo.'),
      ));
    } finally {
      if (mounted) setState(() => _preparandoConcierto = false);
    }
  }

  Widget _invitacionVistaPrevia(ColorScheme scheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: scheme.primary.withValues(alpha: .10),
        border: Border.all(color: scheme.primary.withValues(alpha: .38)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.insights_rounded, color: scheme.primary),
          const SizedBox(width: 9),
          const Expanded(child: Text('Vista previa · Concierto Final',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 8),
        Text('Día $_diasTranscurridos de $_duracionCiclo. Mira los indicadores que llevas registrados. No finaliza ni modifica tu ciclo.',
          style: const TextStyle(fontSize: 12, height: 1.4)),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: FilledButton.icon(
          onPressed: _preparandoConcierto ? null : _abrirVistaPreviaConcierto,
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('Ver mi recorrido hasta hoy'),
        )),
      ]),
    );
  }

  Future<void> _abrirConciertoFinal() async {
    final ciclo = _cicloActual;
    if (ciclo == null ||
        !ciclo.puedeRealizarConciertoFinal ||
        _preparandoConcierto) {
      return;
    }

    setState(() => _preparandoConcierto = true);
    try {
      final snapshot = await ConciertoFinalService.preparar(cicloId: ciclo.id);
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ConciertoFinalScreen(snapshot: snapshot),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Concierto Final: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No pudimos preparar tu recorrido. Inténtalo de nuevo.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _preparandoConcierto = false);
    }
  }

  Widget _invitacionConciertoFinal(ColorScheme scheme) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primaryContainer, scheme.surfaceContainerHighest],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.music_note_rounded, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Concierto Final',
                  style: textTheme.titleLarge?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Tu ciclo llegó a su fin. Repasa con Ágora lo que viviste '
            'y decide cuándo cerrar esta etapa.',
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onPrimaryContainer,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _preparandoConcierto ? null : _abrirConciertoFinal,
              icon: _preparandoConcierto
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward_rounded),
              label: Text(
                _preparandoConcierto
                    ? 'Preparando tu recorrido…'
                    : 'Reflexionar con Ágora',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _invitacionIniciarCiclo(ColorScheme scheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.hourglass_empty_rounded, color: scheme.primary, size: 28),
          const SizedBox(height: 12),
          const Text(
            'Tu recorrido todavía no ha comenzado',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Cuando estés listo, conversa con Ágora. Ella te acompañará a '
            'decidir cuándo iniciar tu primer ciclo. Tus registros anteriores '
            'se conservan; no se utilizan para inventar una fecha de inicio.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _anillo(ColorScheme scheme) {
    return Center(
      child: SizedBox(
        width: 290,
        height: 290,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(290, 290),
              painter: PulsoPainter(
                colores: _dias.map(_colorDia).toList(),
                seleccionado: _dias.indexWhere(
                  (d) => _clave(d) == _clave(_seleccionado),
                ),
                base: _sinRegistro,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MI PULSO',
                  style: TextStyle(
                    color: scheme.primary,
                    fontSize: 12,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$_diasTranscurridos',
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _cicloFinalizado
                      ? 'días del recorrido'
                      : 'días transcurridos de $_duracionCiclo',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.68),
                  ),
                ),
              ],
            ),
            for (var i = 0; i < _dias.length; i++) _puntoInteractivo(i, scheme),
          ],
        ),
      ),
    );
  }

  /// Controles compactos de Mi ritmo. El registro sigue perteneciendo
  /// únicamente al día seleccionado y se persiste mediante DiarioStore.
  Widget _panelIndicadores(ColorScheme scheme) {
    final entrada = _entrada(_seleccionado);
    final semaforo = entrada?.semaforo ?? '';
    const tonos = [kColorDesafio, kColorAtencion, kColorBien];
    const claves = ['riesgo', 'atencion', 'bien'];
    const nombres = ['Desafío', 'Atención', 'Bien'];
    const estados = ['😞', '😕', '😐', '🙂', '😄'];
    const energias = ['🪫', '😴', '🌤️', '⚡', '🔥'];
    final estado = entrada?.estado ?? 0;
    final energia = entrada?.energia ?? 0;

    Widget selectorEmoji({
      required String titulo,
      required int valor,
      required List<String> emojis,
      required List<String> etiquetas,
      required void Function(int) guardar,
    }) {
      final actual = valor >= 1 && valor <= 5 ? valor - 1 : null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          PopupMenuButton<int>(
            tooltip: 'Elegir $titulo',
            initialValue: valor,
            onSelected: guardar,
            color: const Color(0xFF242424),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
            itemBuilder: (context) => [
              for (var i = 0; i < 5; i++)
                PopupMenuItem<int>(
                  value: i + 1,
                  child: Row(
                    children: [
                      Text(emojis[i], style: const TextStyle(fontSize: 23)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          etiquetas[i],
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      if (valor == i + 1)
                        Icon(
                          Icons.check_rounded,
                          color: scheme.primary,
                          size: 18,
                        ),
                    ],
                  ),
                ),
              const PopupMenuItem<int>(
                value: 0,
                child: Text('Sin registro', style: TextStyle(fontSize: 12)),
              ),
            ],
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFF242424),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                children: [
                  Text(
                    actual == null ? '▫️' : emojis[actual],
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      actual == null ? 'Sin registro' : etiquetas[actual],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 19),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Registro de hoy',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        // Etiquetas visibles junto a cada foco (rojo, amarillo y verde).
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 75,
              child: Padding(
                // Iguala la altura interior del semáforo (borde + margen).
                // Cada etiqueta queda centrada frente a su propia luz.
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final item in const [
                      ('Desafío', 'Reconocer'),
                      ('Atención', 'Observar'),
                      ('Bien', 'Satisfacción'),
                    ])
                      SizedBox(
                        height: 63,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              item.$1,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              item.$2,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 70,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(36),
                border: Border.all(color: const Color(0xFF485365), width: 3),
              ),
              child: Column(
                children: List.generate(3, (i) {
                  final activo = semaforo == claves[i] ||
                      (i == 0 && semaforo == 'desafio');
                  return SizedBox(
                    height: 63,
                    child: Center(
                      child: Semantics(
                        button: true,
                        label: 'Registrar día: ${nombres[i]}',
                        selected: activo,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            final registro = DiarioStore.instance.obtenerOCrear(
                              _clave(_seleccionado),
                            );
                            registro.semaforo = claves[i];
                            DiarioStore.instance.cambio(registro);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: tonos[i].withValues(
                                alpha: activo ? 1 : 0.78,
                              ),
                              border: Border.all(
                                color: tonos[i].withValues(
                                  alpha: activo ? 1 : 0.4,
                                ),
                              ),
                              boxShadow: activo
                                  ? [
                                      BoxShadow(
                                        color: tonos[i].withValues(alpha: 0.52),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Toca una luz para registrar tu día',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.78),
          ),
        ),
        const SizedBox(height: 15),
        Divider(color: Colors.white.withValues(alpha: 0.12)),
        const SizedBox(height: 13),
        selectorEmoji(
          titulo: 'Estado emocional',
          valor: estado,
          emojis: estados,
          etiquetas: kNivelesEstado,
          guardar: (nivel) {
            final registro = DiarioStore.instance.obtenerOCrear(
              _clave(_seleccionado),
            );
            registro.estado = nivel;
            DiarioStore.instance.cambio(registro);
          },
        ),
        const SizedBox(height: 12),
        selectorEmoji(
          titulo: 'Energía',
          valor: energia,
          emojis: energias,
          etiquetas: kNivelesEnergia,
          guardar: (nivel) {
            final registro = DiarioStore.instance.obtenerOCrear(
              _clave(_seleccionado),
            );
            registro.energia = nivel;
            DiarioStore.instance.cambio(registro);
          },
        ),
      ],
    );
  }

  /// Dos discos superpuestos: cada uno conserva su gráfico y sus valores.
  /// El toque intercambia el primer plano; la transición combina profundidad,
  /// inclinación y giro tipo flip sin convertir los gráficos en imágenes.
  static const List<Color> _coloresRueda = [
    Color(0xFF35D07F), // Salud
    Color(0xFF45A9FF), // Estudios
    Color(0xFFFF9F43), // Trabajo
    Color(0xFFFFD166), // Finanzas
    Color(0xFFFF6FAE), // Familia
    Color(0xFF35D6C5), // Amigos
    Color(0xFFB28DFF), // Descanso
    Color(0xFFA6D854), // Crecimiento
    Color(0xFFFFE45E), // Energía
    Color(0xFFFF5C65), // Estrés
    Color(0xFF65D8FF), // Claridad mental
    Color(0xFF788BFF), // Organización
    Color(0xFFFF65D4), // Motivación
    Color(0xFFFF876B), // Satisfacción general
  ];

  static const List<String> _etiquetasRueda = [
    'Salud',
    'Estudios',
    'Trabajo',
    'Finanzas',
    'Familia',
    'Amigos',
    'Descanso',
    'Crecimiento',
    'Energía',
    'Estrés',
    'Claridad mental',
    'Organización',
    'Motivación',
    'Satisfacción',
  ];

  bool get _hayPropuestaRueda =>
      (_herramientas?.diagnosticoConversacional?.valoresPropuestos.isNotEmpty ??
          false) ||
      (_herramientas?.diagnosticoConversacional?.confirmado == true);

  bool get _tieneDiagnosticoConversacionalConfirmado =>
      _herramientas?.diagnosticoConversacional?.confirmado == true;

  Map<String, int> get _valoresDisponiblesRueda {
    final diagnostico = _herramientas?.diagnosticoConversacional;
    return diagnostico?.confirmado == true
        ? diagnostico!.valoresConfirmados
        : diagnostico?.valoresPropuestos ?? const <String, int>{};
  }

  Set<int> get _dimensionesSinDatoRueda => {
        for (var i = 0; i < _etiquetasRueda.length; i++)
          if (!_valoresDisponiblesRueda.containsKey(_etiquetasRueda[i])) i,
      };

  List<double> _valoresRuedaUnificada() => _etiquetasRueda
      .map((etiqueta) => (_valoresDisponiblesRueda[etiqueta] ?? 0).toDouble())
      .toList();

  Widget _composicionDiagnostica(ColorScheme scheme) {
    final valores = _valoresRuedaUnificada();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Rueda de la Vida',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          !_hayPropuestaRueda
              ? 'Base inicial: todas las dimensiones parten de 0. Ágora las revisará mediante sondeo y propondrá valores a partir de lo que conversen.'
              : _tieneDiagnosticoConversacionalConfirmado
                  ? 'Diagnóstico conversacional confirmado. Puedes volver a revisar tus dimensiones.'
                  : 'Propuesta preliminar de Ágora. Revisa cada dimensión y confirma solo cuando te represente.',
          style: TextStyle(
            fontSize: 12,
            height: 1.35,
            color: Colors.white.withValues(alpha: 0.66),
          ),
        ),
        if ((_herramientas?.diagnosticoConversacional?.resumen ?? '')
            .trim()
            .isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
            child: Text(
              _herramientas!.diagnosticoConversacional!.resumen,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Colors.white.withValues(alpha: 0.82),
              ),
            ),
          ),
        const SizedBox(height: 12),
        Center(
          child: GestureDetector(
            onTap: _hayPropuestaRueda
                ? () => _abrirEditorRadar(scheme: scheme)
                : null,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 430),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF121E3B),
                    Color(0xFF10172F),
                    Color(0xFF211D43),
                  ],
                ),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: const Color(0xFF8CEBFF).withValues(alpha: 0.13),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    blurRadius: 26,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 300,
                    child: CustomPaint(
                      painter: RadarDiagnosticoPainter(
                        values: valores,
                        labels: _etiquetasRueda,
                        color: const Color(0xFF9B75FF),
                        axisColors: _coloresRueda,
                        textColor: Colors.white,
                        missingIndices: _hayPropuestaRueda
                            ? _dimensionesSinDatoRueda
                            : const <int>{},
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.open_in_full,
                        size: 15,
                        color: Color(0xFF8CEBFF),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Toca para ampliar y editar',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _abrirEditorRadar({required ColorScheme scheme}) async {
    final editados = _valoresRuedaUnificada();
    final faltantesIniciales = _dimensionesSinDatoRueda;
    final dimensionesEditadas = <int>{};
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, actualizarDialogo) {
          void moverPunto(Offset posicion, Size size) {
            final centro = Offset(size.width / 2, size.height / 2);
            final delta = posicion - centro;
            final radio = math.min(size.width, size.height) * 0.285;
            if (delta.distance < 2) return;
            var angulo = math.atan2(delta.dy, delta.dx) + math.pi / 2;
            if (angulo < 0) angulo += 2 * math.pi;
            final paso = 2 * math.pi / editados.length;
            final indice = ((angulo / paso).round()) % editados.length;
            final valor = (delta.distance / radio * 10).clamp(0.0, 10.0);
            actualizarDialogo(() {
              editados[indice] = valor;
              dimensionesEditadas.add(indice);
            });
          }

          return Dialog.fullscreen(
            backgroundColor: const Color(0xFF080F22),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                        const Expanded(
                          child: Text(
                            'Rueda de la Vida',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final data = _herramientas;
                            if (data == null) return;
                            final diagnostico = data.diagnosticoConversacional;
                            if (diagnostico == null) return;
                            for (var i = 0; i < _etiquetasRueda.length; i++) {
                              final etiqueta = _etiquetasRueda[i];
                              if (!faltantesIniciales.contains(i) ||
                                  dimensionesEditadas.contains(i)) {
                                diagnostico.valoresConfirmados[etiqueta] =
                                    editados[i].round();
                              }
                            }
                            diagnostico.confirmado = true;
                            await HerramientasService.guardar(data);
                            if (mounted) setState(() {});
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          },
                          child: Text(
                            _tieneDiagnosticoConversacionalConfirmado
                                ? 'Guardar cambios'
                                : 'Confirmar diagnóstico',
                            style: const TextStyle(
                              color: Color(0xFF8CEBFF),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Text(
                      'Toca o arrastra sobre el gráfico para ajustar cada dimensión. También puedes usar los controles.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final side = math.min(
                          constraints.maxWidth,
                          constraints.maxHeight * 0.78,
                        );
                        return Center(
                          child: SizedBox(
                            width: side,
                            height: side,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapDown: (d) =>
                                  moverPunto(d.localPosition, Size(side, side)),
                              onPanStart: (d) =>
                                  moverPunto(d.localPosition, Size(side, side)),
                              onPanUpdate: (d) =>
                                  moverPunto(d.localPosition, Size(side, side)),
                              child: CustomPaint(
                                painter: RadarDiagnosticoPainter(
                                  values: editados,
                                  labels: _etiquetasRueda,
                                  color: const Color(0xFF9B75FF),
                                  axisColors: _coloresRueda,
                                  textColor: Colors.white,
                                  missingIndices: {
                                    for (final i in faltantesIniciales)
                                      if (!dimensionesEditadas.contains(i)) i,
                                  },
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    height: math.min(
                      250,
                      MediaQuery.of(context).size.height * 0.29,
                    ),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                      itemCount: _etiquetasRueda.length,
                      itemBuilder: (context, index) {
                        final fundamento = _herramientas
                            ?.diagnosticoConversacional
                            ?.fundamentos[_etiquetasRueda[index]];
                        return Row(
                          children: [
                            Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: _coloresRueda[index],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _etiquetasRueda[index],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (fundamento != null &&
                                      fundamento.trim().isNotEmpty)
                                    Text(
                                      fundamento,
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 10,
                                      ),
                                    ),
                                  if (faltantesIniciales.contains(index) &&
                                      !dimensionesEditadas.contains(index))
                                    const Text(
                                      'Sin información suficiente · puedes proponer un valor',
                                      style: TextStyle(
                                        color: Colors.amberAccent,
                                        fontSize: 10,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 6,
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: _coloresRueda[index],
                                  thumbColor: _coloresRueda[index],
                                  inactiveTrackColor: _coloresRueda[index]
                                      .withValues(alpha: 0.20),
                                ),
                                child: Slider(
                                  value:
                                      editados[index].clamp(0, 10).toDouble(),
                                  min: 0,
                                  max: 10,
                                  divisions: 10,
                                  onChanged: (value) => actualizarDialogo(() {
                                    editados[index] = value;
                                    dimensionesEditadas.add(index);
                                  }),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 25,
                              child: Text(
                                faltantesIniciales.contains(index) &&
                                        !dimensionesEditadas.contains(index)
                                    ? '—'
                                    : editados[index].toStringAsFixed(0),
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  color: _coloresRueda[index],
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _tareasDelDia(ColorScheme scheme) {
    final tareasMatriz = _tareas(_seleccionado).where((t) => t.done).toList();
    final compromisos = AgendaStore.instance
        .eventosEnDia(_seleccionado)
        .where((e) => e.realizadaEn(_seleccionado))
        .toList();
    final clave = _clave(_seleccionado);
    final habitos = (_herramientas?.habitos ?? [])
        .where((h) => h.registros[clave] == true)
        .toList();
    final total = tareasMatriz.length + compromisos.length + habitos.length;

    Widget actividad(String titulo, String origen, IconData icono) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icono, size: 18, color: scheme.primary),
            const SizedBox(width: 9),
            Expanded(child: Text(titulo, style: const TextStyle(fontSize: 13))),
            Text(
              origen,
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.58),
              ),
            ),
            const SizedBox(width: 5),
            Icon(Icons.check_circle, size: 16, color: scheme.primary),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.task_alt, color: scheme.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Tareas cumplidas',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '$total',
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _fechaLarga(_seleccionado),
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 10),
          if (total == 0)
            Text(
              'Aún no hay actividades cumplidas en este día.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.68),
              ),
            )
          else ...[
            for (final tarea in tareasMatriz)
              actividad(tarea.title, 'Matriz', Icons.checklist),
            for (final evento in compromisos)
              actividad(evento.title, 'Agenda', Icons.event_available),
            for (final habito in habitos)
              actividad(habito.nombre, 'Hábito', Icons.repeat),
          ],
        ],
      ),
    );
  }

  Widget _puntoInteractivo(int index, ColorScheme scheme) {
    const center = 145.0;
    const radius = 118.0;
    final angle = (index * 2 * 3.141592653589793 / _duracionCiclo) -
        3.141592653589793 / 2;
    final x = center + radius * math.cos(angle) - 13;
    final y = center + radius * math.sin(angle) - 13;
    final seleccionado = _clave(_dias[index]) == _clave(_seleccionado);
    return Positioned(
      left: x,
      top: y,
      child: GestureDetector(
        onTap: () => setState(() => _seleccionado = _dias[index]),
        child: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _colorDia(_dias[index]),
            shape: BoxShape.circle,
            border: Border.all(
              color:
                  seleccionado ? Colors.orangeAccent : const Color(0xFF0B1020),
              width: seleccionado ? 2.5 : 1.5,
            ),
          ),
          child: Text(
            '${_dias[index].day}',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: _colorDia(_dias[index]) == _sinRegistro
                  ? Colors.white70
                  : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
