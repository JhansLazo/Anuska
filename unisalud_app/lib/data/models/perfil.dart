import 'especialidad.dart';

enum RolUsuario {
  paciente('Paciente'),
  doctor('Profesional de salud'),
  admin('Administrador');

  const RolUsuario(this.etiqueta);
  final String etiqueta;

  static RolUsuario desde(String? v) =>
      RolUsuario.values.firstWhere((r) => r.name == v, orElse: () => RolUsuario.paciente);
}

const tiposUsuario = {
  'estudiante': 'Estudiante',
  'docente': 'Docente',
  'administrativo': 'Administrativo',
  'externo': 'Externo',
};

class Perfil {
  final String id;
  final String nombres;
  final String apellidos;
  final String? email;
  final String? dni;
  final String? codigoUniversitario;
  final String? telefono;
  final String? escuela;
  final String tipoUsuario;
  final RolUsuario rol;
  final int? especialidadId;
  final Especialidad? especialidad;
  final String? consultorio;
  final bool activo;

  const Perfil({
    required this.id,
    required this.nombres,
    required this.apellidos,
    this.email,
    this.dni,
    this.codigoUniversitario,
    this.telefono,
    this.escuela,
    this.tipoUsuario = 'estudiante',
    this.rol = RolUsuario.paciente,
    this.especialidadId,
    this.especialidad,
    this.consultorio,
    this.activo = true,
  });

  factory Perfil.fromMap(Map<String, dynamic> m) => Perfil(
        id: m['id'] as String,
        nombres: (m['nombres'] as String?) ?? '',
        apellidos: (m['apellidos'] as String?) ?? '',
        email: m['email'] as String?,
        dni: m['dni'] as String?,
        codigoUniversitario: m['codigo_universitario'] as String?,
        telefono: m['telefono'] as String?,
        escuela: m['escuela'] as String?,
        tipoUsuario: (m['tipo_usuario'] as String?) ?? 'estudiante',
        rol: RolUsuario.desde(m['rol'] as String?),
        especialidadId: m['especialidad_id'] as int?,
        especialidad: m['especialidad'] is Map<String, dynamic>
            ? Especialidad.fromMap(m['especialidad'] as Map<String, dynamic>)
            : null,
        consultorio: m['consultorio'] as String?,
        activo: (m['activo'] as bool?) ?? true,
      );

  String get nombreCompleto => '$nombres $apellidos'.trim().isEmpty ? (email ?? 'Usuario') : '$nombres $apellidos'.trim();

  String get primerNombre => nombres.split(' ').first;

  String get iniciales {
    final a = nombres.isNotEmpty ? nombres[0] : '';
    final b = apellidos.isNotEmpty ? apellidos[0] : '';
    final r = '$a$b'.toUpperCase();
    return r.isEmpty ? '?' : r;
  }

  String get tipoUsuarioEtiqueta => tiposUsuario[tipoUsuario] ?? tipoUsuario;
}
