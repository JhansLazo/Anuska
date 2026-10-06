import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'especialidad.dart';

enum EstadoCita {
  pendiente('Pendiente', AppColors.warning, Icons.schedule_rounded),
  confirmada('Confirmada', AppColors.info, Icons.event_available_rounded),
  atendida('Atendida', AppColors.success, Icons.check_circle_rounded),
  noAsistio('No asistió', AppColors.danger, Icons.person_off_rounded),
  cancelada('Cancelada', AppColors.neutral, Icons.cancel_rounded);

  const EstadoCita(this.etiqueta, this.color, this.icono);
  final String etiqueta;
  final Color color;
  final IconData icono;

  String get valorDb => this == EstadoCita.noAsistio ? 'no_asistio' : name;

  static EstadoCita desde(String? v) =>
      EstadoCita.values.firstWhere((e) => e.valorDb == v, orElse: () => EstadoCita.pendiente);

  bool get activa => this == EstadoCita.pendiente || this == EstadoCita.confirmada;
}

/// Cita tal como la devuelve la vista `v_citas`.
class Cita {
  final int id;
  final String pacienteId;
  final String doctorId;
  final int especialidadId;
  final DateTime fecha;
  final String horaInicio;
  final String horaFin;
  final String turno;
  final String? motivo;
  final EstadoCita estado;
  final bool? asistio;
  final DateTime? horaLlegada;
  final DateTime? atendidaEn;
  final String? diagnostico;
  final String? indicaciones;
  final String? observaciones;
  final int? derivadoA;
  final String? derivadoANombre;
  final String? derivacionExterna;
  final String? motivoDerivacion;
  final int? citaOrigenId;
  final String? motivoCancelacion;
  final String? canceladaPorNombre;
  final DateTime? canceladaEn;
  final DateTime creadaEn;

  final String especialidadNombre;
  final String especialidadCodigo;
  final Color especialidadColor;
  final String pacienteNombre;
  final String? pacienteDni;
  final String? pacienteCodigo;
  final String? pacienteTipo;
  final String? pacienteTelefono;
  final String? pacienteEscuela;
  final String doctorNombre;
  final String? consultorio;

  const Cita({
    required this.id,
    required this.pacienteId,
    required this.doctorId,
    required this.especialidadId,
    required this.fecha,
    required this.horaInicio,
    required this.horaFin,
    required this.turno,
    this.motivo,
    required this.estado,
    this.asistio,
    this.horaLlegada,
    this.atendidaEn,
    this.diagnostico,
    this.indicaciones,
    this.observaciones,
    this.derivadoA,
    this.derivadoANombre,
    this.derivacionExterna,
    this.motivoDerivacion,
    this.citaOrigenId,
    this.motivoCancelacion,
    this.canceladaPorNombre,
    this.canceladaEn,
    required this.creadaEn,
    required this.especialidadNombre,
    required this.especialidadCodigo,
    required this.especialidadColor,
    required this.pacienteNombre,
    this.pacienteDni,
    this.pacienteCodigo,
    this.pacienteTipo,
    this.pacienteTelefono,
    this.pacienteEscuela,
    required this.doctorNombre,
    this.consultorio,
  });

  static DateTime? _ts(dynamic v) => v == null ? null : DateTime.parse(v as String).toLocal();

  factory Cita.fromMap(Map<String, dynamic> m) => Cita(
        id: m['id'] as int,
        pacienteId: m['paciente_id'] as String,
        doctorId: m['doctor_id'] as String,
        especialidadId: m['especialidad_id'] as int,
        fecha: DateTime.parse(m['fecha'] as String),
        horaInicio: m['hora_inicio'] as String,
        horaFin: m['hora_fin'] as String,
        turno: (m['turno'] as String?) ?? '',
        motivo: m['motivo'] as String?,
        estado: EstadoCita.desde(m['estado'] as String?),
        asistio: m['asistio'] as bool?,
        horaLlegada: _ts(m['hora_llegada']),
        atendidaEn: _ts(m['atendida_en']),
        diagnostico: m['diagnostico'] as String?,
        indicaciones: m['indicaciones'] as String?,
        observaciones: m['observaciones'] as String?,
        derivadoA: m['derivado_a'] as int?,
        derivadoANombre: m['derivado_a_nombre'] as String?,
        derivacionExterna: m['derivacion_externa'] as String?,
        motivoDerivacion: m['motivo_derivacion'] as String?,
        citaOrigenId: m['cita_origen_id'] as int?,
        motivoCancelacion: m['motivo_cancelacion'] as String?,
        canceladaPorNombre: m['cancelada_por_nombre'] as String?,
        canceladaEn: _ts(m['cancelada_en']),
        creadaEn: _ts(m['created_at']) ?? DateTime.now(),
        especialidadNombre: (m['especialidad_nombre'] as String?) ?? '',
        especialidadCodigo: (m['especialidad_codigo'] as String?) ?? '',
        especialidadColor: Especialidad.colorDesdeHex(m['especialidad_color'] as String?),
        pacienteNombre: (m['paciente_nombre'] as String?) ?? '',
        pacienteDni: m['paciente_dni'] as String?,
        pacienteCodigo: m['paciente_codigo'] as String?,
        pacienteTipo: m['paciente_tipo'] as String?,
        pacienteTelefono: m['paciente_telefono'] as String?,
        pacienteEscuela: m['paciente_escuela'] as String?,
        doctorNombre: (m['doctor_nombre'] as String?) ?? '',
        consultorio: m['consultorio'] as String?,
      );

  /// Fecha + hora de inicio como DateTime local.
  DateTime get inicio {
    final p = horaInicio.split(':');
    return DateTime(fecha.year, fecha.month, fecha.day, int.parse(p[0]), int.parse(p[1]));
  }

  bool get esFutura => inicio.isAfter(DateTime.now());
  bool get puedeCancelarse => estado.activa && esFutura;
  bool get fueDerivada => derivadoA != null || (derivacionExterna?.isNotEmpty ?? false);
  String get codigo => 'C-${id.toString().padLeft(5, '0')}';
  String get turnoEtiqueta => turno == 'mañana' ? 'Mañana' : 'Tarde';
  IconData get icono => Especialidad.iconoPorCodigo(especialidadCodigo);
}
