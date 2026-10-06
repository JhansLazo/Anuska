import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notificacion.dart';

class NotificacionesService {
  static SupabaseClient get _db => Supabase.instance.client;

  static Future<List<Notificacion>> listar() async {
    final data = await _db.from('notificaciones').select().order('created_at', ascending: false).limit(100);
    return data.map(Notificacion.fromMap).toList();
  }

  static Future<int> noLeidas() async {
    final data = await _db.from('notificaciones').select('id').eq('leida', false);
    return data.length;
  }

  static Future<void> marcarLeida(int id) =>
      _db.from('notificaciones').update({'leida': true}).eq('id', id);

  static Future<void> marcarTodas() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    await _db.from('notificaciones').update({'leida': true}).eq('usuario_id', uid).eq('leida', false);
  }
}
