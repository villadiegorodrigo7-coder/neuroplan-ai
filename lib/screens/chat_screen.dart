import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_conversation.dart';
import '../services/gemini_service.dart';
import '../services/voice_service.dart';
import '../services/chat_history_service.dart';
import '../services/cuadernillo_service.dart';
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
  static const String _prefVoz = 'chat_voz_activada';
  bool _loadingHistory = true;

  @override
  void initState() {
    super.initState();
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

  /// Dictado: pulsa el micrófono, habla con calma y pulsa de nuevo para
  /// terminar. El texto queda en la caja para que lo revises antes de enviar.
  Future<void> _toggleDictado() async {
    if (_isListening) {
      await VoiceService.stopListening();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    _textoAntesDeDictar = _controller.text.trim();
    setState(() => _isListening = true);

    final activado = await VoiceService.startListening(
      onResult: (texto, esFinal) {
        if (!mounted) return;
        final base = _textoAntesDeDictar;
        final unido = base.isEmpty ? texto : '$base $texto';
        _controller.text = unido;
        _controller.selection = TextSelection.collapsed(offset: unido.length);
        if (esFinal) _textoAntesDeDictar = unido;
      },
      onDone: () {
        if (mounted) setState(() => _isListening = false);
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
    setState(() {
      _conversations = list;
      _current = list.isNotEmpty ? list.first : null;
      _loadingHistory = false;
    });
  }

  Future<void> _persist() async {
    await ChatHistoryService.saveConversations(_conversations);
  }

  Future<void> _startNewChat() async {
    final conv = await ChatHistoryService.createConversation();
    setState(() {
      _conversations.insert(0, conv);
      _current = conv;
    });
    await _persist();
    if (mounted) Navigator.of(context).maybePop();
  }

  void _selectConversation(ChatConversation conv) {
    setState(() => _current = conv);
    Navigator.of(context).maybePop();
    _scrollToBottom();
  }

  Future<void> _deleteConversation(ChatConversation conv) async {
    setState(() {
      _conversations.removeWhere((c) => c.id == conv.id);
      if (_current?.id == conv.id) {
        _current = _conversations.isNotEmpty ? _conversations.first : null;
      }
    });
    await _persist();
  }

  Future<void> _sendMessage([String? voiceText]) async {
    if (_isListening) {
      await VoiceService.stopListening();
      if (mounted) setState(() => _isListening = false);
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
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();

    final contexto = await _construirContextoUsuario();

    final response = await GeminiService.sendMessage(
      text,
      history: history,
      contextoUsuario: contexto,
    );

    if (!mounted) return;
    setState(() {
      conv.messages.add(ChatMessageData(role: 'model', content: response));
      _isLoading = false;
    });
    _scrollToBottom();
    await _persist();

    if (_voiceReplyEnabled) {
      VoiceService.speak(response);
    }
  }

  /// Arma el contexto de la Etapa 1 (diagnóstico, Rueda de la Vida y
  /// consumo de tiempo) para dárselo al agente.
  ///
  /// Los valores numéricos arrancan en 5 por defecto, así que un 5 puede
  /// ser "no lo toqué" o un 5 real. Por eso:
  ///  * Etapa 1 completada  -> se envían todos los valores (ya los revisó).
  ///  * Etapa 1 en progreso -> solo se envían los valores distintos de 5
  ///    (los que seguro movió el usuario) y se avisa que son parciales.
  /// Así el agente no trata valores por defecto como si fueran de la persona.
  Future<String?> _construirContextoUsuario() async {
    final data = await CuadernilloService.cargar();
    final completa = data.etapa1Completada;

    // Devuelve "Etiqueta valor, ..." con los campos que corresponda enviar.
    String? valores(Map<String, int> campos) {
      final usados = campos.entries
          .where((e) => completa || e.value != 5)
          .map((e) => '${e.key} ${e.value}')
          .toList();
      return usados.isEmpty ? null : usados.join(', ');
    }

    final bloques = <String>[];

    // --- Diagnóstico inicial ---
    final d = data.diagnosticoInicial;
    final diag = valores({
      'Energía': d.energia,
      'Estrés': d.estres,
      'Claridad mental': d.claridadMental,
      'Organización': d.organizacion,
      'Motivación': d.motivacion,
      'Satisfacción general': d.satisfaccionGeneral,
    });
    if (diag != null) bloques.add('Diagnóstico inicial (escala 0-10): $diag.');
    if (d.nota.trim().isNotEmpty) {
      bloques.add('Nota del usuario en el diagnóstico: ${_recortar(d.nota)}');
    }

    // --- Rueda de la Vida ---
    final r = data.ruedaVida;
    final rueda = valores({
      'Salud': r.salud,
      'Estudios': r.estudios,
      'Trabajo': r.trabajo,
      'Finanzas': r.finanzas,
      'Familia': r.familia,
      'Amigos': r.amigos,
      'Descanso': r.descanso,
      'Crecimiento personal': r.crecimiento,
    });
    if (rueda != null) bloques.add('Rueda de la Vida (escala 0-10): $rueda.');

    // --- Distribución / consumo de tiempo (texto libre) ---
    final t = data.consumoTiempo;
    final tiempo = <String>[
      if (t.redesSociales.trim().isNotEmpty)
        'Redes sociales: ${_recortar(t.redesSociales)}',
      if (t.distracciones.trim().isNotEmpty)
        'Distracciones: ${_recortar(t.distracciones)}',
      if (t.obligaciones.trim().isNotEmpty)
        'Obligaciones: ${_recortar(t.obligaciones)}',
      if (t.habitos.trim().isNotEmpty) 'Hábitos: ${_recortar(t.habitos)}',
    ];
    if (tiempo.isNotEmpty) {
      bloques.add('Cómo usa su tiempo el usuario. ${tiempo.join(' | ')}');
    }

    final partes = <String>[];

    if (bloques.isNotEmpty) {
      final estado = completa
          ? 'Etapa 1 del Cuadernillo completada.'
          : 'Etapa 1 del Cuadernillo en progreso: son datos PARCIALES. Lo '
              'que no aparece aquí aún no lo ha respondido; no lo des por '
              'hecho ni asumas un valor.';
      partes.add('$estado\n${bloques.join('\n')}');
    }

    // --- Tareas del usuario, por cuadrante de la Matriz de Eisenhower ---
    final tareas = await _construirContextoTareas();
    if (tareas != null) partes.add(tareas);

    // Nada real todavía: no mandamos contexto.
    if (partes.isEmpty) return null;
    return partes.join('\n\n');
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
              color: _voiceReplyEnabled ? scheme.primary : Colors.white38,
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
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 12.5,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Puedes escribirme hasta 30 mensajes al día.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.45),
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
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 5,
                        style: const TextStyle(fontSize: 14.5),
                        decoration: InputDecoration(
                          hintText: _isListening ? 'Te escucho...' : 'Escribe un mensaje...',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                        onSubmitted: (_) => _sendMessage(),
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
