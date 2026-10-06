import 'package:flutter/material.dart';

class Especialidad {
  final int id;
  final String codigo;
  final String nombre;
  final String? descripcion;
  final Color color;
  final bool activo;

  const Especialidad({
    required this.id,
    required this.codigo,
    required this.nombre,
    this.descripcion,
    required this.color,
    this.activo = true,
  });

  factory Especialidad.fromMap(Map<String, dynamic> m) => Especialidad(
        id: m['id'] as int,
        codigo: m['codigo'] as String,
        nombre: m['nombre'] as String,
        descripcion: m['descripcion'] as String?,
        color: colorDesdeHex(m['color'] as String?),
        activo: (m['activo'] as bool?) ?? true,
      );

  IconData get icono => iconoPorCodigo(codigo);

  static IconData iconoPorCodigo(String? codigo) => switch (codigo) {
        'medicina' => Icons.medical_services_rounded,
        'enfermeria' => Icons.vaccines_rounded,
        'psicologia' => Icons.psychology_rounded,
        'odontologia' => Icons.sentiment_satisfied_alt_rounded,
        _ => Icons.local_hospital_rounded,
      };

  static Color colorDesdeHex(String? hex) {
    if (hex == null || hex.length < 7) return const Color(0xFF0E7C86);
    return Color(int.parse('FF${hex.substring(1, 7)}', radix: 16));
  }
}
