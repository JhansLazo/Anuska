import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatos.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/cita.dart';
import '../../data/services/catalogo_service.dart';
import '../../data/services/citas_service.dart';
import '../comun/linea_tiempo.dart';
import 'reservar_cita_screen.dart';

/// Detalle de una cita desde la vista del paciente.
class CitaDetalleScreen extends StatefulWidget {
  const CitaDetalleScreen({super.key, required this.citaId});
  final int citaId;

  @override
  State<CitaDetalleScreen> createState() => _CitaDetalleScreenState();
}

class _CitaDetalleScreenState extends State<CitaDetalleScreen> {
  late Future<Cita> _cita;
  bool _cambio = false;

  @override
  void initState() {
    super.initState();
    _cita = CitasService.obtener(widget.citaId);
  }

  void _recargar() => setState(() => _cita = CitasService.obtener(widget.citaId));

  Future<void> _cancelar(Cita c) async {
    final motivo = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar esta cita?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('El horario quedará libre para otra persona.'),
          const SizedBox(height: 16),
          TextField(controller: motivo, decoration: const InputDecoration(labelText: 'Motivo (opcional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Volver')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger, minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await CitasService.cancelar(c.id, motivo.text);
      _cambio = true;
      if (mounted) mostrarMensaje(context, 'Cita cancelada');
      _recargar();
    } catch (e) {
      if (mounted) mostrarMensaje(context, Formatos.error(e), error: true);
    }
  }

  Future<void> _reservarDerivacion(Cita c) async {
    final esps = await CatalogoService.especialidades();
    final esp = esps.where((e) => e.id == c.derivadoA).firstOrNull;
    if (!mounted || esp == null) return;
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ReservarCitaScreen(especialidadInicial: esp, citaOrigenId: c.id)),
    );
    if (ok == true) _cambio = true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _cambio);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Detalle de la cita')),
        body: FutureBuilder(
          future: _cita,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Cargando();
            if (snap.hasError) return ErrorView(mensaje: Formatos.error(snap.error!), onReintentar: _recargar);
            final c = snap.data!;
            final color = c.especialidadColor;
            return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.white, 0.25)!]),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(c.icono, color: Colors.white, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(c.especialidadNombre,
                          style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
                      child: Text(c.estado.etiqueta, style: TextStyle(color: c.estado.color, fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Text(Formatos.diaLargo(c.fecha), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  Text('${Formatos.horaSql(c.horaInicio)} - ${Formatos.horaSql(c.horaFin)} · Turno ${c.turno}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9))),
                  const SizedBox(height: 8),
                  Text('Código ${c.codigo}', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12.5)),
                ]),
              ),
              const SizedBox(height: 16),
              Bloque(
                titulo: 'Información',
                child: Column(children: [
                  InfoFila(icono: Icons.person_rounded, etiqueta: 'Profesional', valor: c.doctorNombre, color: color),
                  if (c.consultorio != null)
                    InfoFila(icono: Icons.location_on_rounded, etiqueta: 'Lugar de atención', valor: c.consultorio!, color: color),
                  if (c.motivo != null) InfoFila(icono: Icons.notes_rounded, etiqueta: 'Motivo', valor: c.motivo!, color: color),
                  InfoFila(
                    icono: Icons.how_to_reg_rounded,
                    etiqueta: 'Asistencia',
                    valor: switch (c.asistio) { true => 'Asistió', false => 'No asistió', null => 'Por registrar' },
                    color: color,
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Bloque(titulo: 'Seguimiento', child: LineaTiempoCita(cita: c)),
              if (c.estado == EstadoCita.atendida && (c.diagnostico != null || c.indicaciones != null)) ...[
                const SizedBox(height: 12),
                Bloque(
                  titulo: 'Resultado de la atención',
                  child: Column(children: [
                    if (c.diagnostico != null)
                      InfoFila(icono: Icons.assignment_rounded, etiqueta: 'Diagnóstico / evaluación', valor: c.diagnostico!, color: AppColors.success),
                    if (c.indicaciones != null)
                      InfoFila(icono: Icons.medication_rounded, etiqueta: 'Indicaciones', valor: c.indicaciones!, color: AppColors.success),
                  ]),
                ),
              ],
              if (c.fueDerivada) ...[
                const SizedBox(height: 12),
                Bloque(
                  titulo: 'Derivación',
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    InfoFila(
                      icono: Icons.alt_route_rounded,
                      etiqueta: 'Derivado a',
                      valor: c.derivadoANombre ?? c.derivacionExterna!,
                      color: AppColors.accent,
                    ),
                    if (c.derivadoANombre != null && c.derivacionExterna != null)
                      InfoFila(icono: Icons.local_hospital_rounded, etiqueta: 'Derivación externa', valor: c.derivacionExterna!, color: AppColors.accent),
                    if (c.motivoDerivacion != null)
                      InfoFila(icono: Icons.notes_rounded, etiqueta: 'Motivo', valor: c.motivoDerivacion!, color: AppColors.accent),
                    if (c.derivadoA != null) ...[
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        onPressed: () => _reservarDerivacion(c),
                        icon: const Icon(Icons.event_rounded),
                        label: Text('Reservar en ${c.derivadoANombre}'),
                      ),
                    ],
                  ]),
                ),
              ],
              if (c.puedeCancelarse) ...[
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
                  onPressed: () => _cancelar(c),
                  icon: const Icon(Icons.event_busy_rounded),
                  label: const Text('Cancelar cita'),
                ),
              ],
            ]);
          },
        ),
      ),
    );
  }
}
