import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Radar numérico reutilizable para la Rueda de la Vida y el Diagnóstico.
class RadarDiagnosticoPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color color;
  final Color textColor;
  final List<Color>? axisColors;
  final Set<int> missingIndices;

  RadarDiagnosticoPainter({
    required this.values,
    required this.labels,
    required this.color,
    required this.textColor,
    this.axisColors,
    this.missingIndices = const {},
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.285;
    final count = values.length;
    final gridPaint = Paint()
      ..color = const Color(0xFF9FB8E8).withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (var level = 1; level <= 10; level++) {
      final r = radius * level / 10;
      final points = List.generate(count, (i) {
        final angle = -math.pi / 2 + 2 * math.pi * i / count;
        return center + Offset(math.cos(angle) * r, math.sin(angle) * r);
      });
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    final polygon = <Offset?>[];
    for (var i = 0; i < count; i++) {
      final angle = -math.pi / 2 + 2 * math.pi * i / count;
      final end =
          center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      final axisColor = axisColors != null && i < axisColors!.length
          ? axisColors![i]
          : color;
      canvas.drawLine(
        center,
        end,
        Paint()
          ..color = axisColor.withValues(alpha: 0.48)
          ..strokeWidth = 1.1,
      );
      if (missingIndices.contains(i)) {
        polygon.add(null);
      } else {
        final value = values[i].clamp(0, 10).toDouble();
        polygon.add(
          center +
              Offset(
                math.cos(angle) * radius * value / 10,
                math.sin(angle) * radius * value / 10,
              ),
        );
      }
    }

    // Solo une dimensiones con información: las ausencias no se dibujan como cero.
    for (var i = 0; i < count; i++) {
      final current = polygon[i];
      final next = polygon[(i + 1) % count];
      if (current == null || next == null) continue;
      final sectorColor = axisColors != null && i < axisColors!.length
          ? axisColors![i]
          : color;
      final sector = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(current.dx, current.dy)
        ..lineTo(next.dx, next.dy)
        ..close();
      canvas.drawPath(
        sector,
        Paint()
          ..color = sectorColor.withValues(alpha: 0.13)
          ..style = PaintingStyle.fill,
      );
      canvas.drawLine(
        current,
        next,
        Paint()
          ..color = sectorColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }

    for (var i = 0; i < count; i++) {
      final point = polygon[i];
      if (point == null) continue;
      final pointColor = axisColors != null && i < axisColors!.length
          ? axisColors![i]
          : color;
      canvas.drawCircle(point, 4.2, Paint()..color = pointColor);
      canvas.drawCircle(
        point,
        5.3,
        Paint()
          ..color = pointColor.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    for (var i = 0; i < count; i++) {
      final angle = -math.pi / 2 + 2 * math.pi * i / count;
      final labelPoint =
          center +
          Offset(
            math.cos(angle) * (radius + 17),
            math.sin(angle) * (radius + 17),
          );
      final labelColor = missingIndices.contains(i)
          ? textColor.withValues(alpha: 0.45)
          : (axisColors != null && i < axisColors!.length
                ? axisColors![i]
                : textColor);
      final text = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: labelColor,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            shadows: const [Shadow(color: Color(0xFFB66BFF), blurRadius: 5)],
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 2,
      )..layout(maxWidth: 70);
      final offset = Offset(
        (labelPoint.dx - text.width / 2).clamp(0.0, size.width - text.width),
        (labelPoint.dy - text.height / 2).clamp(0.0, size.height - text.height),
      );
      text.paint(canvas, offset);
    }

    // Escala discreta 2–10 en el eje vertical, como referencia numérica.
    for (var level = 2; level <= 10; level += 2) {
      final y = center.dy - radius * level / 10;
      final text = TextPainter(
        text: TextSpan(
          text: '$level',
          style: TextStyle(
            color: textColor.withValues(alpha: 0.58),
            fontSize: 8,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(center.dx + 4, y - text.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant RadarDiagnosticoPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.labels != labels ||
      oldDelegate.color != color ||
      oldDelegate.textColor != textColor ||
      oldDelegate.axisColors != axisColors ||
      oldDelegate.missingIndices != missingIndices;
}
