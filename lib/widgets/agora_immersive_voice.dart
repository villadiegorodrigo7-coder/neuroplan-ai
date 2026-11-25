import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/voice_service.dart';
import 'agora_constellation_painter.dart';

class AgoraImmersiveVoice extends StatelessWidget {
  const AgoraImmersiveVoice({
    super.key,
    required this.animation,
    required this.isListening,
    required this.isLoading,
    required this.onToggleDictation,
    required this.onExit,
  });

  final Animation<double> animation;
  final bool isListening;
  final bool isLoading;
  final VoidCallback onToggleDictation;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ValueListenableBuilder<bool>(
              valueListenable: VoiceService.isSpeaking,
              builder: (context, speaking, _) => AnimatedBuilder(
                animation: animation,
                builder: (context, _) => CustomPaint(
                  painter: AgoraConstellationPainter(
                    progress: animation.value,
                    active: speaking || isListening || isLoading,
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
                final listening = isListening;
                final thinking = isLoading && !speaking && !listening;
                final color = speaking
                    ? const Color(0xFFA78BFA)
                    : listening
                    ? const Color(0xFF67E8F9)
                    : const Color(0xFF818CF8);
                final size = speaking
                    ? 190.0
                    : listening
                    ? 158.0
                    : thinking
                    ? 142.0
                    : 128.0;
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, _) {
                    final t = animation.value * math.pi * 2;
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
                                  color.withValues(
                                    alpha: speaking ? 0.20 : 0.11,
                                  ),
                                  const Color(0xFF6366F1)
                                      .withValues(alpha: 0.06),
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
                                  color: const Color(0xFF67E8F9)
                                      .withValues(alpha: 0.18),
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
                                    ? const [
                                        Color(0xFFF5F3FF),
                                        Color(0xFFA78BFA),
                                        Color(0xFF6366F1),
                                        Color(0xFF312E81),
                                      ]
                                    : listening
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
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(
                                    alpha: speaking ? 0.52 : 0.30,
                                  ),
                                  blurRadius: speaking ? 62 : 42,
                                  spreadRadius: speaking ? 12 : 5,
                                ),
                                BoxShadow(
                                  color: const Color(0xFF8B5CF6)
                                      .withValues(alpha: 0.24),
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
                                color: const Color(0xFF172554)
                                    .withValues(alpha: 0.78),
                                size: speaking ? 42 : 34,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 42 + math.sin(t) * 9,
                            left: 38,
                            child: _agoraOrbitDot(
                              const Color(0xFF67E8F9),
                              0.85,
                              7,
                            ),
                          ),
                          Positioned(
                            right: 32,
                            top: 92 + math.cos(t * 1.2) * 10,
                            child: _agoraOrbitDot(
                              const Color(0xFFA78BFA),
                              0.90,
                              8,
                            ),
                          ),
                          Positioned(
                            bottom: 48 + math.sin(t * 0.8) * 8,
                            left: 58,
                            child: _agoraOrbitDot(
                              const Color(0xFF38BDF8),
                              0.78,
                              5,
                            ),
                          ),
                          Positioned(
                            bottom: 60,
                            right: 58 + math.cos(t) * 8,
                            child: _agoraOrbitDot(
                              const Color(0xFFC4B5FD),
                              0.68,
                              4,
                            ),
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
                  icon: isListening ? Icons.stop_rounded : Icons.mic_rounded,
                  tooltip: isListening
                      ? 'Terminar de hablar'
                      : 'Hablar con Ágora',
                  color: isListening
                      ? const Color(0xFFF87171)
                      : const Color(0xFF67E8F9),
                  onPressed: isLoading || VoiceService.isSpeaking.value
                      ? null
                      : onToggleDictation,
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
                  onPressed: onExit,
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
}
