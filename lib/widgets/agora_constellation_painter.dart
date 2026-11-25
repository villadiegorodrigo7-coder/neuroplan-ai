import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Fondo permanente de Ágora: una constelación tenue que permanece detrás
/// de los mensajes mientras el usuario recorre la conversación.
class AgoraConstellationPainter extends CustomPainter {
  AgoraConstellationPainter({
    required this.progress,
    required this.active,
    required this.speaking,
  });

  final double progress;
  final bool active;
  final bool speaking;

  static const List<Offset> _stars = [
    Offset(0.12, 0.12),
    Offset(0.28, 0.20),
    Offset(0.46, 0.10),
    Offset(0.68, 0.16),
    Offset(0.87, 0.10),
    Offset(0.18, 0.38),
    Offset(0.36, 0.46),
    Offset(0.58, 0.36),
    Offset(0.80, 0.43),
    Offset(0.10, 0.65),
    Offset(0.30, 0.78),
    Offset(0.52, 0.68),
    Offset(0.73, 0.79),
    Offset(0.91, 0.66),
    Offset(0.17, 0.91),
    Offset(0.43, 0.94),
    Offset(0.66, 0.91),
    Offset(0.88, 0.90),
  ];

  static const List<List<int>> _links = [
    [0, 1],
    [1, 2],
    [2, 3],
    [3, 4],
    [0, 5],
    [1, 6],
    [2, 7],
    [3, 8],
    [5, 6],
    [6, 7],
    [7, 8],
    [5, 9],
    [6, 10],
    [7, 11],
    [8, 13],
    [9, 10],
    [10, 11],
    [11, 12],
    [12, 13],
    [10, 14],
    [11, 15],
    [12, 16],
    [13, 17],
    [14, 15],
    [15, 16],
    [16, 17],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * math.pi * 2;
    final accent = speaking ? const Color(0xFFA78BFA) : const Color(0xFF67E8F9);
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
    canvas.drawCircle(
      center,
      radius * (1.02 + math.cos(t * 0.7) * 0.025),
      orbPaint,
    );

    final points = <Offset>[];
    for (var i = 0; i < _stars.length; i++) {
      final p = _stars[i];
      final drift = math.sin(t + i * 0.83) * (active ? 5.0 : 2.5);
      points.add(
        Offset(
          p.dx * size.width + drift,
          p.dy * size.height + math.cos(t * 0.8 + i) * (active ? 4.0 : 2.0),
        ),
      );
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
  bool shouldRepaint(covariant AgoraConstellationPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.active != active ||
      oldDelegate.speaking != speaking;
}
