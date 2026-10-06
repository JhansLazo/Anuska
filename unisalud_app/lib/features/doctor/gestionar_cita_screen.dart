import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatos.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/cita.dart';
import '../../data/models/especialidad.dart';
import '../../data/models/perfil.dart';
import '../../data/services/catalogo_service.dart';
import '../../data/services/citas_service.dart';
import '../comun/linea_tiempo.dart';

/// Ficha de la cita para el profesional (o admin): asistencia, atención y derivación.
class GestionarCitaScreen extends StatefulWidget {
  const GestionarCitaScreen({super.key, required this.citaId});
  final int citaId;

  @override
  State<GestionarCitaScreen> createState() => _GestionarCitaScreenState();
}

class _GestionarCitaScreenState extends State<GestionarCitaScreen> {
  late Future<(Cita, List<Cita>)> _datos;
  bool _cambio = false;
  bool _trabajando = false;

  @override
  void initState() {
    super.initState();
    _datos = _cargar();
  }

  Future<(Cita, List<Cita>)> _cargar() async {
    final c = await CitasService.obtener(widget.citaId);
    final historial = await CitasService.historialPaciente(c.pacienteId);
    return (c, historial.where((h) => h.id != c.id).toList());
  }

  void _recargar() => setState(() => _datos = _cargar());

  Future<void> _accion(Future<void> Function() f, String ok) async {
    setState(() => _trabajando = true);
    try {
      await f();
      _cambio = true;
      if (mounted) mostrarMensaje(context, ok);
      _recargar();
    } catch (e) {
      if (mounted) mostrarMensaje(context, Formatos.error(e), error: true);
    }
    if (mounted) setState(() => _trabajando = false);
  }

  Future<void> _noAsistio(Cita c) async {
    if (!await confirmar(context,
        titulo: 'Marcar inasistencia',
        mensaje: '¿Confirmas que ${c.pacienteNombre} no se presentó a la cita?',
        aceptar: 'Sí, no asistió',
        peligro: true)) {
      return;
    }
    await _accion(() => CitasService.marcarNoAsistio(c.id), 'Inasistencia registrada');
  }

