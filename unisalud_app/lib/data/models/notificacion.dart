class Notificacion {
  final int id;
  final String titulo;
  final String mensaje;
  final int? citaId;
  final bool leida;
  final DateTime creadaEn;

  const Notificacion({
    required this.id,
    required this.titulo,
    required this.mensaje,
    this.citaId,
    required this.leida,
    required this.creadaEn,
  });

  factory Notificacion.fromMap(Map<String, dynamic> m) => Notificacion(
        id: m['id'] as int,
        titulo: m['titulo'] as String,
        mensaje: m['mensaje'] as String,
        citaId: m['cita_id'] as int?,
        leida: m['leida'] as bool,
        creadaEn: DateTime.parse(m['created_at'] as String).toLocal(),
      );
}
