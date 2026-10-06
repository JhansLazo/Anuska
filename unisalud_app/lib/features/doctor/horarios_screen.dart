import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatos.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/horario.dart';
import '../../data/services/catalogo_service.dart';

/// Horario semanal de atención de un profesional (lo usa el profesional y el admin).
class HorariosScreen extends StatefulWidget {
  const HorariosScreen({super.key, required this.doctorId, required this.titulo});
  final String doctorId;
  final String titulo;

  @override
  State<HorariosScreen> createState() => _HorariosScreenState();
}

class _HorariosScreenState extends State<HorariosScreen> {
  late Future<List<Horario>> _horarios;

  @override
  void initState() {
    super.initState();
    _horarios = CatalogoService.horarios(widget.doctorId);
  }

  void _recargar() => setState(() => _horarios = CatalogoService.horarios(widget.doctorId));

  String _hhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _agregar() async {
    final dias = <int>{1};
    var inicio = const TimeOfDay(hour: 8, minute: 0);
    var fin = const TimeOfDay(hour: 12, minute: 0);
    var duracion = 30;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Nuevo bloque de atención', style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              const Text('Días', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (var d = 1; d <= 7; d++)
                  FilterChip(
                    label: Text(Formatos.diasSemana[d - 1].substring(0, 3)),
                    selected: dias.contains(d),
                    onSelected: (v) => setS(() => v ? dias.add(d) : dias.remove(d)),
                  ),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.login_rounded),
                    label: Text('Desde ${_hhmm(inicio)}'),
                    onPressed: () async {
                      final t = await showTimePicker(context: c, initialTime: inicio);
                      if (t != null) setS(() => inicio = t);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.logout_rounded),
                    label: Text('Hasta ${_hhmm(fin)}'),
                    onPressed: () async {
                      final t = await showTimePicker(context: c, initialTime: fin);
                      if (t != null) setS(() => fin = t);
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: duracion,
                decoration: const InputDecoration(labelText: 'Duración de cada cita'),
                items: [for (final m in [15, 20, 30, 40, 45, 60]) DropdownMenuItem(value: m, child: Text('$m minutos'))],
                onChanged: (v) => duracion = v ?? 30,
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Guardar')),
            ]),
          ),
        ),
      ),
    );
    if (ok != true) return;
    if (dias.isEmpty) {
      if (mounted) mostrarMensaje(context, 'Elige al menos un día', error: true);
      return;
    }
    if (inicio.hour * 60 + inicio.minute >= fin.hour * 60 + fin.minute) {
      if (mounted) mostrarMensaje(context, 'La hora de fin debe ser posterior a la de inicio', error: true);
      return;
    }
    try {
      for (final d in dias) {
        await CatalogoService.crearHorario(
          doctorId: widget.doctorId,
          diaSemana: d,
          horaInicio: _hhmm(inicio),
          horaFin: _hhmm(fin),
          duracion: duracion,
        );
      }
      if (mounted) mostrarMensaje(context, 'Horario agregado');
      _recargar();
    } catch (e) {
      if (mounted) mostrarMensaje(context, Formatos.error(e), error: true);
    }
  }

  Future<void> _eliminar(Horario h) async {
    if (!await confirmar(context,
        titulo: 'Eliminar bloque',
        mensaje: 'Las citas ya reservadas se mantienen, pero no se podrán reservar nuevas en este bloque.',
        aceptar: 'Eliminar',
        peligro: true)) {
      return;
    }
    try {
      await CatalogoService.eliminarHorario(h.id);
      _recargar();
    } catch (e) {
      if (mounted) mostrarMensaje(context, Formatos.error(e), error: true);
    }
  }

  Future<void> _alternar(Horario h, bool v) async {
    try {
      await CatalogoService.cambiarEstadoHorario(h.id, v);
      _recargar();
    } catch (e) {
      if (mounted) mostrarMensaje(context, Formatos.error(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregar,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agregar horario'),
      ),
      body: FutureBuilder(
        future: _horarios,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Cargando();
          if (snap.hasError) return ErrorView(mensaje: Formatos.error(snap.error!), onReintentar: _recargar);
          final hs = snap.data!;
          if (hs.isEmpty) {
            return const VacioView(
              icono: Icons.edit_calendar_rounded,
              titulo: 'Aún no hay horarios',
              mensaje: 'Agrega los días y horas en que atiendes. Los pacientes solo podrán reservar en esos bloques.',
            );
          }
          return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), children: [
            for (var d = 1; d <= 7; d++)
              if (hs.any((h) => h.diaSemana == d)) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Text(Formatos.diasSemana[d - 1], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                for (final h in hs.where((h) => h.diaSemana == d)) ...[
                  Card(
                    child: ListTile(
                      leading: Icon(
                        h.horaInicio.compareTo('13:00') < 0 ? Icons.wb_sunny_rounded : Icons.wb_twilight_rounded,
                        color: h.activo ? AppColors.accent : Theme.of(context).disabledColor,
                      ),
                      title: Text('${Formatos.horaSql(h.horaInicio)} - ${Formatos.horaSql(h.horaFin)}',
                          style: TextStyle(fontWeight: FontWeight.w800, color: h.activo ? null : Theme.of(context).disabledColor)),
                      subtitle: Text('Citas de ${h.duracionMinutos} min${h.activo ? '' : ' · pausado'}'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Switch(value: h.activo, onChanged: (v) => _alternar(h, v)),
                        IconButton(tooltip: 'Eliminar', onPressed: () => _eliminar(h), icon: const Icon(Icons.delete_outline_rounded)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
          ]);
        },
      ),
    );
  }
}
