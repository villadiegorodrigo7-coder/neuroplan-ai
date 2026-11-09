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

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatConversation> _conversations = [];
  ChatConversation? _current;

  bool _isLoading = false;
  /// La voz de Ágora empieza apagada: solo habla si la persona activa la bocina.
  /// La elección se recuerda en este dispositivo.
  bool _voiceReplyEnabled = false;
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

  @override
  void initState() {
    super.initState();
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

  /// Dictado: pulsa el micrófono, habla con calma y pulsa de nuevo para
  /// terminar. El texto queda en la caja para que lo revises antes de enviar.
  Future<void> _toggleDictado() async {
    if (_isListening) {
      await VoiceService.stopListening();
      if (mounted) setState(() => _isListening = false);
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
        if (mounted && sesion == _sesionDictado) {
          setState(() => _isListening = false);
        }
      },
      onError: (_) {},
    );

    if (!activado && mounted) {
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
      final completo = tieneMarcador ||
          await GeminiService.diagnosticoConversacionalCompleto(historial);
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
    }

    if (_voiceReplyEnabled) {
      VoiceService.speak(response);
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

    // --- Tareas del usuario, por cuadrante de la Matriz de Eisenhower ---
    final tareas = await _construirContextoTareas();
    if (tareas != null) partes.add(tareas);

    // --- Mi diario ---
    final diario = await _construirContextoDiario();
    if (diario != null) partes.add(diario);

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
    final sinClasificar = pendientes
        .where((t) => !grupos.containsKey(t.cuadrante))
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final messages = _current?.messages ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'NEUROPLAN',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
        ),
        centerTitle: false,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Historial',
            onPressed: _loadingHistory ? null : _openHistoryDrawer,
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'Nuevo chat',
            onPressed: _loadingHistory ? null : _startNewChat,
          ),
          IconButton(
            icon: Icon(
              _voiceReplyEnabled ? Icons.volume_up : Icons.volume_off,
              color: _voiceReplyEnabled ? scheme.primary : AppColors.textoTenue,
            ),
            tooltip: _voiceReplyEnabled
                ? 'Ágora habla: toca para silenciar'
                : 'Activar la voz de Ágora',
            onPressed: _toggleVoiceReply,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_reflexionFecha != null) _bannerReflexion(scheme),
          Expanded(
            child: _loadingHistory
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
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
                        padding: const EdgeInsets.all(16),
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
                        _isListening ? Icons.stop_circle_outlined : Icons.mic_none_rounded,
                        color: _isListening ? Colors.redAccent : scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              scheme.primary,
                              scheme.primary.withValues(alpha: 0.75),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: IconButton(
                          onPressed: _isLoading ? null : () => _sendMessage(),
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
                                  color: Colors.white, size: 20),
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
    );
  }
}