  Future<void> _cancelar(Cita c) async {
    final motivo = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar cita'),
        content: TextField(controller: motivo, decoration: const InputDecoration(labelText: 'Motivo (se avisará al paciente)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Volver')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger, minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar cita'),
          ),
        ],
      ),
    );
    if (ok == true) await _accion(() => CitasService.cancelar(c.id, motivo.text), 'Cita cancelada');
  }

  Future<void> _atender(Cita c) async {
    final guardado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => _FormularioAtencion(cita: c)),
    );
    if (guardado == true) {
      _cambio = true;
      if (mounted) mostrarMensaje(context, 'Atención registrada');
      _recargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _cambio);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Gestionar cita')),
        body: FutureBuilder(
          future: _datos,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Cargando();
            if (snap.hasError) return ErrorView(mensaje: Formatos.error(snap.error!), onReintentar: _recargar);
            final (c, historial) = snap.data!;
            return Column(children: [
              Expanded(
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
                  _TarjetaPaciente(cita: c),
                  const SizedBox(height: 12),
                  Bloque(
                    titulo: 'Cita ${c.codigo}',
                    child: Column(children: [
                      Row(children: [EstadoChip(c.estado), const Spacer(), Etiqueta(c.especialidadNombre, color: c.especialidadColor, icono: c.icono)]),
                      const SizedBox(height: 6),
                      InfoFila(icono: Icons.calendar_today_rounded, etiqueta: 'Fecha', valor: Formatos.diaLargo(c.fecha)),
                      InfoFila(
                        icono: Icons.access_time_rounded,
                        etiqueta: 'Horario',
                        valor: '${Formatos.horaSql(c.horaInicio)} - ${Formatos.horaSql(c.horaFin)} · Turno ${c.turno}',
                      ),
                      InfoFila(icono: Icons.person_rounded, etiqueta: 'Profesional', valor: c.doctorNombre),
                      if (c.motivo != null) InfoFila(icono: Icons.notes_rounded, etiqueta: 'Motivo del paciente', valor: c.motivo!),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Bloque(titulo: 'Seguimiento', child: LineaTiempoCita(cita: c)),
                  if (c.estado == EstadoCita.atendida) ...[
                    const SizedBox(height: 12),
                    Bloque(
                      titulo: 'Registro de atención',
                      child: Column(children: [
                        InfoFila(icono: Icons.assignment_rounded, etiqueta: 'Diagnóstico / evaluación', valor: c.diagnostico ?? '—', color: AppColors.success),
                        InfoFila(icono: Icons.medication_rounded, etiqueta: 'Indicaciones', valor: c.indicaciones ?? '—', color: AppColors.success),
                        if (c.observaciones != null)
                          InfoFila(icono: Icons.sticky_note_2_rounded, etiqueta: 'Observaciones', valor: c.observaciones!, color: AppColors.success),
                        if (c.fueDerivada)
                          InfoFila(
                            icono: Icons.alt_route_rounded,
                            etiqueta: 'Derivado a',
                            valor: [c.derivadoANombre, c.derivacionExterna].whereType<String>().join(' · ') +
                                (c.motivoDerivacion != null ? '\nMotivo: ${c.motivoDerivacion}' : ''),
                            color: AppColors.accent,
                          ),
                      ]),
                    ),
                  ],
                  if (historial.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Bloque(
                      titulo: 'Atenciones anteriores',
                      child: Column(children: [
                        for (final h in historial.take(5))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(h.icono, color: h.especialidadColor),
                            title: Text('${h.especialidadNombre} · ${Formatos.fechaCorta(h.fecha)}',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            subtitle: Text(h.diagnostico ?? 'Sin diagnóstico registrado', maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                      ]),
                    ),
                  ],
                ]),
              ),
              _acciones(c),
            ]);
          },
        ),
      ),
    );
  }

  Widget _acciones(Cita c) {
    if (c.estado == EstadoCita.cancelada || c.estado == EstadoCita.noAsistio) return const SizedBox.shrink();
    final botones = <Widget>[];
    if (c.estado == EstadoCita.atendida) {
      botones.add(OutlinedButton.icon(
        onPressed: () => _atender(c),
        icon: const Icon(Icons.edit_note_rounded),
        label: const Text('Editar registro de atención'),
      ));
    } else {
      botones.add(FilledButton.icon(
        onPressed: _trabajando ? null : () => _atender(c),
        icon: const Icon(Icons.medical_information_rounded),
        label: const Text('Atender y registrar'),
      ));
      botones.add(const SizedBox(height: 10));
      botones.add(Row(children: [
        if (c.horaLlegada == null)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _trabajando ? null : () => _accion(() => CitasService.registrarLlegada(c.id), 'Llegada registrada'),
              icon: const Icon(Icons.how_to_reg_rounded),
              label: const Text('Llegó'),
            ),
          )
        else if (c.estado == EstadoCita.pendiente)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _trabajando ? null : () => _accion(() => CitasService.confirmar(c.id), 'Cita confirmada'),
              icon: const Icon(Icons.event_available_rounded),
              label: const Text('Confirmar'),
            ),
          ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: _trabajando ? null : () => _noAsistio(c),
            icon: const Icon(Icons.person_off_rounded),
            label: const Text('No vino'),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.outlined(
          tooltip: 'Cancelar cita',
          style: IconButton.styleFrom(minimumSize: const Size(52, 52)),
          onPressed: _trabajando ? null : () => _cancelar(c),
          icon: const Icon(Icons.event_busy_rounded),
        ),
      ]));
      if (c.estado == EstadoCita.pendiente && c.horaLlegada == null) {
        botones.insert(
          0,
          TextButton.icon(
            onPressed: _trabajando ? null : () => _accion(() => CitasService.confirmar(c.id), 'Cita confirmada'),
            icon: const Icon(Icons.event_available_rounded),
            label: const Text('Confirmar cita sin registrar llegada'),
          ),
        );
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: botones),
        ),
      ),
    );
  }
}

class _TarjetaPaciente extends StatelessWidget {
  const _TarjetaPaciente({required this.cita});
  final Cita cita;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              AvatarIniciales(
                cita.pacienteNombre.split(' ').where((s) => s.isNotEmpty).take(2).map((s) => s[0]).join().toUpperCase(),
                radio: 26,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(cita.pacienteNombre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                  Text(tiposUsuario[cita.pacienteTipo] ?? 'Paciente', style: TextStyle(color: Theme.of(context).hintColor)),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (cita.pacienteDni != null) Etiqueta('DNI ${cita.pacienteDni}', color: AppColors.primary, icono: Icons.badge_rounded),
              if (cita.pacienteCodigo != null)
                Etiqueta('Cód. ${cita.pacienteCodigo}', color: AppColors.primary, icono: Icons.credit_card_rounded),
              if (cita.pacienteTelefono != null)
                Etiqueta(cita.pacienteTelefono!, color: AppColors.primary, icono: Icons.phone_rounded),
              if (cita.pacienteEscuela != null)
                Etiqueta(cita.pacienteEscuela!, color: AppColors.primary, icono: Icons.apartment_rounded),
            ]),
          ]),
        ),
      );
}

