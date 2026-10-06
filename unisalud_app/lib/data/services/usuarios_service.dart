import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/perfil.dart';

/// Gestión de cuentas (solo administradores, lo garantiza RLS).
class UsuariosService {
  static SupabaseClient get _db => Supabase.instance.client;

  static Future<List<Perfil>> listar({String? busqueda, RolUsuario? rol}) async {
    var q = _db.from('perfiles').select('*, especialidad:especialidades(*)');
    if (rol != null) q = q.eq('rol', rol.name);
    final texto = busqueda?.trim().replaceAll(RegExp(r'[,()]'), ' ');
    if (texto != null && texto.isNotEmpty) {
      q = q.or('nombres.ilike.%$texto%,apellidos.ilike.%$texto%,dni.ilike.%$texto%,'
          'email.ilike.%$texto%,codigo_universitario.ilike.%$texto%');
    }
    final data = await q.order('apellidos').limit(200);
    return data.map(Perfil.fromMap).toList();
  }

  static Future<void> actualizar(
    String id, {
    required RolUsuario rol,
    int? especialidadId,
    String? consultorio,
    required bool activo,
  }) =>
      _db.from('perfiles').update({
        'rol': rol.name,
        'especialidad_id': rol == RolUsuario.doctor ? especialidadId : null,
        'consultorio': rol == RolUsuario.doctor ? consultorio : null,
        'activo': activo,
      }).eq('id', id);
}
