import 'package:flutter/material.dart';

/// Dibuja un segmento por cada día del ciclo; el selector táctil se superpone encima.
class PulsoPainter extends CustomPainter {
  final List<Color> colores;
  final int seleccionado;
  final Color base;

  PulsoPainter({
    required this.colores,
    required this.seleccionado,
    required this.base,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height / 2);
    const radio = 112.0;
    const grosor = 13.0;
    const separacion = 0.035;
    final rect = Rect.fromCircle(center: centro, radius: radio);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round;

    final cantidad = colores.isEmpty ? 30 : colores.length;
    for (var i = 0; i < cantidad; i++) {
      final barrido = 2 * 3.141592653589793 / cantidad;
      final inicio = -3.141592653589793 / 2 + i * barrido + separacion;
      paint.color = i < colores.length ? colores[i] : base;
      canvas.drawArc(rect, inicio, barrido - separacion * 2, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant PulsoPainter oldDelegate) =>
      oldDelegate.colores != colores ||
      oldDelegate.seleccionado != seleccionado;
}
