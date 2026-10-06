class Horario {
  final int id;
  final String doctorId;
  final int diaSemana; // 1 = lunes
  final String horaInicio;
  final String horaFin;
  final int duracionMinutos;
  final bool activo;

  const Horario({
    required this.id,
    required this.doctorId,
    required this.diaSemana,
    required this.horaInicio,
    required this.horaFin,
    required this.duracionMinutos,
    required this.activo,
  });

  factory Horario.fromMap(Map<String, dynamic> m) => Horario(
        id: m['id'] as int,
        doctorId: m['doctor_id'] as String,
        diaSemana: m['dia_semana'] as int,
        horaInicio: m['hora_inicio'] as String,
        horaFin: m['hora_fin'] as String,
        duracionMinutos: m['duracion_minutos'] as int,
        activo: m['activo'] as bool,
      );
}

/// Un bloque reservable devuelto por `horarios_disponibles`.
class BloqueHorario {
  final String inicio;
  final String fin;
  final String turno;
  final bool disponible;

  const BloqueHorario({required this.inicio, required this.fin, required this.turno, required this.disponible});

  factory BloqueHorario.fromMap(Map<String, dynamic> m) => BloqueHorario(
        inicio: m['slot_inicio'] as String,
        fin: m['slot_fin'] as String,
        turno: m['turno'] as String,
        disponible: m['disponible'] as bool,
      );
}
