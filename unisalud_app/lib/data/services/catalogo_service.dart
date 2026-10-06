import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/especialidad.dart';
import '../models/horario.dart';
import '../models/perfil.dart';

/// Especialidades, profesionales y sus horarios.
class CatalogoService {
  static SupabaseClient get _db => Supabase.instance.client;

  static List<Especialidad>? _cacheEspecialidades;

  static Future<List<Especialidad>> especialidades({bool refrescar = false}) async {
    if (_cacheEspecialidades != null && !refrescar) return _cacheEspecialidades!;
    final data = await _db.from('especialidades').select().eq('activo', true).order('id');
    _cacheEspecialidades = data.map(Especialidad.fromMap).toList();
    return _cacheEspecialidades!;
  }

  static Future<List<Perfil>> profesionales({int? especialidadId}) async {
    var q = _db
        .from('perfiles')
        .select('*, especialidad:especialidades(*)')
        .eq('rol', 'doctor')
        .eq('activo', true);
    if (especialidadId != null) q = q.eq('especialidad_id', especialidadId);
    final data = await q.order('apellidos');
    return data.map(Perfil.fromMap).toList();
  }

  static Future<List<Horario>> horarios(String doctorId) async {
    final data = await _db
        .from('horarios_doctor')
        .select()
        .eq('doctor_id', doctorId)
        .order('dia_semana')
        .order('hora_inicio');
    return data.map(Horario.fromMap).toList();
  }

  /// Horarios de varios profesionales a la vez (agrupados por profesional).
  static Future<Map<String, List<Horario>>> horariosDe(List<String> doctorIds) async {
    if (doctorIds.isEmpty) return {};
    final data = await _db.from('horarios_doctor').select().inFilter('doctor_id', doctorIds).eq('activo', true);
    final r = <String, List<Horario>>{};
    for (final h in data.map(Horario.fromMap)) {
      r.putIfAbsent(h.doctorId, () => []).add(h);
    }
    return r;
  }

  /// Días de la semana (1-7) en que el profesional atiende.
  static Future<Set<int>> diasDeAtencion(String doctorId) async {
    final hs = await horarios(doctorId);
    return hs.where((h) => h.activo).map((h) => h.diaSemana).toSet();
  }

  static Future<void> crearHorario({
    required String doctorId,
    required int diaSemana,
    required String horaInicio,
    required String horaFin,
    required int duracion,
  }) =>
      _db.from('horarios_doctor').insert({
        'doctor_id': doctorId,
        'dia_semana': diaSemana,
        'hora_inicio': horaInicio,
        'hora_fin': horaFin,
        'duracion_minutos': duracion,
      });

  static Future<void> cambiarEstadoHorario(int id, bool activo) =>
      _db.from('horarios_doctor').update({'activo': activo}).eq('id', id);

  static Future<void> eliminarHorario(int id) => _db.from('horarios_doctor').delete().eq('id', id);
}
