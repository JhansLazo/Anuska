import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:unisalud/core/utils/formatos.dart';
import 'package:unisalud/data/models/cita.dart';
import 'package:unisalud/features/comun/resumen_reporte.dart';

Cita _cita(int id, String estado, String turno, {int? derivadoA, String? derivadoNombre}) => Cita.fromMap({
      'id': id,
      'paciente_id': 'p$id',
      'doctor_id': 'd1',
      'especialidad_id': 3,
      'fecha': '2026-10-06',
      'hora_inicio': turno == 'mañana' ? '08:30:00' : '15:00:00',
      'hora_fin': '09:00:00',
      'turno': turno,
      'estado': estado,
      'derivado_a': derivadoA,
      'derivado_a_nombre': derivadoNombre,
      'created_at': '2026-10-01T10:00:00Z',
      'especialidad_nombre': 'Psicología',
      'especialidad_codigo': 'psicologia',
      'especialidad_color': '#7C3AED',
      'paciente_nombre': 'Paciente $id',
      'doctor_nombre': 'Dra. Prueba',
    });

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  test('Cita.fromMap interpreta estados, turno y código', () {
    final c = _cita(7, 'no_asistio', 'tarde');
    expect(c.estado, EstadoCita.noAsistio);
    expect(c.turnoEtiqueta, 'Tarde');
    expect(c.codigo, 'C-00007');
    expect(c.inicio, DateTime(2026, 10, 6, 15, 0));
  });

  test('ResumenReporte calcula asistencia, turnos y derivaciones', () {
    final r = ResumenReporte([
      _cita(1, 'atendida', 'mañana', derivadoA: 1, derivadoNombre: 'Medicina General'),
      _cita(2, 'atendida', 'mañana'),
      _cita(3, 'atendida', 'tarde'),
      _cita(4, 'no_asistio', 'tarde'),
      _cita(5, 'cancelada', 'mañana'),
    ]);
    expect(r.total, 5);
    expect(r.cuenta(EstadoCita.atendida), 3);
    expect(r.tasaAsistencia, 75);
    expect(r.porTurno['Mañana'], 3);
    expect(r.derivaciones['Medicina General'], 1);
    expect(r.porProfesional['Dra. Prueba']!.inasistencias, 1);
  });

  test('Formatos de hora y fecha en español', () {
    expect(Formatos.horaSql('08:30:00'), '08:30');
    expect(Formatos.diaLargo(DateTime(2026, 10, 6)), 'Martes 6 de octubre');
  });
}
