import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/entrada_diario.dart';
import '../theme/app_theme.dart';
import '../services/diario_store.dart';
import '../services/reflexion_service.dart';
import '../models/chat_conversation.dart';
import '../models/productividad_data.dart';
import '../services/gemini_service.dart';
import '../services/voice_service.dart';
import '../services/chat_history_service.dart';
import '../services/herramientas_service.dart';
import '../services/tasks_service.dart';
import '../services/concierto_final_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    this.conciertoFinalSnapshot,
  });

  final ConciertoFinalSnapshot? conciertoFinalSnapshot;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _agoraMotionController;

  List<ChatConversation> _conversations = [];
  ChatConversation? _current;

  bool _isLoading = false;
  /// La voz de Ágora empieza apagada: solo habla si la persona activa la bocina.
  /// La elección se recuerda en este dispositivo.
  bool _voiceReplyEnabled = false;
  /// La experiencia inmersiva solo se abre cuando Ágora va a responder con voz.
  bool _immersiveVoiceMode = false;
  bool _isListening = false;
  String _textoAntesDeDictar = '';

  /// Cada vez que se empieza a dictar sube este número. Lo que llegue del
  /// micrófono con un número viejo se ignora: así un resultado tardío nunca
  /// vuelve a escribir en la caja después de enviar o de editar a mano.
  int _sesionDictado = 0;
  static const String _prefVoz = 'chat_voz_activada';

  /// Si no es null, esta conversación es la "reflexión del día" de esa fecha
  /// (por ejemplo "2026-10-24") y se muestra el botón para guardarla en el diario.
  String? _reflexionFecha;
  int? _revisionSemanalSemana;

  static const List<String> _mesesNombre = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];
  bool _loadingHistory = true;
  bool _proponerInicioCiclo = false;
  bool _esPrimerCiclo = true;
  bool _iniciandoCiclo = false;

  @override
  void initState() {
    super.initState();
    _agoraMotionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _loadHistory();
    _loadVoicePreference();
    ReflexionService.instance.senal.addListener(_alSolicitarReflexion);
  }

  // ------------------------------------------------------------------
  // Reflexión del día con Ágora
  // ------------------------------------------------------------------

  String _nombreFecha(String fecha) {
    final d = DateTime.tryParse(fecha);
    if (d == null) return fecha;
    return '${d.day} de ${_mesesNombre[d.month - 1]}';
  }

  /// Mi diario pidió una reflexión: se abre una conversación nueva.
  void _alSolicitarReflexion() {
    final fecha = ReflexionService.instance.consumir();
    if (fecha != null) _iniciarReflexion(fecha);
  }

  /// Primer mensaje de Ágora: lo arma la app (no gasta mensajes de la IA).
  String _aperturaReflexion(EntradaDiario? e) {
    final partes = <String>['Vamos a mirar tu día con calma.'];
    if (e != null && e.semaforo.isNotEmpty) {
      partes.add('Marcaste ${nombreDeSemaforo(e.semaforo).toLowerCase()}.');
    }
    if (e != null && e.prioridad.isNotEmpty) {
      partes.add('Tu prioridad era: ${e.prioridad}.');
    }
    partes.add('Cuéntame, hablando o escribiendo: ¿por qué crees que el día salió así?');
    return partes.join(' ');
  }

  Future<void> _iniciarReflexion(String fecha) async {
    try {
      await DiarioStore.instance.cargar();
    } catch (_) {}
    final entrada = DiarioStore.instance.de(fecha);
    final conv = await ChatHistoryService.createConversation();
    conv.title = 'Reflexión del ${_nombreFecha(fecha)}';
    conv.messages.add(
      ChatMessageData(role: 'model', content: _aperturaReflexion(entrada)),
    );
    if (!mounted) return;
    setState(() {
      _conversations.insert(0, conv);
      _current = conv;
      _reflexionFecha = fecha;
    });
    await _persist();
    _scrollToBottom();
  }

  /// Guarda en Mi diario lo que la persona dijo en esta conversación, con sus
  /// propias palabras. Se agrega a la reflexión que ya hubiera ese día.
  Future<void> _guardarReflexion() async {
    final fecha = _reflexionFecha;
    final conv = _current;
    if (fecha == null || conv == null) return;

    final texto = conv.messages
        .where((m) => m.role == 'user')
        .map((m) => m.content.trim())
        .where((t) => t.isNotEmpty)
        .join('\n\n');
    if (texto.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Todavía no has dicho nada para guardar.')),
      );
      return;
    }

    final store = DiarioStore.instance;
    try {
      await store.cargar();
    } catch (_) {}
    final entrada = store.obtenerOCrear(fecha);
    entrada.reflexion =
        entrada.reflexion.isEmpty ? texto : '${entrada.reflexion}\n\n$texto';
    store.cambio(entrada);
    await store.guardarYa();

    if (!mounted) return;
    setState(() => _reflexionFecha = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Guardado en tu diario.')),
    );
  }

  Widget _bannerReflexion(ColorScheme scheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
      color: scheme.primary.withValues(alpha: 0.14),
      child: Row(
        children: [
          Icon(Icons.menu_book_rounded, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Reflexión del día · ${_nombreFecha(_reflexionFecha ?? '')}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: _guardarReflexion,
            child: const Text('Guardar en mi diario'),
          ),
          IconButton(
            tooltip: 'Terminar sin guardar',
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _reflexionFecha = null),
          ),
        ],
      ),
    );
  }

  Future<void> _loadVoicePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activada = prefs.getBool(_prefVoz) ?? false;
      if (mounted) setState(() => _voiceReplyEnabled = activada);
    } catch (_) {
      // Si no se puede leer, la voz queda apagada.
    }
  }

  Future<void> _toggleVoiceReply() async {
    final nueva = !_voiceReplyEnabled;
    setState(() => _voiceReplyEnabled = nueva);
    if (!nueva) VoiceService.stopSpeaking();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefVoz, nueva);
    } catch (_) {}
  }

  /// Envía una sola vez el dictado de una sesión inmersiva. El callback
  /// onDone y el botón de detener pueden coincidir; la sesión evita duplicados.
  void _enviarDictadoInmersivoSiCorresponde(int sesion) {
    if (!mounted ||
        sesion != _sesionDictado ||
        !_immersiveVoiceMode ||
        _isLoading) {
      return;
    }

    final dictado = _controller.text.trim();
    if (dictado.isEmpty) return;

    // Se invalida la sesión antes de enviar: cualquier callback tardío queda
    // descartado y no puede volver a enviar el mismo reconocimiento.
    _sesionDictado++;
    _sendMessage(dictado);
  }

  /// Dictado: pulsa el micrófono, habla con calma y pulsa de nuevo para
  /// terminar. En el chat escrito el texto queda disponible para revisarlo.
  Future<void> _toggleDictado() async {
    if (_isListening) {
      final sesion = _sesionDictado;
      await VoiceService.stopListening();
      if (!mounted) return;

      setState(() => _isListening = false);
      _enviarDictadoInmersivoSiCorresponde(sesion);
      return;
    }

    _textoAntesDeDictar = _controller.text.trim();
    final sesion = ++_sesionDictado;
    setState(() => _isListening = true);

    final activado = await VoiceService.startListening(
      onResult: (texto, esFinal) {
        if (!mounted || sesion != _sesionDictado) return;
        final base = _textoAntesDeDictar;
        final unido = base.isEmpty ? texto : '$base $texto';
        _controller.text = unido;
        _controller.selection = TextSelection.collapsed(offset: unido.length);
        if (esFinal) _textoAntesDeDictar = unido;
      },
      onDone: () {
        if (!mounted || sesion != _sesionDictado) return;
        setState(() => _isListening = false);
        _enviarDictadoInmersivoSiCorresponde(sesion);
      },
      onError: (_) {},
    );

    if (!activado && mounted && sesion == _sesionDictado) {
      // Invalida cualquier callback tardío de una activación fallida.
      _sesionDictado++;
      setState(() => _isListening = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No pude activar el micrófono. Revisa el permiso del navegador, o prueba con Chrome o Edge.',
          ),
        ),
      );
    }
  }

  Future<void> _loadHistory() async {
    final list = await ChatHistoryService.loadConversations();

    // El diagnóstico conversacional se inicia una sola vez por cuenta.
    // La conversación queda guardada en el historial para poder retomarla
    // si la persona cierra la aplicación antes de terminar.
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null) {
      final prefs = await SharedPreferences.getInstance();
      final claveInicio = 'agora_diagnostico_inicial_v1_$uid';
      final yaIniciado = prefs.getBool(claveInicio) ?? false;
      if (!yaIniciado) {
        ChatConversation? diagnostico;
        for (final c in list) {
          if (c.title == 'Diagnóstico inicial') {
            diagnostico = c;
            break;
          }
        }
        if (diagnostico == null) {
          diagnostico = await ChatHistoryService.createConversation();
          diagnostico.title = 'Diagnóstico inicial';
          diagnostico.messages.add(
            ChatMessageData(role: 'model', content: 'Hola, ¿cómo te llamas?'),
          );
          list.insert(0, diagnostico);
          await ChatHistoryService.saveConversations(list);
        }
        await prefs.setBool(claveInicio, true);
      }
    }

    final revisionSemanal = await _crearRevisionSemanalSiCorresponde(list);
    final conversacionInicial = revisionSemanal ?? (list.isNotEmpty ? list.first : null);

    if (!mounted) return;
    setState(() {
      _conversations = list;
      _current = conversacionInicial;
      _revisionSemanalSemana = _semanaDeRevision(conversacionInicial);
      _loadingHistory = false;
    });
    await _generarInformeHabitosSiCorresponde();
    await _recuperarDiagnosticoCompleto();
    await _actualizarPropuestaInicioCiclo();
    await _abrirConciertoFinalSiCorresponde();
  }

  /// Crea o recupera la conversación especial del ciclo. El contexto queda
  /// guardado en Supabase junto con la conversación para poder retomarla.
  Future<void> _abrirConciertoFinalSiCorresponde() async {
    final snapshot = widget.conciertoFinalSnapshot;
    if (snapshot == null || !mounted) return;

    final marcaCiclo = 'CONCIERTO_FINAL_CICLO:${snapshot.ciclo.id}';
    ChatConversation? existente;
    for (final candidata in _conversations) {
      if (candidata.messages.any((m) =>
          m.role == 'system' && m.content.trim() == marcaCiclo)) {
        existente = candidata;
        break;
      }
    }

    final esNueva = existente == null;
    final conv = existente ?? await ChatHistoryService.createConversation();
    conv.title = 'Concierto Final';

    final indiceContexto = conv.messages.indexWhere((m) =>
        m.role == 'system' &&
        m.content.startsWith('CONCIERTO_FINAL_CONTEXTO:'));
    final contextoGuardado =
        'CONCIERTO_FINAL_CONTEXTO:\n${snapshot.contextoParaAgora}';
    if (indiceContexto >= 0) {
      conv.messages[indiceContexto] =
          ChatMessageData(role: 'system', content: contextoGuardado);
    } else {
      conv.messages.add(ChatMessageData(role: 'system', content: marcaCiclo));
      conv.messages.add(
        ChatMessageData(role: 'system', content: contextoGuardado),
      );
    }

    if (esNueva) {
      conv.messages.add(ChatMessageData(
        role: 'model',
        content: 'Estoy aquí. Vamos a mirar juntos lo que has vivido. Treinta días no definen quién eres, pero pueden ayudarnos a reconocer algunas cosas de tu recorrido. No vamos a ponerte una nota ni a juzgar los días sin registro. Si algo de lo que observemos no representa tu experiencia, puedes corregirlo. ¿Qué te gustaría reconocer primero de estos días?',
      ));
      _conversations.insert(0, conv);
    }

    if (!mounted) return;
    setState(() {
      _current = conv;
      _reflexionFecha = null;
      _revisionSemanalSemana = null;
      _proponerInicioCiclo = false;
    });
    await _persist();
    _scrollToBottom();
  }

  /// Recupera una conversación que ya terminó pero cuya rueda no se generó.
  /// La comprobación se limita a una vez al día mientras no exista propuesta.
  Future<void> _recuperarDiagnosticoCompleto() async {
    try {
      ChatConversation? diagnostico;
      for (final conv in _conversations) {
        if (conv.title == 'Diagnóstico inicial') {
          diagnostico = conv;
          break;
        }
      }
      if (diagnostico == null) return;

      final data = await HerramientasService.cargar();
      final existente = data.diagnosticoConversacional;
      if (existente != null &&
          (existente.valoresPropuestos.isNotEmpty || existente.confirmado)) {
        return;
      }

      final historial = diagnostico.messages
          .where((m) => m.role != 'system' && m.content.trim().isNotEmpty)
          .map((m) => {
                'role': m.role == 'user' ? 'user' : 'model',
                'content': m.content,
              })
          .toList();
      final respuestasUsuario =
          historial.where((m) => m['role'] == 'user').length;
      if (respuestasUsuario == 0) return;

      // La conversación puede cubrir varias preguntas en una sola respuesta.
      // No imponemos un mínimo artificial de turnos: el clasificador evalúa
      // el contenido real y el cierre integrador, no el número de mensajes.
      final tieneMarcador = diagnostico.diagnosticoCompleto ||
          diagnostico.messages.any(
            (m) => m.content.contains('[[DIAGNOSTICO_COMPLETO]]'),
          );
      var completo = tieneMarcador;
      if (!completo) {
        final uid = Supabase.instance.client.auth.currentUser?.id;
        if (uid == null) return;
        final prefs = await SharedPreferences.getInstance();
        final claveRevision =
            'agora_diagnostico_recuperacion_v1_${uid}_${diagnostico.id}';
        final hoy = EntradaDiario.claveFecha(DateTime.now());
        // Si el sondeo sigue abierto, no volvemos a clasificarlo cada vez
        // que se abre el chat. Se permite una nueva comprobación al día.
        if (prefs.getString(claveRevision) == hoy) return;
        completo =
            await GeminiService.diagnosticoConversacionalCompleto(historial);
        await prefs.setString(claveRevision, hoy);
      }
      if (!completo) return;

      diagnostico.diagnosticoCompleto = true;
      if (!diagnostico.messages.any((m) =>
          m.role == 'system' && m.content == 'DIAGNOSTICO_COMPLETO')) {
        diagnostico.messages.add(ChatMessageData(
          role: 'system',
          content: 'DIAGNOSTICO_COMPLETO',
        ));
      }
      await _persist();
      await _generarPropuestaDiagnostico(diagnostico);
    } catch (_) {
      // La recuperación nunca debe impedir entrar a la aplicación.
    }
  }

  /// La propuesta solo aparece al completar el diagnóstico y si no existe
  /// un ciclo activo. La persona debe confirmar con un botón explícito.
  Future<void> _actualizarPropuestaInicioCiclo() async {
    try {
      final conv = _current;
      if (conv == null || conv.title != 'Diagnóstico inicial' ||
          !conv.diagnosticoCompleto) {
        if (mounted) setState(() => _proponerInicioCiclo = false);
        return;
      }
      final data = await HerramientasService.cargar();
      final activo = HerramientasService.cicloActivo(data);
      if (mounted) {
        setState(() {
          _proponerInicioCiclo = activo == null;
          _esPrimerCiclo = data.ciclos.isEmpty;
        });
      }
    } catch (_) {
      // Un fallo al consultar el ciclo no debe bloquear la conversación.
    }
  }

  Future<void> _confirmarInicioCiclo() async {
    if (_iniciandoCiclo || !_proponerInicioCiclo) return;
    setState(() => _iniciandoCiclo = true);
    try {
      final ciclo = await HerramientasService.iniciarCiclo(duracionDias: 30);
      if (!mounted) return;
      final fecha = ciclo.inicio;
      final fechaTexto = fecha == null
          ? ciclo.fechaInicio
          : '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
      final conv = _current;
      setState(() {
        _proponerInicioCiclo = false;
        _iniciandoCiclo = false;
        if (conv != null) {
          conv.messages.add(ChatMessageData(
            role: 'model',
            content: '${_esPrimerCiclo ? 'Tu primer ciclo' : 'Tu nuevo ciclo'} de NEUROPLAN ha comenzado el $fechaTexto y tendrá una duración de 30 días. No se trata de hacerlo todo perfecto: vamos a observar tu tiempo, tu energía y aquello que quieras transformar, un día a la vez.',
          ));
        }
      });
      await _persist();
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _iniciandoCiclo = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pude iniciar el ciclo. Inténtalo de nuevo.')),
      );
    }
  }

  int? _semanaDeRevision(ChatConversation? conv) {
    if (conv == null) return null;
    final match = RegExp(r'^Revisión semanal · semana (\d+)$').firstMatch(conv.title);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  /// Abre una revisión al cumplirse cada periodo de siete días desde el diagnóstico.
  Future<ChatConversation?> _crearRevisionSemanalSiCorresponde(
      List<ChatConversation> list) async {
    ChatConversation? diagnostico;
    for (final conv in list) {
      if (conv.title == 'Diagnóstico inicial') {
        diagnostico = conv;
        break;
      }
    }
    if (diagnostico == null) return null;

    final ahora = DateTime.now();
    final inicio = DateTime(diagnostico.createdAt.year, diagnostico.createdAt.month, diagnostico.createdAt.day);
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final semana = hoy.difference(inicio).inDays ~/ 7;
    if (semana < 1) return null;
    final titulo = 'Revisión semanal · semana $semana';
    if (list.any((c) => c.title == titulo)) return null;

    final conv = await ChatHistoryService.createConversation();
    conv.title = titulo;
    conv.messages.add(ChatMessageData(
      role: 'model',
      content: 'Ya ha pasado una semana desde que comenzaste NEUROPLAN. '
          'Quiero que miremos cómo transcurrieron estos días teniendo presente '
          'lo que me contaste al iniciar. No es una evaluación ni una lista de '
          'cumplimientos. Empecemos por algo sencillo: ¿qué ocupó más tu tiempo '
          'y tu energía durante esta semana?',
    ));
    list.insert(0, conv);
    await ChatHistoryService.saveConversations(list);
    return conv;
  }

  Future<void> _generarInformeHabitosSiCorresponde() async {
    try {
      final data = await HerramientasService.cargar();
      if (data.habitos.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      const claveUltimoInforme = 'agora_ultimo_informe_habitos';
      final ultimo = DateTime.tryParse(prefs.getString(claveUltimoInforme) ?? '');
      final hoy = DateTime.now();
      final fechas = data.habitos.expand((h) => h.registros.keys)
          .map(DateTime.tryParse).whereType<DateTime>().toList()..sort();
      if (fechas.isEmpty) return;
      final primerRegistro = fechas.first;
      final desde = ultimo ?? primerRegistro;
      if (hoy.difference(DateTime(desde.year, desde.month, desde.day)).inDays < 3) return;

      final inicioVentana = hoy.subtract(const Duration(days: 3));
      final lineas = <String>[];
      for (final h in data.habitos) {
        final registros = h.registros.entries.where((e) {
          final fecha = DateTime.tryParse(e.key);
          return fecha != null &&
              !fecha.isBefore(DateTime(inicioVentana.year, inicioVentana.month, inicioVentana.day)) &&
              !fecha.isAfter(DateTime(hoy.year, hoy.month, hoy.day));
        }).toList()..sort((a, b) => a.key.compareTo(b.key));
        if (registros.isEmpty) continue;
        final favorables = registros.where((e) => e.value).length;
        final observados = registros.length;
        final etiqueta = h.tipo == 'incorporar' ? 'por incorporar' : 'por alejar';
        final lectura = h.tipo == 'incorporar'
            ? '$favorables de $observados registros realizados'
            : '$favorables de $observados registros en los que lograste evitarlo';
        lineas.add('- ${h.nombre} ($etiqueta): $lectura.');
      }
      if (lineas.isEmpty) return;

      final conv = await ChatHistoryService.createConversation();
      conv.title = 'Seguimiento de hábitos · ${EntradaDiario.claveFecha(hoy)}';
      conv.messages.add(ChatMessageData(
        role: 'model',
        content: '''Volvamos a mirar tus hábitos de estos tres días. Esto no es una calificación ni una conclusión sobre ti; es una lectura de los registros que decidiste hacer.

${lineas.join('\n')}

¿Qué has notado en estos días? ¿Qué te ha ayudado o dificultado mantener estos cambios?

Si algún día no registraste, lo dejamos como información ausente, no como incumplimiento.''',
      ));
      if (!mounted) return;
      setState(() {
        _conversations.insert(0, conv);
        _current = conv;
        _revisionSemanalSemana = null;
      });
      await _persist();
      await prefs.setString(claveUltimoInforme, EntradaDiario.claveFecha(hoy));
      _scrollToBottom();
    } catch (_) {
      // Un informe fallido no debe impedir abrir ni usar el chat.
    }
  }

  Future<void> _generarPropuestaDiagnostico(ChatConversation conv) async {
    try {
      final data = await HerramientasService.cargar();
      final existente = data.diagnosticoConversacional;
      if (existente != null &&
          (existente.valoresPropuestos.isNotEmpty || existente.confirmado)) {
        return;
      }
      final historial = conv.messages
          .where((m) => m.role != 'system' && m.content.trim().isNotEmpty)
          .map((m) => {
                'role': m.role == 'user' ? 'user' : 'model',
                'content': m.content,
              })
          .toList();
      // Solo compartimos los antecedentes del diario con el generador:
      // las tareas pendientes no son evidencia para puntuar dimensiones vitales.
      final contextoDiario = await _construirContextoDiario();
      final propuesta =
          await GeminiService.proponerDiagnosticoConversacional(
        historial,
        contextoUsuario: contextoDiario,
      );
      if (propuesta == null) return;

      data.diagnosticoConversacional = DiagnosticoConversacional(
        valoresPropuestos: Map<String, int>.from(propuesta['valoresPropuestos'] as Map),
        fundamentos: Map<String, String>.from(propuesta['fundamentos'] as Map),
        resumen: (propuesta['resumen'] ?? '').toString(),
        antecedentesHistoricos:
            existente?.antecedentesHistoricos ?? <String, dynamic>{},
      );
      await HerramientasService.guardar(data);

      final aviso = ChatMessageData(
        role: 'model',
        content: 'He preparado una primera hipótesis visual de tu Rueda de la Vida a partir de lo que conversamos. No es una calificación ni una conclusión definitiva. Puedes revisarla, ajustar cada dimensión y confirmarla cuando te represente, desde Mi Pulso.',
      );
      conv.messages.add(aviso);
      await _persist();
      if (mounted && _current?.id == conv.id) {
        setState(() {});
        _scrollToBottom();
      }
    } catch (_) {
      // La conversación sigue disponible aunque falle la propuesta visual.
    }
  }

  Future<void> _persist() async {
    await ChatHistoryService.saveConversations(_conversations);
  }

  Future<void> _startNewChat() async {
    final conv = await ChatHistoryService.createConversation();
    setState(() {
      _conversations.insert(0, conv);
      _current = conv;
      _revisionSemanalSemana = null;
    });
    await _persist();
    if (mounted) Navigator.of(context).maybePop();
  }

  void _selectConversation(ChatConversation conv) {
    setState(() {
      _current = conv;
      _revisionSemanalSemana = _semanaDeRevision(conv);
    });
    _actualizarPropuestaInicioCiclo();
    Navigator.of(context).maybePop();
    _scrollToBottom();
  }

  Future<void> _deleteConversation(ChatConversation conv) async {
    setState(() {
      _conversations.removeWhere((c) => c.id == conv.id);
      if (_current?.id == conv.id) {
        _current = _conversations.isNotEmpty ? _conversations.first : null;
        _revisionSemanalSemana = _semanaDeRevision(_current);
      }
    });
    await _persist();
  }

  Future<void> _sendMessage([String? voiceText]) async {
    // Se cierra el dictado y se ignora lo que el micrófono todavía entregue.
    _sesionDictado++;
    if (_isListening) {
      setState(() => _isListening = false);
      VoiceService.stopListening();
    }
    final text = (voiceText ?? _controller.text).trim();
    if (text.isEmpty) return;

    if (_current == null) {
      final conv = await ChatHistoryService.createConversation();
      setState(() {
        _conversations.insert(0, conv);
        _current = conv;
      });
    }

    final conv = _current!;
    final isFirstMessage = conv.messages.isEmpty;

    setState(() {
      conv.messages.add(ChatMessageData(role: 'user', content: text));
      if (isFirstMessage) {
        conv.title = ChatHistoryService.buildTitle(text);
      }
      _isLoading = true;
      _controller.clear();
    });
    _scrollToBottom();
    await _persist();

    // El último mensaje (el que acaba de escribir el usuario) se envía aparte
    // en sendMessage, así que se excluye del historial para no duplicarlo.
    final history = conv.messages
        .sublist(0, conv.messages.length - 1)
        .where((m) => m.role != 'system')
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();

    // Una conversación que empieza con un mensaje de Ágora (como la reflexión
    // del día) se envía con un primer turno de la persona, porque el servicio
    // de IA exige que la conversación empiece por ella.
    if (history.isNotEmpty && history.first['role'] == 'model') {
      final mensajeDeContexto = _reflexionFecha != null
          ? 'Quiero hacer mi reflexión del día.'
          : _revisionSemanalSemana != null
              ? 'Quiero hacer mi revisión semanal de NEUROPLAN.'
              : conv.title == 'Diagnóstico inicial'
                  ? 'Estoy comenzando el diagnóstico inicial de NEUROPLAN y respondo al saludo de Ágora.'
                  : 'Quiero continuar esta conversación con Ágora.';
      history.insert(0, {'role': 'user', 'content': mensajeDeContexto});
    }

    final contexto = await _construirContextoUsuario(
      incluirAntecedentesDiagnostico: conv.title == 'Diagnóstico inicial',
    );

    final respuestaAgora = await GeminiService.sendMessage(
      text,
      history: history,
      contextoUsuario: contexto,
    );
    final diagnosticoCompleto =
        conv.title == 'Diagnóstico inicial' &&
        (respuestaAgora.contains('[[DIAGNOSTICO_COMPLETO]]') ||
            conv.diagnosticoCompleto);
    if (diagnosticoCompleto) {
      conv.diagnosticoCompleto = true;
      if (!conv.messages.any((m) =>
          m.role == 'system' && m.content == 'DIAGNOSTICO_COMPLETO')) {
        conv.messages.add(ChatMessageData(
          role: 'system',
          content: 'DIAGNOSTICO_COMPLETO',
        ));
      }
    }
    final response = respuestaAgora
        .replaceAll('[[DIAGNOSTICO_COMPLETO]]', '')
        .trim();

    if (!mounted) return;
    setState(() {
      conv.messages.add(ChatMessageData(role: 'model', content: response));
      _isLoading = false;
    });
    _scrollToBottom();
    await _persist();

    if (diagnosticoCompleto) {
      await _generarPropuestaDiagnostico(conv);
      await _actualizarPropuestaInicioCiclo();
    }

    if (_voiceReplyEnabled) {
      setState(() => _immersiveVoiceMode = true);
      await VoiceService.speak(response);
    }
  }

  /// Comparte con Ágora únicamente el diagnóstico conversacional confirmado.
  Future<String?> _construirContextoUsuario({
    bool incluirAntecedentesDiagnostico = false,
  }) async {
    final data = await HerramientasService.cargar();
    final partes = <String>[];
    final diagnostico = data.diagnosticoConversacional;

    if (incluirAntecedentesDiagnostico &&
        diagnostico != null &&
        diagnostico.antecedentesHistoricos.isNotEmpty) {
      final antecedentes = diagnostico.antecedentesHistoricos;
      final rueda = antecedentes['ruedaVida'];
      final inicial = antecedentes['diagnosticoInicial'];
      final lineasHistoricas = <String>[];
      if (rueda is Map && rueda.isNotEmpty) {
        lineasHistoricas.add(
          'Rueda de la Vida histórica (datos antiguos, no confirmados hoy): '
          '${rueda.entries.map((e) => '${e.key}: ${e.value}').join(', ')}.',
        );
      }
      if (inicial is Map && inicial.isNotEmpty) {
        lineasHistoricas.add(
          'Diagnóstico inicial histórico (referencia antigua, no equivale a '
          'una evaluación actual): '
          '${inicial.entries.map((e) => '${e.key}: ${e.value}').join(', ')}.',
        );
      }
      if (lineasHistoricas.isNotEmpty) {
        partes.add(
          'ANTECEDENTES HISTÓRICOS PARA EL DIAGNÓSTICO. Úsalos solo para '
          'orientar preguntas y detectar qué conviene confirmar. No los '
          'conviertas en puntuaciones actuales ni en valores de la Rueda. '
          'Si pueden haber cambiado, pregunta por su vigencia.\n'
          '${lineasHistoricas.join('\n')}',
        );
      }
    }
    if (diagnostico != null && diagnostico.confirmado) {
      final valores = diagnostico.valoresConfirmados.entries
          .map((e) => '${e.key}: ${e.value}/10')
          .join(', ');
      final fundamentos = diagnostico.fundamentos.entries
          .map((e) => '${e.key}: ${e.value}')
          .join(' | ');
      partes.add(
        'Rueda de la Vida confirmada por la persona después de conversar '
        'con Ágora. Valores revisados y aceptados: $valores. '
        '${diagnostico.resumen.trim().isEmpty ? '' : 'Síntesis aceptada: ${diagnostico.resumen}'} '
        '${fundamentos.isEmpty ? '' : 'Fundamentos conversados: $fundamentos'} '
        'Estos valores son una referencia personal confirmada, no un diagnóstico clínico.',
      );
    }

    // --- Contexto persistente del Concierto Final ---
    final conversacionActual = _current;
    if (conversacionActual?.title == 'Concierto Final') {
      String? contextoConcierto;
      for (final mensaje in conversacionActual!.messages) {
        if (mensaje.role == 'system' &&
            mensaje.content.startsWith('CONCIERTO_FINAL_CONTEXTO:')) {
          contextoConcierto = mensaje.content
              .substring('CONCIERTO_FINAL_CONTEXTO:'.length)
              .trim();
          break;
        }
      }
      partes.insert(
        0,
        'MODO CONCIERTO FINAL. Estás acompañando a la persona a revisar un ciclo ya completado. '
        'No cierres el ciclo, no propongas empezar otro y no presentes esta conversación como examen. '
        'Primero escucha qué quiere mirar la persona. Puedes ayudar a reconocer patrones, momentos '
        'significativos, cambios y preguntas abiertas. Haz una sola pregunta por turno. Diferencia '
        'datos registrados, palabras de la persona e interpretaciones tentativas. Invita a corregir '
        'cualquier interpretación. La conversación debe ser cálida, honesta y sin juicios.'
        '${contextoConcierto == null ? '' : '\n\nRECORRIDO RECOPILADO PARA ESTA CONVERSACIÓN:\n$contextoConcierto'}',
      );
    }

    // --- Tareas del usuario, por cuadrante de la Matriz de Eisenhower ---
    if (conversacionActual?.title != 'Concierto Final') {
      final tareas = await _construirContextoTareas();
      if (tareas != null) partes.add(tareas);

      // --- Mi diario ---
      final diario = await _construirContextoDiario();
      if (diario != null) partes.add(diario);
    }

    // --- Contexto del diagnóstico para las revisiones semanales ---
    if (_revisionSemanalSemana != null) {
      ChatConversation? diagnostico;
      for (final conv in _conversations) {
        if (conv.title == 'Diagnóstico inicial') {
          diagnostico = conv;
          break;
        }
      }
      if (diagnostico != null) {
        final respuestas = diagnostico.messages
            .where((m) => m.role == 'user' && m.content.trim().isNotEmpty)
            .take(14)
            .map((m) => _recortar(m.content, max: 220))
            .toList();
        if (respuestas.isNotEmpty) {
          partes.add(
            'Respuestas de la persona en su diagnóstico inicial. Úsalas para '
            'personalizar la revisión semanal, relacionando el uso de tiempo y '
            'energía con las áreas y preocupaciones que la propia persona nombró. '
            'No conviertas estos datos en puntuaciones ni supongas que algo cambió.\n'
            '${respuestas.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}',
          );
        }
      }

      partes.insert(
        0,
        'MODO REVISIÓN SEMANAL · semana $_revisionSemanalSemana. Guía una '
        'conversación natural, no un formulario. Haz una pregunta por turno y '
        'adáptala a las respuestas. Explora: qué ocupó el tiempo y la energía '
        'durante la semana; qué ocurrió con las áreas, necesidades o dificultades '
        'que aparecieron en el diagnóstico; qué cambios o patrones reconoce la '
        'persona; y qué propósito pequeño y realista quiere llevar a la semana '
        'siguiente. Conecta explícitamente las preguntas con lo que la persona '
        'contó en su diagnóstico, sin repetirlo mecánicamente. No exijas una '
        'racha diaria, no califiques el rendimiento, no juzgues y no interpretes '
        'la ausencia de registros como incumplimiento. La revisión debe recoger '
        'lo vivido durante los siete días como información para observar el '
        'proceso, no como examen.',
      );
    }

    // --- Modo reflexión del día ---
    if (_reflexionFecha != null) {
      partes.insert(
        0,
        'MODO REFLEXIÓN DIARIA. La persona está haciendo su reflexión del día. '
        'Guía una conversación breve con estas tres preguntas, siempre en este '
        'orden y una por turno: 1) "¿Cómo te sentiste hoy?" 2) "¿Cómo crees que '
        'salieron las cosas?" 3) "¿Qué crees que podrías mejorar y cómo podrías '
        'hacerlo?". Espera la respuesta a cada pregunta antes de formular la '
        'siguiente. Reconoce brevemente lo que escuchaste y distingue el estado '
        'personal de la valoración de los resultados: alguien puede sentirse '
        'mal y aun así haber conseguido lo que se propuso, o sentirse bien aunque '
        'las cosas no hayan salido como esperaba. No agregues preguntas de '
        'interrogatorio, no juzgues y no conviertas la reflexión en una evaluación. '
        'Si el día fue difícil, ayuda a pensar sin culpa; si fue bien, permite '
        'identificar qué desea mantener. Tras la tercera respuesta, ofrece una '
        'síntesis breve y deja la conversación abierta. Un día sin reflexión no '
        'es un error ni un incumplimiento.',
      );
    }

    // Nada real todavía: no mandamos contexto.
    if (partes.isEmpty) return null;
    return partes.join('\n\n');
  }

  /// Resume Mi diario: el día de hoy, los últimos semáforos y las últimas
  /// reflexiones. Devuelve null si el diario está vacío.
  Future<String?> _construirContextoDiario() async {
    final store = DiarioStore.instance;
    try {
      await store.cargar();
    } catch (_) {
      return null;
    }

    final hoy = EntradaDiario.claveFecha(DateTime.now());
    final lineas = <String>[];

    final h = store.de(hoy);
    if (h != null && h.tieneAlgo) {
      final p = <String>[];
      if (h.prioridad.isNotEmpty) p.add('prioridad: ${_recortar(h.prioridad, max: 120)}');
      if (h.semaforo.isNotEmpty) p.add('semáforo: ${nombreDeSemaforo(h.semaforo)}');
      if (h.energia > 0) p.add('energía: ${kNivelesEnergia[h.energia - 1]}');
      if (h.estado > 0) p.add('estado emocional: ${kNivelesEstado[h.estado - 1]}');
      if (h.reflexion.isNotEmpty) p.add('reflexión: ${_recortar(h.reflexion, max: 250)}');
      if (p.isNotEmpty) lineas.add('Hoy: ${p.join('; ')}.');
    }

    final anteriores = store.entradas.where((e) => e.fecha.compareTo(hoy) < 0).toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));

    final semaforos = anteriores.where((e) => e.semaforo.isNotEmpty).take(7).toList();
    if (semaforos.isNotEmpty) {
      lineas.add(
        'Semáforos de días anteriores (del más reciente): '
        '${semaforos.map((e) => '${e.fecha} ${nombreDeSemaforo(e.semaforo)}').join(', ')}.',
      );
    }

    for (final e in anteriores.where((e) => e.reflexion.isNotEmpty).take(3)) {
      lineas.add('Reflexión del ${e.fecha}: ${_recortar(e.reflexion, max: 200)}');
    }

    if (lineas.isEmpty) return null;
    return 'Mi diario del usuario (el método usa un semáforo diario: Bien, '
        'Atención y Riesgo; un día en rojo no es un fracaso). Úsalo como '
        'contexto, sin repetirlo textualmente.\n${lineas.join('\n')}';
  }

  /// Resume las tareas PENDIENTES agrupadas por cuadrante, para que el
  /// agente pueda ayudar a priorizar. Limita cantidad y largo para no
  /// inflar el prompt. Devuelve null si no hay tareas.
  Future<String?> _construirContextoTareas() async {
    try {
      await TasksService.instance.cargar();
    } catch (_) {
      return null;
    }
    final todas = TasksService.instance.tasks;
    final pendientes = todas.where((t) => !t.done).toList();
    if (pendientes.isEmpty) return null;

    const grupos = <String, String>{
      'urgenteImportante': 'Hazlo ya (urgente e importante)',
      'importanteNoUrgente': 'Planifícalo (importante, no urgente)',
      'urgenteNoImportante': 'Delégalo (urgente, no importante)',
      'niUrgenteNiImportante': 'Elimínalo (ni urgente ni importante)',
    };
    const maxPorGrupo = 10;

    String lista(List<String> titulos) {
      final mostrados = titulos.take(maxPorGrupo).map((t) => _recortar(t, max: 80));
      final resto = titulos.length - maxPorGrupo;
      return mostrados.join('; ') + (resto > 0 ? ' (y $resto más)' : '');
    }

    final lineas = <String>[];
    grupos.forEach((clave, etiqueta) {
      final titulos =
          pendientes.where((t) => t.cuadrante == clave).map((t) => t.title).toList();
      if (titulos.isNotEmpty) lineas.add('$etiqueta: ${lista(titulos)}');
    });
    final sinClasificar = pendientes        .where((t) => !grupos.containsKey(t.cuadrante))
        .map((t) => t.title)
        .toList();
    if (sinClasificar.isNotEmpty) {
      lineas.add('Sin clasificar: ${lista(sinClasificar)}');
    }

    final hechas = todas.length - pendientes.length;
    return 'Tareas pendientes del usuario (${pendientes.length}), por '
        'cuadrante de la Matriz de Eisenhower (método NEUROPLAN). '
        'Completadas: $hechas.\n${lineas.join('\n')}';
  }

  /// Limita el largo de textos libres para no inflar el prompt.
  String _recortar(String texto, {int max = 300}) {
    final limpio = texto.trim().replaceAll(RegExp(r'\s+'), ' ');
    return limpio.length <= max ? limpio : '${limpio.substring(0, max)}…';
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _agoraMotionController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    ReflexionService.instance.senal.removeListener(_alSolicitarReflexion);
    VoiceService.stopSpeaking();
    VoiceService.stopListening();
    super.dispose();
  }

  void _openHistoryDrawer() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        const Text(
                          'Historial de chats',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () async {
                            Navigator.pop(context);
                            await _startNewChat();
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Nuevo'),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: _conversations.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('Aún no tienes conversaciones.'),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: _conversations.length,
                            itemBuilder: (context, index) {
                              final conv = _conversations[index];
                              final isSelected = _current?.id == conv.id;
                              return ListTile(
                                leading: Icon(
                                  Icons.chat_bubble_outline,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                                title: Text(
                                  conv.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${conv.messages.length} mensajes',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20),
                                  onPressed: () async {
                                    await _deleteConversation(conv);
                                    setModalState(() {});
                                  },
                                ),
                                onTap: () => _selectConversation(conv),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAgoraPresence(ColorScheme scheme) {
    return ValueListenableBuilder<bool>(
      valueListenable: VoiceService.isSpeaking,
      builder: (context, hablando, _) {
        final escuchando = _isListening;
        final pensando = _isLoading && !hablando && !escuchando;
        final activo = hablando || escuchando || pensando;
        final diametro = hablando ? 112.0 : (escuchando ? 86.0 : (pensando ? 70.0 : 58.0));
        final alto = hablando ? 166.0 : 116.0;
        final colorPulso = hablando
            ? const Color(0xFFB794F6)
            : escuchando
                ? const Color(0xFF67E8F9)
                : pensando
                    ? const Color(0xFF818CF8)
                    : const Color(0xFF6366F1);
        final estado = hablando
            ? 'Ágora está hablando'
            : escuchando
                ? 'Ágora te está escuchando'
                : pensando
                    ? 'Ágora está pensando'
                    : 'Ágora está aquí';
        final detalle = hablando
            ? 'Una idea toma forma y llega hasta ti'
            : escuchando
                ? 'Tómate tu tiempo. Estoy contigo'
                : pensando
                    ? 'Estoy conectando lo que me cuentas'
                    : 'Cuando quieras, podemos conversar';
        final icono = hablando
            ? Icons.graphic_eq_rounded
            : escuchando
                ? Icons.hearing_rounded
                : pensando
                    ? Icons.auto_awesome_rounded
                    : Icons.blur_on_rounded;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeInOutCubic,
          height: alto,
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Órbita viva: movimiento continuo incluso cuando Ágora está en reposo.
              AnimatedBuilder(
                animation: _agoraMotionController,
                builder: (context, _) {
                  final t = _agoraMotionController.value * math.pi * 2;
                  return Transform.rotate(
                    angle: t * 0.22,
                    child: SizedBox(
                      width: 226,
                      height: 142,
                      child: Stack(
                        children: [
                          Positioned(
                            top: 5 + math.sin(t) * 5,
                            left: 26,
                            child: _agoraOrbitDot(const Color(0xFF67E8F9), 0.72, 5),
                          ),
                          Positioned(
                            right: 18,
                            top: 52 + math.cos(t * 1.2) * 8,
                            child: _agoraOrbitDot(const Color(0xFFA78BFA), 0.82, 7),
                          ),
                          Positioned(
                            bottom: 8 + math.sin(t * 0.8) * 6,
                            left: 70,
                            child: _agoraOrbitDot(const Color(0xFF38BDF8), 0.68, 4),
                          ),
                          Positioned(
                            bottom: 20,
                            right: 52 + math.cos(t) * 7,
                            child: _agoraOrbitDot(const Color(0xFFC4B5FD), 0.55, 3.5),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeInOut,
                width: hablando ? 196 : (escuchando ? 154 : (pensando ? 132 : 112)),
                height: hablando ? 144 : (escuchando ? 108 : (pensando ? 92 : 76)),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      colorPulso.withValues(alpha: hablando ? 0.25 : (activo ? 0.16 : 0.10)),
                      const Color(0xFF22D3EE).withValues(alpha: activo ? 0.075 : 0.035),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeInOutCubic,
                width: diametro + (hablando ? 38 : (escuchando ? 30 : 22)),
                height: diametro + (hablando ? 38 : (escuchando ? 30 : 22)),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorPulso.withValues(alpha: activo ? 0.30 : 0.13),
                    width: hablando ? 1.5 : 1,
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeInOutCubic,
                top: hablando ? 15 : (escuchando ? 25 : 31),
                right: hablando ? 92 : (escuchando ? 106 : 116),
                child: _agoraOrbitDot(colorPulso, activo ? 0.92 : 0.38, hablando ? 7 : 5),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 750),
                curve: Curves.easeInOutCubic,
                bottom: hablando ? 18 : (escuchando ? 26 : 32),
                left: hablando ? 92 : (escuchando ? 106 : 116),
                child: _agoraOrbitDot(
                  const Color(0xFF22D3EE),
                  activo ? 0.78 : 0.30,
                  escuchando ? 7 : 5,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedScale(
                    scale: hablando ? 1.06 : (escuchando ? 1.02 : (pensando ? 0.98 : 0.94)),
                    duration: const Duration(milliseconds: 650),
                    curve: Curves.easeInOutCubic,
                    child: AnimatedRotation(
                      turns: pensando ? 0.025 : (hablando ? -0.012 : 0),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeInOut,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 650),
                        curve: Curves.easeInOutCubic,
                        width: diametro,
                        height: diametro,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            center: const Alignment(-0.34, -0.42),
                            radius: 0.96,
                            colors: hablando
                                ? const [
                                    Color(0xFFF5F3FF),
                                    Color(0xFFA78BFA),
                                    Color(0xFF6366F1),
                                    Color(0xFF312E81),
                                  ]
                                : escuchando
                                    ? const [
                                        Color(0xFFE0FBFF),
                                        Color(0xFF67E8F9),
                                        Color(0xFF6366F1),
                                        Color(0xFF312E81),
                                      ]
                                    : const [
                                        Color(0xFFCCFBFF),
                                        Color(0xFF38BDF8),
                                        Color(0xFF6366F1),
                                        Color(0xFF312E81),
                                      ],
                            stops: const [0.0, 0.30, 0.70, 1.0],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colorPulso.withValues(alpha: hablando ? 0.42 : (activo ? 0.30 : 0.18)),
                              blurRadius: hablando ? 42 : 28,
                              spreadRadius: hablando ? 7 : (activo ? 3 : 1),
                            ),
                            BoxShadow(
                              color: const Color(0xFF8B5CF6).withValues(alpha: hablando ? 0.30 : 0.13),
                              blurRadius: hablando ? 48 : 28,
                            ),
                          ],
                          border: Border.all(
                            color: Colors.white.withValues(alpha: hablando ? 0.82 : 0.50),
                            width: hablando ? 1.8 : 1.1,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              top: diametro * 0.19,
                              left: diametro * 0.23,
                              child: Container(
                                width: diametro * 0.22,
                                height: diametro * 0.12,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(99),
                                  color: Colors.white.withValues(alpha: 0.32),
                                ),
                              ),
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 320),
                              switchInCurve: Curves.easeOutBack,
                              switchOutCurve: Curves.easeIn,
                              transitionBuilder: (child, animation) => ScaleTransition(
                                scale: animation,
                                child: FadeTransition(opacity: animation, child: child),
                              ),
                              child: Icon(
                                icono,
                                key: ValueKey<String>(estado),
                                size: hablando ? 34 : (escuchando ? 30 : 25),
                                color: const Color(0xFF172554).withValues(alpha: 0.82),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: activo ? 0.98 : 0.72),
                      fontSize: hablando ? 12.5 : 11.5,
                      fontWeight: hablando || escuchando ? FontWeight.w600 : FontWeight.w500,
                      letterSpacing: 0.35,
                    ),
                    child: Text(estado),
                  ),
                  const SizedBox(height: 3),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: Text(
                      detalle,
                      key: ValueKey<String>(detalle),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: activo ? 0.70 : 0.48),
                        fontSize: 10.5,
                        letterSpacing: 0.12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _agoraOrbitDot(Color color, double opacity, double size) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: opacity),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: opacity * 0.55),
            blurRadius: size * 2.2,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  Widget _headerAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 19),
        style: IconButton.styleFrom(
          foregroundColor: color ?? Colors.white.withValues(alpha: 0.86),
          backgroundColor: Colors.white.withValues(alpha: 0.055),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.075)),
          ),
          fixedSize: const Size(42, 42),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildImmersiveVoice(ColorScheme scheme) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ValueListenableBuilder<bool>(
              valueListenable: VoiceService.isSpeaking,
              builder: (context, speaking, _) => AnimatedBuilder(
                animation: _agoraMotionController,
                builder: (context, _) => CustomPaint(
                  painter: _AgoraConstellationPainter(
                    progress: _agoraMotionController.value,
                    active: speaking || _isListening || _isLoading,
                    speaking: speaking,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Center(
            child: ValueListenableBuilder<bool>(
              valueListenable: VoiceService.isSpeaking,
              builder: (context, speaking, _) {
                final listening = _isListening;
                final thinking = _isLoading && !speaking && !listening;
                final color = speaking
                    ? const Color(0xFFA78BFA)
                    : listening
                        ? const Color(0xFF67E8F9)
                        : const Color(0xFF818CF8);
                final size = speaking ? 190.0 : listening ? 158.0 : thinking ? 142.0 : 128.0;
                return AnimatedBuilder(
                  animation: _agoraMotionController,
                  builder: (context, _) {
                    final t = _agoraMotionController.value * math.pi * 2;
                    return SizedBox(
                      width: 300,
                      height: 330,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: size + 82,
                            height: size + 82,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  color.withValues(alpha: speaking ? 0.20 : 0.11),
                                  const Color(0xFF6366F1).withValues(alpha: 0.06),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          Transform.rotate(
                            angle: t * 0.20,
                            child: Container(
                              width: size + 54,
                              height: size + 54,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: color.withValues(alpha: 0.30),
                                  width: 1.1,
                                ),
                              ),
                            ),
                          ),
                          Transform.rotate(
                            angle: -t * 0.13,
                            child: Container(
                              width: size + 26,
                              height: size + 26,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF67E8F9).withValues(alpha: 0.18),
                                  width: 0.8,
                                ),
                              ),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 650),
                            curve: Curves.easeInOutCubic,
                            width: size,
                            height: size,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                center: const Alignment(-0.34, -0.42),
                                colors: speaking
                                    ? const [Color(0xFFF5F3FF), Color(0xFFA78BFA), Color(0xFF6366F1), Color(0xFF312E81)]
                                    : listening
                                        ? const [Color(0xFFE0FBFF), Color(0xFF67E8F9), Color(0xFF6366F1), Color(0xFF312E81)]
                                        : const [Color(0xFFCCFBFF), Color(0xFF38BDF8), Color(0xFF6366F1), Color(0xFF312E81)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: speaking ? 0.52 : 0.30),
                                  blurRadius: speaking ? 62 : 42,
                                  spreadRadius: speaking ? 12 : 5,
                                ),
                                BoxShadow(
                                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.24),
                                  blurRadius: 70,
                                ),
                              ],
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.78),
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                speaking
                                    ? Icons.graphic_eq_rounded
                                    : listening
                                        ? Icons.hearing_rounded
                                        : Icons.auto_awesome_rounded,
                                color: const Color(0xFF172554).withValues(alpha: 0.78),
                                size: speaking ? 42 : 34,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 42 + math.sin(t) * 9,
                            left: 38,
                            child: _agoraOrbitDot(const Color(0xFF67E8F9), 0.85, 7),
                          ),
                          Positioned(
                            right: 32,
                            top: 92 + math.cos(t * 1.2) * 10,
                            child: _agoraOrbitDot(const Color(0xFFA78BFA), 0.90, 8),
                          ),
                          Positioned(
                            bottom: 48 + math.sin(t * 0.8) * 8,
                            left: 58,
                            child: _agoraOrbitDot(const Color(0xFF38BDF8), 0.78, 5),
                          ),
                          Positioned(
                            bottom: 60,
                            right: 58 + math.cos(t) * 8,
                            child: _agoraOrbitDot(const Color(0xFFC4B5FD), 0.68, 4),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 28,
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _immersiveControl(
                  icon: _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                  tooltip: _isListening ? 'Terminar de hablar' : 'Hablar con Ágora',
                  color: _isListening ? const Color(0xFFF87171) : const Color(0xFF67E8F9),
                  onPressed: _isLoading || VoiceService.isSpeaking.value
                      ? null
                      : _toggleDictado,
                ),
                const SizedBox(width: 22),
                _immersiveControl(
                  icon: Icons.stop_circle_outlined,
                  tooltip: 'Detener la voz',
                  onPressed: VoiceService.isSpeaking.value
                      ? VoiceService.stopSpeaking
                      : null,
                ),
                const SizedBox(width: 22),
                _immersiveControl(
                  icon: Icons.chat_bubble_outline_rounded,
                  tooltip: 'Volver al chat escrito',
                  onPressed: () {
                    if (_isListening) VoiceService.stopListening();
                    VoiceService.stopSpeaking();
                    setState(() {
                      _isListening = false;
                      _immersiveVoiceMode = false;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _immersiveControl({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    Color color = Colors.white,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 25),
        color: color,
        disabledColor: Colors.white.withValues(alpha: 0.24),
        style: IconButton.styleFrom(
          fixedSize: const Size(62, 62),
          backgroundColor: Colors.white.withValues(alpha: 0.065),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final messages = _current?.messages ?? [];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: _immersiveVoiceMode,
        title: _immersiveVoiceMode ? const SizedBox.shrink() : const Text(
          'NEUROPLAN',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: _immersiveVoiceMode ? Colors.transparent : null,
        actions: _immersiveVoiceMode ? [
          _headerAction(
            icon: Icons.chat_bubble_outline_rounded,
            tooltip: 'Volver al chat escrito',
            onPressed: () {
              if (_isListening) VoiceService.stopListening();
              VoiceService.stopSpeaking();
              setState(() {
                _isListening = false;
                _immersiveVoiceMode = false;
              });
            },
          ),
          const SizedBox(width: 8),
        ] : [
          _headerAction(
            icon: Icons.history_rounded,
            tooltip: 'Historial',
            onPressed: _loadingHistory ? null : _openHistoryDrawer,
          ),
          _headerAction(
            icon: Icons.add_comment_rounded,
            tooltip: 'Nuevo chat',
            onPressed: _loadingHistory ? null : _startNewChat,
          ),
          _headerAction(
            icon: _voiceReplyEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            tooltip: _voiceReplyEnabled
                ? 'Ágora habla: toca para silenciar'
                : 'Activar la voz de Ágora',
            onPressed: _toggleVoiceReply,
            color: _voiceReplyEnabled ? const Color(0xFF67E8F9) : AppColors.textoTenue,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _immersiveVoiceMode
          ? _buildImmersiveVoice(scheme)
          : Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ValueListenableBuilder<bool>(
                valueListenable: VoiceService.isSpeaking,
                builder: (context, speaking, _) {
                  final active = speaking || _isListening || _isLoading;
                  return AnimatedBuilder(
                    animation: _agoraMotionController,
                    builder: (context, _) => CustomPaint(
                      painter: _AgoraConstellationPainter(
                        progress: _agoraMotionController.value,
                        active: active,
                        speaking: speaking,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Column(
            children: [
          if (_reflexionFecha != null) _bannerReflexion(scheme),
          Expanded(
            child: _loadingHistory
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      scheme.primary.withValues(alpha: 0.25),
                                      scheme.primary.withValues(alpha: 0.05),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Icon(Icons.auto_awesome_rounded,
                                    color: scheme.primary, size: 34),
                              ),
                              const SizedBox(height: 22),
                              const Text(
                                'Soy Ágora, tu asistente de\ninteligencia artificial',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Te acompaño en tu organización y en cada etapa de NEUROPLAN, a tu ritmo. Escríbeme o háblame cuando quieras.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 14,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Soy una IA y puedo equivocarme. No soy psicólogo ni otro profesional de la salud: si estás pasando por algo difícil, busca también a una persona de confianza o a un profesional.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 12.5,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Puedes escribirme hasta 30 mensajes al día.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.66),
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          if (msg.role == 'system') return const SizedBox.shrink();
                          final isUser = msg.role == 'user';
                          return Align(
                            alignment: isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 5),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.78,
                              ),
                              decoration: BoxDecoration(
                                gradient: isUser
                                    ? LinearGradient(
                                        colors: [
                                          scheme.primary,
                                          scheme.primary.withValues(alpha: 0.75),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                color: isUser ? null : scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(18),
                                  topRight: const Radius.circular(18),
                                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                                  bottomRight: Radius.circular(isUser ? 4 : 18),
                                ),
                              ),
                              child: Text(
                                msg.content,
                                style: TextStyle(
                                  color: isUser
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.9),
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          if (_proponerInicioCiclo &&
              _current?.title == 'Diagnóstico inicial')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(                      children: [
                        Icon(Icons.auto_awesome_rounded, color: scheme.primary),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Una propuesta de Ágora',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _esPrimerCiclo
                          ? 'Hemos terminado este primer reconocimiento. Si estás de acuerdo, podemos comenzar tu primer ciclo de 30 días. Tú decides cuándo iniciar; tus registros anteriores seguirán conservados como historia.'
                          : 'Si estás de acuerdo, podemos comenzar un nuevo ciclo de 30 días. Tu recorrido anterior seguirá conservado como historia.',
                      style: TextStyle(fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _iniciandoCiclo ? null : _confirmarInicioCiclo,
                        icon: _iniciandoCiclo
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.play_arrow_rounded),
                        label: Text(_iniciandoCiclo
                            ? 'Iniciando…'
                            : (_esPrimerCiclo ? 'Comenzar mi primer ciclo' : 'Comenzar un nuevo ciclo')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Focus(
                        // En el computador, Enter envía y Shift+Enter baja de
                        // línea. En el teléfono, Enter sigue siendo línea nueva.
                        onKeyEvent: (node, event) {
                          final esEnter =
                              event.logicalKey == LogicalKeyboardKey.enter ||
                                  event.logicalKey == LogicalKeyboardKey.numpadEnter;
                          final esTelefono =
                              defaultTargetPlatform == TargetPlatform.android ||
                                  defaultTargetPlatform == TargetPlatform.iOS;
                          if (!esEnter ||
                              esTelefono ||
                              HardwareKeyboard.instance.isShiftPressed ||
                              !_controller.value.composing.isCollapsed) {
                            return KeyEventResult.ignored;
                          }
                          if (event is KeyDownEvent && !_isLoading) {
                            _sendMessage();
                          }
                          return KeyEventResult.handled;
                        },
                        child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 5,
                        style: const TextStyle(fontSize: 14.5),
                        decoration: InputDecoration(
                          hintText: _isListening ? 'Te escucho...' : 'Escribe un mensaje...',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.62),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                        onChanged: (_) {
                          // Si escribes o corriges a mano, el dictado se
                          // detiene para no pisar tus cambios.
                          if (_isListening) {
                            _sesionDictado++;
                            setState(() => _isListening = false);
                            VoiceService.stopListening();
                          }
                        },
                        onSubmitted: (_) => _sendMessage(),
                      ),
                      ),
                    ),
                    IconButton(
                      tooltip: _isListening ? 'Terminar de dictar' : 'Dictar con la voz',
                      onPressed: _isLoading ? null : _toggleDictado,
                      icon: Icon(
                        _isListening ? Icons.stop_rounded : Icons.mic_none_rounded,
                        color: _isListening ? Colors.redAccent : const Color(0xFF67E8F9),
                        size: 21,
                      ),
                      style: IconButton.styleFrom(
                        fixedSize: const Size(44, 44),
                        backgroundColor: _isListening
                            ? Colors.redAccent.withValues(alpha: 0.13)
                            : const Color(0xFF22D3EE).withValues(alpha: 0.09),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: BorderSide(
                            color: _isListening
                                ? Colors.redAccent.withValues(alpha: 0.35)
                                : const Color(0xFF22D3EE).withValues(alpha: 0.20),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF22D3EE), Color(0xFF6366F1), Color(0xFF8B5CF6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.30),
                              blurRadius: 16,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: IconButton(
                          tooltip: 'Enviar mensaje',
                          onPressed: _isLoading ? null : () => _sendMessage(),
                          style: IconButton.styleFrom(
                            fixedSize: const Size(46, 46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.30)),
                            ),
                          ),
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.arrow_upward_rounded,
                                  color: Colors.white, size: 21),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
          ),
        ],
      ),
    );
  }
}

/// Fondo permanente de Ágora: una constelación tenue que permanece detrás
/// de los mensajes mientras el usuario recorre la conversación.
class _AgoraConstellationPainter extends CustomPainter {
  _AgoraConstellationPainter({
    required this.progress,
    required this.active,
    required this.speaking,
  });

  final double progress;
  final bool active;
  final bool speaking;

  static const List<Offset> _stars = [
    Offset(0.12, 0.12), Offset(0.28, 0.20), Offset(0.46, 0.10),
    Offset(0.68, 0.16), Offset(0.87, 0.10), Offset(0.18, 0.38),
    Offset(0.36, 0.46), Offset(0.58, 0.36), Offset(0.80, 0.43),
    Offset(0.10, 0.65), Offset(0.30, 0.78), Offset(0.52, 0.68),
    Offset(0.73, 0.79), Offset(0.91, 0.66), Offset(0.17, 0.91),
    Offset(0.43, 0.94), Offset(0.66, 0.91), Offset(0.88, 0.90),
  ];

  static const List<List<int>> _links = [
    [0, 1], [1, 2], [2, 3], [3, 4], [0, 5], [1, 6], [2, 7],
    [3, 8], [5, 6], [6, 7], [7, 8], [5, 9], [6, 10], [7, 11],
    [8, 13], [9, 10], [10, 11], [11, 12], [12, 13], [10, 14],
    [11, 15], [12, 16], [13, 17], [14, 15], [15, 16], [16, 17],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * math.pi * 2;
    final accent = speaking
        ? const Color(0xFFA78BFA)
        : const Color(0xFF67E8F9);
    final strength = active ? 1.0 : 0.62;
    final center = Offset(size.width * 0.50, size.height * 0.43);
    final radius = math.min(size.width, size.height) * 0.30;

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          accent.withValues(alpha: 0.075 * strength),
          const Color(0xFF6366F1).withValues(alpha: 0.035 * strength),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.7));
    canvas.drawCircle(center, radius * 1.7, glow);

    final orbPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = accent.withValues(alpha: 0.09 * strength);
    canvas.drawCircle(center, radius * (0.78 + math.sin(t) * 0.025), orbPaint);
    orbPaint
      ..strokeWidth = 0.65
      ..color = const Color(0xFF8B5CF6).withValues(alpha: 0.07 * strength);
    canvas.drawCircle(center, radius * (1.02 + math.cos(t * 0.7) * 0.025), orbPaint);

    final points = <Offset>[];
    for (var i = 0; i < _stars.length; i++) {
      final p = _stars[i];
      final drift = math.sin(t + i * 0.83) * (active ? 5.0 : 2.5);
      points.add(Offset(
        p.dx * size.width + drift,
        p.dy * size.height + math.cos(t * 0.8 + i) * (active ? 4.0 : 2.0),
      ));
    }

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = accent.withValues(alpha: 0.12 * strength);
    for (final link in _links) {
      canvas.drawLine(points[link[0]], points[link[1]], linePaint);
    }

    for (var i = 0; i < points.length; i++) {
      final pulse = 0.65 + (math.sin(t * 1.3 + i * 1.7) + 1) * 0.17;
      final nodeColor = i.isEven ? accent : const Color(0xFFA78BFA);
      final halo = Paint()
        ..color = nodeColor.withValues(alpha: 0.13 * strength * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(points[i], i % 4 == 0 ? 5 : 3.2, halo);
      final dot = Paint()
        ..color = nodeColor.withValues(alpha: 0.46 * strength * pulse);
      canvas.drawCircle(points[i], i % 4 == 0 ? 1.8 : 1.2, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _AgoraConstellationPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.active != active ||
      oldDelegate.speaking != speaking;
}