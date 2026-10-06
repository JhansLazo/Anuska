import 'package:flutter/material.dart';

/// Paleta pensada para salud: calma, confianza y buen contraste (WCAG AA).
class AppColors {
  static const primary = Color(0xFF0E7C86); // teal clínico
  static const primaryDark = Color(0xFF0A5C64);
  static const primarySoft = Color(0xFFE0F2F3);
  static const accent = Color(0xFFF59E0B);

  static const background = Color(0xFFF5F7FA);
  static const surface = Colors.white;
  static const text = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);

  static const success = Color(0xFF059669);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);
  static const info = Color(0xFF2563EB);
  static const neutral = Color(0xFF64748B);

  static const darkBackground = Color(0xFF0B1220);
  static const darkSurface = Color(0xFF111A2E);
  static const darkBorder = Color(0xFF1E2A44);

  static const headerGradient = LinearGradient(
    colors: [Color(0xFF0E7C86), Color(0xFF14A3A8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
