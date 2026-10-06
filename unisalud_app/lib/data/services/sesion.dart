import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/perfil.dart';

/// Estado global de la sesión: usuario autenticado + su perfil.
class Sesion extends ChangeNotifier {
  Sesion._();
  static final instancia = Sesion._();

  SupabaseClient get _db => Supabase.instance.client;

  Perfil? perfil;

  User? get usuario => _db.auth.currentUser;
  Stream<AuthState> get cambios => _db.auth.onAuthStateChange;

  Future<Perfil?> cargarPerfil() async {
    final uid = usuario?.id;
    if (uid == null) {
      perfil = null;
      notifyListeners();
      return null;
    }
    final data = await _db
        .from('perfiles')
        .select('*, especialidad:especialidades(*)')
        .eq('id', uid)
        .maybeSingle();
    perfil = data == null ? null : Perfil.fromMap(data);
    notifyListeners();
    return perfil;
  }

  Future<void> iniciarSesion(String email, String password) async {
    await _db.auth.signInWithPassword(email: email.trim(), password: password);
  }

  /// Devuelve `true` si la sesión quedó iniciada; `false` si hay que confirmar el correo.
  Future<bool> registrar({
    required String email,
    required String password,
    required String nombres,
    required String apellidos,
    required String dni,
    required String codigoUniversitario,
    required String telefono,
    required String tipoUsuario,
    String? escuela,
  }) async {
    final res = await _db.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'nombres': nombres.trim(),
        'apellidos': apellidos.trim(),
        'dni': dni.trim(),
        'codigo_universitario': codigoUniversitario.trim(),
        'telefono': telefono.trim(),
        'tipo_usuario': tipoUsuario,
        'escuela': escuela?.trim(),
      },
    );
    return res.session != null;
  }

  Future<void> recuperarContrasena(String email) =>
      _db.auth.resetPasswordForEmail(email.trim());

  Future<void> actualizarPerfil(Map<String, dynamic> cambios) async {
    final uid = usuario?.id;
    if (uid == null) return;
    await _db.from('perfiles').update(cambios).eq('id', uid);
    await cargarPerfil();
  }

  Future<void> cerrarSesion() async {
    await _db.auth.signOut();
    perfil = null;
    notifyListeners();
  }
}
