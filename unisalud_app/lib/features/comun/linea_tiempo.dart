import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatos.dart';
import '../../data/models/cita.dart';

/// Línea de tiempo de la cita: reservada → llegada → atendida / no asistió / cancelada.
class LineaTiempoCita extends StatelessWidget {
  const LineaTiempoCita({super.key, required this.cita});
  final Cita cita;

  @override
  Widget build(BuildContext context) {
    final pasos = <_Paso>[
      _Paso('Cita reservada', Formatos.fechaHora(cita.creadaEn), Icons.event_note_rounded, AppColors.primary, true),
    ];
    switch (cita.estado) {
      case EstadoCita.cancelada:
        pasos.add(_Paso(
          'Cancelada${cita.canceladaPorNombre != null ? ' por ${cita.canceladaPorNombre}' : ''}',
          [
            if (cita.canceladaEn != null) Formatos.fechaHora(cita.canceladaEn!),
            if (cita.motivoCancelacion != null) 'Motivo: ${cita.motivoCancelacion}',
          ].join('\n'),
          Icons.cancel_rounded,
          AppColors.neutral,
          true,
        ));
      case EstadoCita.noAsistio:
        pasos.add(_Paso('No asistió', 'El paciente no se presentó a la cita', Icons.person_off_rounded, AppColors.danger, true));
      default:
        pasos.add(_Paso(
          'Llegada del paciente',
          cita.horaLlegada != null ? Formatos.fechaHora(cita.horaLlegada!) : 'Pendiente',
          Icons.how_to_reg_rounded,
          AppColors.info,
          cita.horaLlegada != null,
        ));
        pasos.add(_Paso(
          'Atendido',
          cita.atendidaEn != null ? '${Formatos.fechaHora(cita.atendidaEn!)} · ${cita.doctorNombre}' : 'Pendiente',
          Icons.check_circle_rounded,
          AppColors.success,
          cita.atendidaEn != null,
        ));
        if (cita.fueDerivada) {
          pasos.add(_Paso(
            'Derivado',
            cita.derivadoANombre ?? cita.derivacionExterna ?? '',
            Icons.alt_route_rounded,
            AppColors.accent,
            true,
          ));
        }
    }

    final hint = Theme.of(context).hintColor;
    return Column(children: [
      for (var i = 0; i < pasos.length; i++)
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 36,
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: pasos[i].hecho ? pasos[i].color : hint.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(pasos[i].icono, size: 16, color: pasos[i].hecho ? Colors.white : hint),
                ),
                if (i < pasos.length - 1)
                  Expanded(child: Container(width: 2, color: hint.withValues(alpha: 0.2))),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(pasos[i].titulo,
                      style: TextStyle(fontWeight: FontWeight.w700, color: pasos[i].hecho ? null : hint)),
                  if (pasos[i].detalle.isNotEmpty)
                    Text(pasos[i].detalle, style: TextStyle(color: hint, fontSize: 13)),
                ]),
              ),
            ),
          ]),
        ),
    ]);
  }
}

class _Paso {
  const _Paso(this.titulo, this.detalle, this.icono, this.color, this.hecho);
  final String titulo;
  final String detalle;
  final IconData icono;
  final Color color;
  final bool hecho;
}
