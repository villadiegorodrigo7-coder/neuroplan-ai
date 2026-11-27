import 'package:flutter/material.dart';

const coloresRueda = [
  Color(0xFF35D07F),
  Color(0xFF45A9FF),
  Color(0xFFFF9F43),
  Color(0xFFFFD166),
  Color(0xFFFF6FAE),
  Color(0xFF35D6C5),
  Color(0xFFB28DFF),
  Color(0xFFA6D854),
  Color(0xFFFFE45E),
  Color(0xFFFF5C65),
  Color(0xFF65D8FF),
  Color(0xFF788BFF),
  Color(0xFFFF65D4),
  Color(0xFFFF876B),
];

BoxDecoration decoracionRadarRueda() => BoxDecoration(
  gradient: const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF121E3B), Color(0xFF10172F), Color(0xFF211D43)],
  ),
  borderRadius: BorderRadius.circular(25),
  border: Border.all(color: const Color(0xFF8CEBFF).withValues(alpha: 0.13)),
  boxShadow: [
    BoxShadow(
      color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
      blurRadius: 26,
      spreadRadius: 1,
    ),
  ],
);
