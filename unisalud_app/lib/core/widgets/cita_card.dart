import 'package:flutter/material.dart';

import '../../data/models/cita.dart';
import '../theme/app_colors.dart';
import '../utils/formatos.dart';
import 'ui.dart';

/// Tarjeta de cita usada en todas las listas.
/// [vista] decide qué persona se destaca: el profesional (paciente) o el paciente (profesional/admin).
enum VistaCita { paciente, profesional, admin }

class CitaCard extends StatelessWidget {
  const CitaCard({super.key, required this.cita, required this.vista, this.onTap});
  final Cita cita;
  final VistaCita vista;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = cita.especialidadColor;
    final hint = Theme.of(context).hintColor;
    final titulo = switch (vista) {
      VistaCita.paciente => cita.especialidadNombre,
      _ => cita.pacienteNombre,
    };
    final subtitulo = switch (vista) {
      VistaCita.paciente => cita.doctorNombre,
      VistaCita.profesional => [
          if (cita.pacienteCodigo != null) 'Cód. ${cita.pacienteCodigo}',
          if (cita.pacienteDni != null) 'DNI ${cita.pacienteDni}',
        ].join(' · '),
      VistaCita.admin => '${cita.especialidadNombre} · ${cita.doctorNombre}',
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 5, color: color),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 0, 14),
              child: Container(
                width: 58,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14)),
                child: vista == VistaCita.profesional
                    ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(Formatos.horaSql(cita.horaInicio),
                            style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
                        Text(Formatos.horaSql(cita.horaFin), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                      ])
                    : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(Formatos.diaSemanaCorto(cita.fecha), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
                        Text('${cita.fecha.day}', style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800, height: 1.1)),
                        Text(Formatos.mesCorto(cita.fecha), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                      ]),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Row(children: [
                    Icon(cita.icono, size: 16, color: color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(titulo,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                  ]),
                  if (subtitulo.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(subtitulo, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: hint, fontSize: 13)),
                  ],
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    if (vista == VistaCita.profesional && cita.horaLlegada != null && cita.estado.activa)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.how_to_reg_rounded, size: 14, color: AppColors.info),
                        const SizedBox(width: 3),
                        Text('Llegó ${Formatos.hora(cita.horaLlegada!)}',
                            style: const TextStyle(fontSize: 12.5, color: AppColors.info, fontWeight: FontWeight.w700)),
                      ])
                    else if (vista != VistaCita.profesional)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.access_time_rounded, size: 14, color: hint),
                        const SizedBox(width: 3),
                        Text('${Formatos.horaSql(cita.horaInicio)} · ${cita.turnoEtiqueta}',
                            style: TextStyle(fontSize: 12.5, color: hint, fontWeight: FontWeight.w600)),
                      ]),
                    EstadoChip(cita.estado, compacto: true),
                  ]),
                ]),
              ),
            ),
            if (onTap != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(Icons.chevron_right_rounded, color: hint),
              ),
          ]),
        ),
      ),
    );
  }
}
