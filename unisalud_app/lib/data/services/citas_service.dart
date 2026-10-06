import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/formatos.dart';
import '../models/cita.dart';
import '../models/horario.dart';

class CitasService {
  static SupabaseClient get _db => Supabase.instance.client;

  static List<Cita> _lista(List<dynamic> data) =>
      data.map((e) => Cita.fromMap(e as Map<String, dynamic>)).toList();

  /// Citas del paciente (las más recientes primero).
  static Future<List<Cita>> delPaciente(String pacienteId) async {
    final data = await _db
        .from('v_citas')
        .select()
        .eq('paciente_id', pacienteId)
        .order('fecha', ascending: false)
        .order('hora_inicio', ascending: false);
    return _lista(data);
  }

  /// Agenda de un profesional en un día.
  static Future<List<Cita>> agendaDelDia(String doctorId, DateTime dia) async {
    final data = await _db
        .from('v_citas')
        .select()
        .eq('doctor_id', doctorId)
        .eq('fecha', Formatos.iso(dia))
        .order('hora_inicio');
    return _lista(data);
  }

  /// Búsqueda general (admin y reportes). RLS limita lo que cada rol puede ver.
  static Future<List<Cita>> buscar({
    required DateTime desde,
    required DateTime hasta,
    int? especialidadId,
    EstadoCita? estado,
    String? doctorId,
    String? turno,
    int limite = 5000,
  }) async {
    var q = _db
        .from('v_citas')
        .select()
        .gte('fecha', Formatos.iso(desde))
        .lte('fecha', Formatos.iso(hasta));
    if (especialidadId != null) q = q.eq('especialidad_id', especialidadId);
    if (estado != null) q = q.eq('estado', estado.valorDb);
    if (doctorId != null) q = q.eq('doctor_id', doctorId);
    if (turno != null) q = q.eq('turno', turno);
    final data = await q.order('fecha', ascending: false).order('hora_inicio').limit(limite);
    return _lista(data);
  }

  static Future<Cita> obtener(int id) async {
    final data = await _db.from('v_citas').select().eq('id', id).single();
    return Cita.fromMap(data);
  }

  /// Historial de atenciones de un paciente (visible según el rol).
  static Future<List<Cita>> historialPaciente(String pacienteId) async {
    final data = await _db
        .from('v_citas')
        .select()
        .eq('paciente_id', pacienteId)
        .eq('estado', 'atendida')
        .order('fecha', ascending: false)
        .limit(20);
    return _lista(data);
  }

  static Future<List<BloqueHorario>> bloquesDisponibles(String doctorId, DateTime fecha) async {
    final data = await _db.rpc('horarios_disponibles', params: {
      'p_doctor_id': doctorId,
      'p_fecha': Formatos.iso(fecha),
    }) as List<dynamic>;
    return data.map((e) => BloqueHorario.fromMap(e as Map<String, dynamic>)).toList();
  }

  static Future<int> reservar({
    required String doctorId,
    required DateTime fecha,
    required String hora,
    String? motivo,
    int? citaOrigenId,
  }) async {
    final data = await _db.rpc('reservar_cita', params: {
      'p_doctor_id': doctorId,
      'p_fecha': Formatos.iso(fecha),
      'p_hora': hora,
      'p_motivo': motivo,
      'p_cita_origen_id': citaOrigenId,
    }) as Map<String, dynamic>;
    return data['id'] as int;
  }

  static Future<void> cancelar(int citaId, String? motivo) =>
      _db.rpc('cancelar_cita', params: {'p_cita_id': citaId, 'p_motivo': motivo});

  static Future<void> confirmar(int citaId) =>
      _db.rpc('confirmar_cita', params: {'p_cita_id': citaId});

  static Future<void> registrarLlegada(int citaId) =>
      _db.rpc('registrar_llegada', params: {'p_cita_id': citaId});

  static Future<void> marcarNoAsistio(int citaId) =>
      _db.rpc('marcar_no_asistio', params: {'p_cita_id': citaId});

  static Future<void> registrarAtencion({
    required int citaId,
    String? diagnostico,
    String? indicaciones,
    String? observaciones,
    int? derivadoA,
    String? derivacionExterna,
    String? motivoDerivacion,
  }) =>
      _db.rpc('registrar_atencion', params: {
        'p_cita_id': citaId,
        'p_diagnostico': diagnostico,
        'p_indicaciones': indicaciones,
        'p_observaciones': observaciones,
        'p_derivado_a': derivadoA,
        'p_derivacion_externa': derivacionExterna,
        'p_motivo_derivacion': motivoDerivacion,
      });
}
