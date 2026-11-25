import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_conversation.dart';
import '../models/entrada_diario.dart';
import '../models/productividad_data.dart';
import '../services/chat_history_service.dart';
import '../services/concierto_final_service.dart';
import '../services/diario_store.dart';
import '../services/gemini_service.dart';
import '../services/herramientas_service.dart';
import '../services/tasks_service.dart';
import '../services/voice_service.dart';
import '../theme/app_theme.dart';
import '../widgets/agora_constellation_painter.dart';
import '../widgets/agora_immersive_voice.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.conciertoFinalSnapshot, this.onExit});

  final ConciertoFinalSnapshot? conciertoFinalSnapshot;

  /// Regresa a la navegación principal sin destruir el estado del chat.
  final VoidCallback? onExit;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
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

  int? _revisionSemanalSemana;

  bool _loadingHistory = true;
  bool _cerrandoConcierto = false;
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
    // Los borradores vacíos de compilaciones anteriores no son conversaciones.
    // Se ocultan sin eliminarlos de la base de datos.
    list.removeWhere(
      (c) => c.title == 'Nueva conversación' && c.messages.isEmpty,
    );

    if (!mounted) return;
    if (widget.conciertoFinalSnapshot != null) {
      _conversations = list;
      await _abrirConciertoFinalSiCorresponde();
      return;
    }

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
    final prefsSeleccion = await SharedPreferences.getInstance();
    final usuarioSeleccion =
        Supabase.instance.client.auth.currentUser?.id ?? 'local';
    final idSeleccionado = prefsSeleccion.getString(
      'agora_chat_activo_$usuarioSeleccion',
    );
    ChatConversation? conversacionInicial = revisionSemanal;
    if (conversacionInicial == null && idSeleccionado != null) {
      for (final candidata in list) {
        if (candidata.id == idSeleccionado) {
          conversacionInicial = candidata;
          break;
        }
      }
    }
    conversacionInicial ??= list.isNotEmpty ? list.first : null;

    if (!mounted) return;
    setState(() {
      _conversations = list;
      _current = conversacionInicial;
      _revisionSemanalSemana = _semanaDeRevision(conversacionInicial);
      _loadingHistory = false;
    });
    // No crear seguimientos automáticamente al abrir Ágora: la apertura
    // puede repetirse en distintas sesiones y generar conversaciones duplicadas.
    // Los seguimientos existentes permanecen disponibles en el historial.
    await _recuperarDiagnosticoCompleto();
    await _actualizarPropuestaInicioCiclo();
  }

  /// Crea o recupera la conversación especial del ciclo. El contexto queda
  /// guardado en Supabase junto con la conversación para poder retomarla.
  Future<void> _abrirConciertoFinalSiCorresponde() async {
    final snapshot = widget.conciertoFinalSnapshot;
    if (snapshot == null || !mounted) return;

    final marcaCiclo = 'CONCIERTO_FINAL_CICLO:${snapshot.ciclo.id}';
    ChatConversation? existente;
    for (final candidata in _conversations) {
      if (candidata.messages.any(
        (m) => m.role == 'system' && m.content.trim() == marcaCiclo,
      )) {
        existente = candidata;
        break;
      }
    }

    final esNueva = existente == null;
    final conv = existente ?? await ChatHistoryService.createConversation();
    conv.title = 'Concierto Final';

    final indiceContexto = conv.messages.indexWhere(
      (m) =>
          m.role == 'system' &&
          m.content.startsWith('CONCIERTO_FINAL_CONTEXTO:'),
    );
    final contextoGuardado =
        'CONCIERTO_FINAL_CONTEXTO:\n${snapshot.contextoParaAgora}';
    if (indiceContexto >= 0) {
      conv.messages[indiceContexto] = ChatMessageData(
        role: 'system',
        content: contextoGuardado,
      );
    } else {
      conv.messages.add(ChatMessageData(role: 'system', content: marcaCiclo));
      conv.messages.add(
        ChatMessageData(role: 'system', content: contextoGuardado),
      );
    }

    if (esNueva) {
      conv.messages.add(
        ChatMessageData(
          role: 'model',
          content: 'Podemos mirar juntos los momentos que marcaron este ciclo. ¿Qué te gustaría reconocer primero de tu recorrido?',
        ),
      );
      _conversations.insert(0, conv);
    }

    if (!mounted) return;
    setState(() {
      _current = conv;
      _loadingHistory = false;
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
          .map(
            (m) => {
              'role': m.role == 'user' ? 'user' : 'model',
              'content': m.content,
            },
          )
          .toList();
      final respuestasUsuario = historial
          .where((m) => m['role'] == 'user')
          .length;
      if (respuestasUsuario == 0) return;

      // La conversación puede cubrir varias preguntas en una sola respuesta.
      // No imponemos un mínimo artificial de turnos: el clasificador evalúa
      // el contenido real y el cierre integrador, no el número de mensajes.
      final tieneMarcador =
          diagnostico.diagnosticoCompleto ||
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
        completo = await GeminiService.diagnosticoConversacionalCompleto(
          historial,
        );
        await prefs.setString(claveRevision, hoy);
      }
      if (!completo) return;

      diagnostico.diagnosticoCompleto = true;
      if (!diagnostico.messages.any(
        (m) => m.role == 'system' && m.content == 'DIAGNOSTICO_COMPLETO',
      )) {
        diagnostico.messages.add(
          ChatMessageData(role: 'system', content: 'DIAGNOSTICO_COMPLETO'),
        );
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
      if (conv == null ||
          conv.title != 'Diagnóstico inicial' ||
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
          conv.messages.add(
            ChatMessageData(
              role: 'model',
              content:
                  '${_esPrimerCiclo ? 'Tu primer ciclo' : 'Tu nuevo ciclo'} de NEUROPLAN ha comenzado el $fechaTexto y tendrá una duración de 30 días. No se trata de hacerlo todo perfecto: vamos a observar tu tiempo, tu energía y aquello que quieras transformar, un día a la vez.',
            ),
          );
        }
      });
      await _persist();
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _iniciandoCiclo = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pude iniciar el ciclo. Inténtalo de nuevo.'),
        ),
      );
    }
  }

  int? _semanaDeRevision(ChatConversation? conv) {
    if (conv == null) return null;
    final match = RegExp(r'^Revisión semanal · semana (\d+)$')
        .firstMatch(conv.title);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  /// Abre una revisión al cumplirse cada periodo de siete días desde el diagnóstico.
  Future<ChatConversation?> _crearRevisionSemanalSiCorresponde(
    List<ChatConversation> list,
  ) async {
    ChatConversation? diagnostico;
    for (final conv in list) {
      if (conv.title == 'Diagnóstico inicial') {
        diagnostico = conv;
        break;
      }
    }
    if (diagnostico == null) return null;

    final ahora = DateTime.now();
    final inicio = DateTime(
      diagnostico.createdAt.year,
      diagnostico.createdAt.month,
      diagnostico.createdAt.day,
    );
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final semana = hoy.difference(inicio).inDays ~/ 7;
    if (semana < 1) return null;
    final titulo = 'Revisión semanal · semana $semana';
    if (list.any((c) => c.title == titulo)) return null;

    final conv = await ChatHistoryService.createConversation();
    conv.title = titulo;
    conv.messages.add(
      ChatMessageData(
        role: 'model',
        content:
            'Ya ha pasado una semana desde que comenzaste NEUROPLAN. '
            'Quiero que miremos cómo transcurrieron estos días teniendo presente '
            'lo que me contaste al iniciar. No es una evaluación ni una lista de '
            'cumplimientos. Empecemos por algo sencillo: ¿qué ocupó más tu tiempo '
            'y tu energía durante esta semana?',
      ),
    );
    list.insert(0, conv);
    await ChatHistoryService.saveConversations(list);
    return conv;
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
          .map(
            (m) => {
              'role': m.role == 'user' ? 'user' : 'model',
              'content': m.content,
            },
          )
          .toList();
      // Solo compartimos los antecedentes del diario con el generador:
      // las tareas pendientes no son evidencia para puntuar dimensiones vitales.
      final contextoDiario = await _construirContextoDiario();
      final propuesta = await GeminiService.proponerDiagnosticoConversacional(
        historial,
        contextoUsuario: contextoDiario,
      );
      if (propuesta == null) return;

      data.diagnosticoConversacional = DiagnosticoConversacional(
        valoresPropuestos: Map<String, int>.from(
          propuesta['valoresPropuestos'] as Map,
        ),
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

  Future<void> _recordarChatActivo(ChatConversation? conv) async {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? 'local';
    final prefs = await SharedPreferences.getInstance();
    if (conv == null) {
      await prefs.remove('agora_chat_activo_$uid');
    } else {
      await prefs.setString('agora_chat_activo_$uid', conv.id);
    }
  }

  Future<void> _startNewChat() async {
    // Una conversación vacía es un borrador, no un chat que deba
    // duplicarse o guardarse cada vez que se pulsa «Nuevo chat».
    ChatConversation? conv;
    for (final candidata in _conversations) {
      if (candidata.title == 'Nueva conversación' &&
          candidata.messages.isEmpty) {
        conv = candidata;
        break;
      }
    }
    conv ??= await ChatHistoryService.createConversation();
    if (!mounted) return;
    final yaExiste = _conversations.any((c) => c.id == conv!.id);
    setState(() {
      if (!yaExiste) _conversations.insert(0, conv!);
      _current = conv;
      _revisionSemanalSemana = null;
    });
    // El borrador solo se persiste cuando se envía el primer mensaje.
    await _recordarChatActivo(conv);
    // El historial ya se cerró desde su propio botón «Nuevo».
  }

  void _selectConversation(ChatConversation conv) {
    setState(() {
      _current = conv;
      _revisionSemanalSemana = _semanaDeRevision(conv);
    });
    _actualizarPropuestaInicioCiclo();
    _recordarChatActivo(conv);
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

  String? _cicloDeConcierto(ChatConversation? conversacion) {
    const prefijo = 'CONCIERTO_FINAL_CICLO:';
    for (final mensaje in conversacion?.messages ?? <ChatMessageData>[]) {
      if (mensaje.role == 'system' && mensaje.content.startsWith(prefijo)) {
        final id = mensaje.content.substring(prefijo.length).trim();
        if (id.isNotEmpty) return id;
      }
    }
    return null;
  }

  Widget _panelConciertoFinal(ColorScheme scheme) {
    final cerrado = _conciertoFinalYaCerrado;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            cerrado
                ? Icons.check_circle_outline_rounded
                : Icons.music_note_rounded,
            color: scheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Concierto Final',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  cerrado
                      ? 'Ciclo cerrado · Disponible en tu historial'
                      : _cierreConciertoDisponible
                      ? 'Puedes cerrar tu ciclo cuando quieras.'
                      : 'Reflexión de cierre con Ágora',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _tieneMarcaConcierto(String marca) {
    final id = _cicloDeConcierto(_current);
    return id != null &&
        _current!.messages.any(
          (m) =>
              m.role == 'system' &&
              (m.content == '$marca:$id' ||
                  (marca == 'CONCIERTO_FINAL_CIERRE_DISPONIBLE' &&
                      m.content == '$marca:')),
        );
  }

  bool get _cierreConciertoDisponible =>
      _tieneMarcaConcierto('CONCIERTO_FINAL_CIERRE_DISPONIBLE');

  bool get _conciertoFinalYaCerrado =>
      _tieneMarcaConcierto('CONCIERTO_FINAL_CERRADO');

  Future<void> _confirmarCierreConciertoFinal() async {
    final conv = _current;
    final cicloId = _cicloDeConcierto(conv);
    if (conv == null ||
        cicloId == null ||
        !_cierreConciertoDisponible ||
        _conciertoFinalYaCerrado ||
        _cerrandoConcierto ||
        _isLoading) {
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar este ciclo'),
        content: const Text(
          'La reflexión del Concierto Final quedará concluida y el recorrido '
          'se conservará en Mi Pulso. Esta decisión no elimina tus registros. '
          '¿Deseas cerrar el ciclo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Todavía no'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sí, cerrar ciclo'),
          ),
        ],
      ),
    );
    if (confirmar != true ||
        !mounted ||
        _current != conv ||
        _isLoading ||
        _cerrandoConcierto ||
        _conciertoFinalYaCerrado) {
      return;
    }

    _sesionDictado++;
    if (_isListening) VoiceService.stopListening();
    setState(() {
      _isListening = false;
      _cerrandoConcierto = true;
    });
    try {
      await HerramientasService.cerrarCiclo(cicloId);
      conv.messages.add(
        ChatMessageData(
          role: 'system',
          content: 'CONCIERTO_FINAL_CERRADO:$cicloId',
        ),
      );
      await _persist();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tu ciclo quedó cerrado. El recorrido permanece en Mi Pulso.',
          ),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Concierto Final: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar el cierre. Vuelve a intentarlo.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _cerrandoConcierto = false);
    }
  }

  Future<void> _sendMessage([String? voiceText]) async {
    if (_loadingHistory ||
        _isLoading ||
        _cerrandoConcierto ||
        _conciertoFinalYaCerrado) {
      return;
    }
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
    await _recordarChatActivo(conv);

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
      final mensajeDeContexto = _esReflexionDiaria(conv)
          ? 'Quiero hacer mi reflexión del día.'
          : _revisionSemanalSemana != null
          ? 'Quiero hacer mi revisión semanal de NEUROPLAN.'
          : conv.title == 'Diagnóstico inicial'
          ? 'Estoy comenzando el diagnóstico inicial de NEUROPLAN y respondo al saludo de Ágora.'
          : 'Quiero continuar esta conversación con Ágora.';
      history.insert(0, {'role': 'user', 'content': mensajeDeContexto});
    }

    final contexto = await _construirContextoUsuario(
      conv,
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
      if (!conv.messages.any(
        (m) => m.role == 'system' && m.content == 'DIAGNOSTICO_COMPLETO',
      )) {
        conv.messages.add(
          ChatMessageData(role: 'system', content: 'DIAGNOSTICO_COMPLETO'),
        );
      }
    }
    const marcadorCierre = '[[CONCIERTO_FINAL_CIERRE_DISPONIBLE]]';
    final cicloConcierto = _cicloDeConcierto(conv);
    if (cicloConcierto != null &&
        respuestaAgora.trimRight().endsWith(marcadorCierre)) {
      final marca = 'CONCIERTO_FINAL_CIERRE_DISPONIBLE:$cicloConcierto';
      if (!conv.messages.any((m) => m.role == 'system' && m.content == marca)) {
        conv.messages.add(ChatMessageData(role: 'system', content: marca));
      }
    }
    final response = respuestaAgora
        .replaceAll('[[DIAGNOSTICO_COMPLETO]]', '')
        .replaceAll(marcadorCierre, '')
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

  // Conserva el contexto de las reflexiones ya guardadas en el historial.
  bool _esReflexionDiaria(ChatConversation conversacion) =>
      conversacion.messages.any(
        (mensaje) =>
            mensaje.role == 'system' &&
            mensaje.content.startsWith('REFLEXION_DIARIA_FECHA:'),
      );

  Future<String?> _construirContextoUsuario(
    ChatConversation conversacionActual, {
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
    if (_cicloDeConcierto(conversacionActual) != null) {
      String? contextoConcierto;
      for (final mensaje in conversacionActual.messages) {
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
        'cualquier interpretación. La conversación debe ser cálida, honesta y sin juicios. '
        'No conviertas el Concierto Final en una lista de preguntas ni en una evaluación. '
        'Cuando la reflexión haya llegado naturalmente a una síntesis suficiente, comparte una '
        'síntesis breve y pregunta si la persona siente que desea cerrar este ciclo. Solo en ese '
        'momento, al final de tu respuesta, añade exactamente el marcador técnico '
        '[[CONCIERTO_FINAL_CIERRE_DISPONIBLE]]. No añadas ese marcador antes de haber escuchado '
        'y sintetizado el recorrido. La persona decide si cierra; nunca cierres por ella.'
        '${contextoConcierto == null ? '' : '\n\nRECORRIDO RECOPILADO PARA ESTA CONVERSACIÓN:\n$contextoConcierto'}',
      );
    }

    // --- Tareas del usuario, por cuadrante de la Matriz de Eisenhower ---
    if (_cicloDeConcierto(conversacionActual) == null) {
      final tareas = await _construirContextoTareas();
      if (tareas != null) partes.add(tareas);

      // --- Registro diario ---
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
    if (_esReflexionDiaria(conversacionActual)) {
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

  /// Resume el registro diario: el día de hoy, los últimos semáforos y las últimas
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
      if (h.prioridad.isNotEmpty) {
        p.add('prioridad: ${_recortar(h.prioridad, max: 120)}');
      }
      if (h.semaforo.isNotEmpty) {
        p.add('semáforo: ${nombreDeSemaforo(h.semaforo)}');
      }
      if (h.energia > 0) p.add('energía: ${kNivelesEnergia[h.energia - 1]}');
      if (h.estado > 0) {
        p.add('estado emocional: ${kNivelesEstado[h.estado - 1]}');
      }
      if (h.reflexion.isNotEmpty) {
        p.add('reflexión: ${_recortar(h.reflexion, max: 250)}');
      }
      if (p.isNotEmpty) lineas.add('Hoy: ${p.join('; ')}.');
    }

    final anteriores =
        store.entradas.where((e) => e.fecha.compareTo(hoy) < 0).toList()
          ..sort((a, b) => b.fecha.compareTo(a.fecha));

    final semaforos = anteriores
        .where((e) => e.semaforo.isNotEmpty)
        .take(7)
        .toList();
    if (semaforos.isNotEmpty) {
      lineas.add(
        'Semáforos de días anteriores (del más reciente): '
        '${semaforos.map((e) => '${e.fecha} ${nombreDeSemaforo(e.semaforo)}').join(', ')}.',
      );
    }

    for (final e in anteriores.where((e) => e.reflexion.isNotEmpty).take(3)) {
      lineas.add(
        'Reflexión del ${e.fecha}: ${_recortar(e.reflexion, max: 200)}',
      );
    }

    if (lineas.isEmpty) return null;
    return 'Registro diario de Mi Pulso (el método usa un semáforo diario: Bien, '
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
      final mostrados = titulos
          .take(maxPorGrupo)
          .map((t) => _recortar(t, max: 80));
      final resto = titulos.length - maxPorGrupo;
      return mostrados.join('; ') + (resto > 0 ? ' (y $resto más)' : '');
    }

    final lineas = <String>[];
    grupos.forEach((clave, etiqueta) {
      final titulos = pendientes
          .where((t) => t.cuadrante == clave)
          .map((t) => t.title)
          .toList();
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
    _agoraMotionController.dispose();
    _controller.dispose();
    _scrollController.dispose();
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
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
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
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                  ),
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

  void _salirDeVozInmersiva() {
    if (_isListening) VoiceService.stopListening();
    VoiceService.stopSpeaking();
    setState(() {
      _isListening = false;
      _immersiveVoiceMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading:
            !_immersiveVoiceMode && widget.conciertoFinalSnapshot != null,
        leading: !_immersiveVoiceMode && widget.onExit != null
            ? IconButton(
                tooltip: 'Volver a NEUROPLAN',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: widget.onExit,
              )
            : null,
        title: _immersiveVoiceMode
            ? const SizedBox.shrink()
            : const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ágora',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  Text(
                    'NEUROPLAN AI',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.8,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: _immersiveVoiceMode ? Colors.transparent : null,
        actions: _immersiveVoiceMode
            ? [
                _headerAction(
                  icon: Icons.chat_bubble_outline_rounded,
                  tooltip: 'Volver al chat escrito',
                  onPressed: _salirDeVozInmersiva,
                ),
                const SizedBox(width: 8),
              ]
            : [
                _headerAction(
                  icon: Icons.history_rounded,
                  tooltip: 'Historial',
                  onPressed: _loadingHistory || _cerrandoConcierto
                      ? null
                      : _openHistoryDrawer,
                ),
                _headerAction(
                  icon: Icons.add_comment_rounded,
                  tooltip: 'Nuevo chat',
                  onPressed: _loadingHistory || _cerrandoConcierto
                      ? null
                      : _startNewChat,
                ),
                _headerAction(
                  icon: _voiceReplyEnabled
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  tooltip: _voiceReplyEnabled
                      ? 'Ágora habla: toca para silenciar'
                      : 'Activar la voz de Ágora',
                  onPressed: _toggleVoiceReply,
                  color: _voiceReplyEnabled
                      ? const Color(0xFF67E8F9)
                      : AppColors.textoTenue,
                ),
                const SizedBox(width: 8),
              ],
      ),
      body: _immersiveVoiceMode
          ? AgoraImmersiveVoice(
              animation: _agoraMotionController,
              isListening: _isListening,
              isLoading: _isLoading,
              onToggleDictation: _toggleDictado,
              onExit: _salirDeVozInmersiva,
            )
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
                            painter: AgoraConstellationPainter(
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
                    if (_cicloDeConcierto(_current) != null)
                      _panelConciertoFinal(scheme),
                    Expanded(child: _contenidoConversacion(scheme)),
                    if (_cierreConciertoDisponible && !_conciertoFinalYaCerrado)
                      SafeArea(
                        top: false,
                        bottom: false,
                        minimum: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _isLoading || _cerrandoConcierto
                                ? null
                                : _confirmarCierreConciertoFinal,
                            icon: _cerrandoConcierto
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.check_circle_outline_rounded,
                                  ),
                            label: Text(
                              _cerrandoConcierto
                                  ? 'Guardando…'
                                  : 'Cerrar mi ciclo',
                            ),
                          ),
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
                            border: Border.all(
                              color: scheme.primary.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.auto_awesome_rounded,
                                    color: scheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Una propuesta de Ágora',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _esPrimerCiclo
                                    ? 'Hemos terminado este primer reconocimiento. Si estás de acuerdo, podemos comenzar tu primer ciclo de 30 días. Tú decides cuándo iniciar; tus registros anteriores seguirán conservados como historia.'
                                    : 'Si estás de acuerdo, podemos comenzar un nuevo ciclo de 30 días. Tu recorrido anterior seguirá conservado como historia.',
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _iniciandoCiclo
                                      ? null
                                      : _confirmarInicioCiclo,
                                  icon: _iniciandoCiclo
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.play_arrow_rounded),
                                  label: Text(
                                    _iniciandoCiclo
                                        ? 'Iniciando…'
                                        : (_esPrimerCiclo
                                              ? 'Comenzar mi primer ciclo'
                                              : 'Comenzar un nuevo ciclo'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (!_loadingHistory && !_conciertoFinalYaCerrado)
                      _editorMensaje(scheme),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _contenidoConversacion(ColorScheme scheme) {
    if (_loadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    final messages = _current?.messages ?? [];
    if (messages.isEmpty) return _bienvenidaAgora(scheme);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        if (msg.role == 'system') return const SizedBox.shrink();
        final isUser = msg.role == 'user';
        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
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
              color: isUser
                  ? null
                  : scheme.surfaceContainerHighest.withValues(alpha: 0.86),
              border: Border.all(
                color: isUser
                    ? Colors.white.withValues(alpha: 0.10)
                    : const Color(0xFF8B5CF6).withValues(alpha: 0.16),
              ),
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
    );
  }

  Widget _bienvenidaAgora(ColorScheme scheme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.34),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.18),
                    blurRadius: 36,
                    spreadRadius: 5,
                  ),
                ],
                gradient: LinearGradient(
                  colors: [
                    scheme.primary.withValues(alpha: 0.25),
                    scheme.primary.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: scheme.primary,
                size: 34,
              ),
            ),
            const SizedBox(height: 26),
            const Text(
              'Un espacio para pensar,\norganizar y avanzar',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                height: 1.2,
                letterSpacing: -0.45,
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
    );
  }

  Widget _editorMensaje(ColorScheme scheme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.28),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
            ],
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
                      hintText: _isListening
                          ? 'Te escucho...'
                          : 'Escribe un mensaje...',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
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
                tooltip: _isListening
                    ? 'Terminar de dictar'
                    : 'Dictar con la voz',
                onPressed: _isLoading ? null : _toggleDictado,
                icon: Icon(
                  _isListening ? Icons.stop_rounded : Icons.mic_none_rounded,
                  color: _isListening
                      ? Colors.redAccent
                      : const Color(0xFF67E8F9),
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
                      colors: [
                        Color(0xFF22D3EE),
                        Color(0xFF6366F1),
                        Color(0xFF8B5CF6),
                      ],
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
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.30),
                        ),
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
                        : const Icon(
                            Icons.arrow_upward_rounded,
                            color: Colors.white,
                            size: 21,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
