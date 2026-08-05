import 'package:flutter/material.dart';
import '../models/chat_conversation.dart';
import '../services/gemini_service.dart';
import '../services/voice_service.dart';
import '../services/chat_history_service.dart';

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
  bool _isListening = false;
  bool _voiceReplyEnabled = true;
  bool _loadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
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

    final history = conv.messages
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();

    final response = await GeminiService.sendMessage(text, history: history);

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

  Future<void> _toggleListening() async {
    if (_isListening) {
      await VoiceService.stopListening();
      setState(() => _isListening = false);
      return;
    }

    final available = await VoiceService.initSpeech();
    if (!available) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo activar el micrófono. Revisa los permisos.')),
      );
      return;
    }

    setState(() => _isListening = true);
    VoiceService.startListening(
      onResult: (text) {
        if (text.trim().isNotEmpty) {
          _sendMessage(text);
        }
      },
      onDone: () {
        if (mounted) setState(() => _isListening = false);
      },
    );
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
    VoiceService.stopListening();
    VoiceService.stopSpeaking();
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
            tooltip: 'Respuesta por voz',
            onPressed: () {
              setState(() => _voiceReplyEnabled = !_voiceReplyEnabled);
              if (!_voiceReplyEnabled) VoiceService.stopSpeaking();
            },
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
                                'Escríbeme o háblame y te\nayudo a organizar tu día',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Si no has configurado tu API key,\nve a la pestaña Perfil.',
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
          if (_isListening)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'Escuchando...',
                style: TextStyle(
                    color: scheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
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
                    IconButton(
                      onPressed: _toggleListening,
                      icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_none_rounded,
                        color: _isListening
                            ? Colors.redAccent
                            : Colors.white.withValues(alpha: 0.55),
                      ),
                      tooltip: 'Hablar',
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 5,
                        style: const TextStyle(fontSize: 14.5),
                        decoration: InputDecoration(
                          hintText: 'Escribe un mensaje...',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 4),
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
