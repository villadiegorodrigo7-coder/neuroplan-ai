import 'package:flutter/material.dart';

import '../services/voice_service.dart';

/// Caja de texto con micrófono: se puede escribir o dictar.
class CampoDictado extends StatefulWidget {
  const CampoDictado({
    super.key,
    required this.controller,
    required this.hint,
    this.minLines = 1,
    this.maxLines = 4,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final int minLines;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;

  @override
  State<CampoDictado> createState() => _CampoDictadoState();
}

class _CampoDictadoState extends State<CampoDictado> {
  bool _escuchando = false;
  int _sesion = 0;
  String _base = '';

  Future<void> _alternar() async {
    if (_escuchando) {
      await VoiceService.stopListening();
      if (mounted) setState(() => _escuchando = false);
      return;
    }

    await VoiceService.stopListening();
    _base = widget.controller.text.trim();
    final sesion = ++_sesion;
    setState(() => _escuchando = true);

    final activado = await VoiceService.startListening(
      onResult: (texto, esFinal) {
        // Un resultado tardío de una sesión ya cerrada se ignora.
        if (!mounted || sesion != _sesion) return;
        final unido = _base.isEmpty ? texto : '$_base $texto';
        widget.controller.text = unido;
        widget.controller.selection = TextSelection.collapsed(offset: unido.length);
        widget.onChanged?.call(unido);
        if (esFinal) _base = unido;
      },
      onDone: () {
        if (mounted && sesion == _sesion) setState(() => _escuchando = false);
      },
      onError: (_) {},
    );

    if (!activado && mounted) {
      setState(() => _escuchando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No pude activar el micrófono. Revisa el permiso del navegador, o prueba con Chrome o Edge.',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _sesion++;
    VoiceService.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: widget.controller,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      style: const TextStyle(fontSize: 14.5),
      onChanged: (v) {
        // Si escribes o corriges a mano, el dictado se detiene.
        if (_escuchando) {
          _sesion++;
          setState(() => _escuchando = false);
          VoiceService.stopListening();
        }
        widget.onChanged?.call(v);
      },
      onSubmitted: (_) => widget.onSubmitted?.call(),
      decoration: InputDecoration(
        hintText: _escuchando ? 'Te escucho...' : widget.hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        isDense: true,
        contentPadding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        suffixIcon: IconButton(
          tooltip: _escuchando ? 'Terminar de dictar' : 'Dictar con la voz',
          onPressed: _alternar,
          icon: Icon(
            _escuchando ? Icons.stop_circle_outlined : Icons.mic_none_rounded,
            color: _escuchando ? Colors.redAccent : scheme.primary,
          ),
        ),
      ),
    );
  }
}
