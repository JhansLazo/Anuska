import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Utilidades de fechas/horas en español.
class Formatos {
  static final _fecha = DateFormat("d 'de' MMMM, yyyy", 'es');
  static final _fechaCorta = DateFormat('dd/MM/yyyy', 'es');
  static final _diaLargo = DateFormat("EEEE d 'de' MMMM", 'es');
  static final _fechaHora = DateFormat("dd/MM/yyyy · HH:mm", 'es');
  static final _hora = DateFormat('HH:mm', 'es');
  static final _iso = DateFormat('yyyy-MM-dd');

  static String fecha(DateTime d) => _fecha.format(d);
  static String fechaCorta(DateTime d) => _fechaCorta.format(d);
  static String diaLargo(DateTime d) => _capitalizar(_diaLargo.format(d));
  static String fechaHora(DateTime d) => _fechaHora.format(d.toLocal());
  static String hora(DateTime d) => _hora.format(d.toLocal());
  static String iso(DateTime d) => _iso.format(d);
  static String diaSemanaCorto(DateTime d) => _capitalizar(DateFormat('EEE', 'es').format(d)).replaceAll('.', '');
  static String mesCorto(DateTime d) => _capitalizar(DateFormat('MMM', 'es').format(d)).replaceAll('.', '');

  /// "08:30:00" → "08:30"
  static String horaSql(String? h) => (h == null || h.length < 5) ? (h ?? '') : h.substring(0, 5);

  static const diasSemana = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

  static String _capitalizar(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static DateTime soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Convierte errores de Supabase en mensajes entendibles.
  static String error(Object e) {
    if (e is PostgrestException) return e.message;
    if (e is AuthException) {
      final m = e.message.toLowerCase();
      if (m.contains('invalid login')) return 'Correo o contraseña incorrectos';
      if (m.contains('already registered')) return 'Ese correo ya está registrado';
      if (m.contains('email not confirmed')) return 'Confirma tu correo antes de ingresar (revisa tu bandeja)';
      if (m.contains('password')) return 'La contraseña debe tener al menos 6 caracteres';
      return e.message;
    }
    final s = e.toString();
    if (s.contains('SocketException') || s.contains('ClientException')) {
      return 'Sin conexión a internet. Inténtalo de nuevo.';
    }
    return s.replaceFirst('Exception: ', '');
  }
}
