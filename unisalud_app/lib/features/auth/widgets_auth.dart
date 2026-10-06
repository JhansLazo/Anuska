import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Encabezado con degradado y logo usado en login/registro.
class EncabezadoAuth extends StatelessWidget {
  const EncabezadoAuth({super.key, required this.titulo, required this.subtitulo, this.mostrarAtras = false});
  final String titulo;
  final String subtitulo;
  final bool mostrarAtras;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.headerGradient,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (mostrarAtras)
                IconButton(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  tooltip: 'Volver',
                )
              else
                const SizedBox(height: 24),
              const LogoUniSalud(),
              const SizedBox(height: 20),
              Text(titulo,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(subtitulo, style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 15)),
            ]),
          ),
        ),
      );
}

class LogoUniSalud extends StatelessWidget {
  const LogoUniSalud({super.key});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.health_and_safety_rounded, color: AppColors.primary, size: 30),
        ),
        const SizedBox(width: 12),
        const Text('UniSalud',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
      ]);
}
