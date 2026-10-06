import '../../data/models/cita.dart';

/// Indicadores calculados a partir de una lista de citas.
class ResumenReporte {
  ResumenReporte(this.citas) {
    for (final c in citas) {
      porEstado[c.estado] = (porEstado[c.estado] ?? 0) + 1;
      porArea[c.especialidadNombre] = (porArea[c.especialidadNombre] ?? 0) + 1;
      porTurno[c.turnoEtiqueta] = (porTurno[c.turnoEtiqueta] ?? 0) + 1;
      porTipoPaciente[c.pacienteTipo ?? 'otro'] = (porTipoPaciente[c.pacienteTipo ?? 'otro'] ?? 0) + 1;
      final d = porProfesional.putIfAbsent(c.doctorNombre, () => FilaProfesional(c.doctorNombre, c.especialidadNombre));
      d.total++;
      if (c.estado == EstadoCita.atendida) d.atendidas++;
      if (c.estado == EstadoCita.noAsistio) d.inasistencias++;
      if (c.estado == EstadoCita.cancelada) d.canceladas++;
      if (c.fueDerivada) {
        final destino = c.derivadoANombre ?? 'Externa: ${c.derivacionExterna}';
        derivaciones[destino] = (derivaciones[destino] ?? 0) + 1;
      }
    }
  }

  final List<Cita> citas;
  final porEstado = <EstadoCita, int>{};
  final porArea = <String, int>{};
  final porTurno = <String, int>{};
  final porTipoPaciente = <String, int>{};
  final porProfesional = <String, FilaProfesional>{};
  final derivaciones = <String, int>{};

  int get total => citas.length;
  int cuenta(EstadoCita e) => porEstado[e] ?? 0;
  int get totalDerivaciones => derivaciones.values.fold(0, (a, b) => a + b);

  /// % de asistencia sobre las citas ya cerradas (atendidas + no asistió).
  double get tasaAsistencia {
    final cerradas = cuenta(EstadoCita.atendida) + cuenta(EstadoCita.noAsistio);
    return cerradas == 0 ? 0 : cuenta(EstadoCita.atendida) * 100 / cerradas;
  }

  static List<MapEntry<String, int>> ordenar(Map<String, int> m) =>
      m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
}

class FilaProfesional {
  FilaProfesional(this.nombre, this.area);
  final String nombre;
  final String area;
  int total = 0;
  int atendidas = 0;
  int inasistencias = 0;
  int canceladas = 0;
}