/// Formulario para registrar (o editar) la atención y la derivación.
class _FormularioAtencion extends StatefulWidget {
  const _FormularioAtencion({required this.cita});
  final Cita cita;

  @override
  State<_FormularioAtencion> createState() => _FormularioAtencionState();
}

class _FormularioAtencionState extends State<_FormularioAtencion> {
  late final _diagnostico = TextEditingController(text: widget.cita.diagnostico);
  late final _indicaciones = TextEditingController(text: widget.cita.indicaciones);
  late final _observaciones = TextEditingController(text: widget.cita.observaciones);
  late final _externa = TextEditingController(text: widget.cita.derivacionExterna);
  late final _motivoDerivacion = TextEditingController(text: widget.cita.motivoDerivacion);
  late bool _derivar = widget.cita.fueDerivada;
  late int? _derivadoA = widget.cita.derivadoA;
  List<Especialidad> _especialidades = [];
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    CatalogoService.especialidades().then((e) {
      if (mounted) setState(() => _especialidades = e);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    for (final c in [_diagnostico, _indicaciones, _observaciones, _externa, _motivoDerivacion]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_diagnostico.text.trim().isEmpty) {
      mostrarMensaje(context, 'Escribe al menos el diagnóstico o evaluación', error: true);
      return;
    }
    if (_derivar && _derivadoA == null && _externa.text.trim().isEmpty) {
      mostrarMensaje(context, 'Indica a qué área o institución se deriva', error: true);
      return;
    }
    setState(() => _guardando = true);
    try {
      await CitasService.registrarAtencion(
        citaId: widget.cita.id,
        diagnostico: _diagnostico.text,
        indicaciones: _indicaciones.text,
        observaciones: _observaciones.text,
        derivadoA: _derivar ? _derivadoA : null,
        derivacionExterna: _derivar ? _externa.text : null,
        motivoDerivacion: _derivar ? _motivoDerivacion.text : null,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) mostrarMensaje(context, Formatos.error(e), error: true);
    }
    if (mounted) setState(() => _guardando = false);
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14);
    return Scaffold(
      appBar: AppBar(title: Text('Atención · ${widget.cita.pacienteNombre}')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
          child: const Row(children: [
            Icon(Icons.info_outline_rounded, color: AppColors.info),
            SizedBox(width: 10),
            Expanded(child: Text('Al guardar se registra automáticamente la fecha y hora exacta de la atención y la asistencia del paciente.')),
          ]),
        ),
        gap,
        TextField(
          controller: _diagnostico,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Diagnóstico / evaluación *', alignLabelWithHint: true),
        ),
        gap,
        TextField(
          controller: _indicaciones,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Indicaciones / tratamiento', alignLabelWithHint: true),
        ),
        gap,
        TextField(
          controller: _observaciones,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Observaciones', alignLabelWithHint: true),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(children: [
            SwitchListTile(
              value: _derivar,
              onChanged: (v) => setState(() => _derivar = v),
              secondary: const Icon(Icons.alt_route_rounded, color: AppColors.accent),
              title: const Text('Derivar al paciente', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('A otra área de la universidad o a una institución externa'),
            ),
            if (_derivar)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(children: [
                  DropdownButtonFormField<int?>(
                    initialValue: _derivadoA,
                    decoration: const InputDecoration(labelText: 'Área interna'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Ninguna (solo externa)')),
                      for (final e in _especialidades) DropdownMenuItem(value: e.id, child: Text(e.nombre)),
                    ],
                    onChanged: (v) => setState(() => _derivadoA = v),
                  ),
                  gap,
                  TextField(
                    controller: _externa,
                    decoration: const InputDecoration(labelText: 'Institución externa (opcional)', hintText: 'Ej.: Hospital Regional - Traumatología'),
                  ),
                  gap,
                  TextField(
                    controller: _motivoDerivacion,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Motivo de la derivación'),
                  ),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _guardando ? null : _guardar,
          icon: _guardando
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
              : const Icon(Icons.save_rounded),
          label: const Text('Guardar atención'),
        ),
      ]),
    );
  }
}
