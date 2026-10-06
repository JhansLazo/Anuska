import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatos.dart';
import '../../core/widgets/cita_card.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/cita.dart';
import '../../data/services/citas_service.dart';
import '../../data/services/notificaciones_service.dart';
import '../../data/services/sesion.dart';
import '../comun/notificaciones_screen.dart';
import 'gestionar_cita_screen.dart';

/// Agenda diaria del profesional.
class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  DateTime _dia = Formatos.soloFecha(DateTime.now());
  late Future<List<Cita>> _citas;
  int _noLeidas = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    _citas = CitasService.agendaDelDia(Sesion.instancia.perfil!.id, _dia);
    NotificacionesService.noLeidas().then((n) {
      if (mounted) setState(() => _noLeidas = n);
    }).catchError((_) {});
  }

  void _cambiarDia(DateTime d) => setState(() {
        _dia = Formatos.soloFecha(d);
        _cargar();
      });

  Future<void> _elegirFecha() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dia,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 120)),
    );
    if (d != null) _cambiarDia(d);
  }

  Future<void> _abrir(Cita c) async {
    final cambio = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => GestionarCitaScreen(citaId: c.id)));
    if (cambio == true) setState(_cargar);
  }

  @override
  Widget build(BuildContext context) {
    final perfil = Sesion.instancia.perfil!;
    final esHoy = _dia == Formatos.soloFecha(DateTime.now());
    final lunes = _dia.subtract(Duration(days: _dia.weekday - 1));
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hola, ${perfil.primerNombre}'),
          Text(perfil.especialidad?.nombre ?? 'Profesional',
              style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor, fontWeight: FontWeight.w500)),
        ]),
        actions: [
          IconButton(
            tooltip: 'Avisos',
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificacionesScreen()));
              setState(_cargar);
            },
            icon: Badge(isLabelVisible: _noLeidas > 0, label: Text('$_noLeidas'), child: const Icon(Icons.notifications_none_rounded)),
          ),
          IconButton(tooltip: 'Elegir fecha', onPressed: _elegirFecha, icon: const Icon(Icons.calendar_month_rounded)),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [
            IconButton(
              tooltip: 'Semana anterior',
              onPressed: () => _cambiarDia(_dia.subtract(const Duration(days: 7))),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            for (var i = 0; i < 7; i++)
              Expanded(child: _DiaChip(dia: lunes.add(Duration(days: i)), seleccionado: lunes.add(Duration(days: i)) == _dia, onTap: _cambiarDia)),
            IconButton(
              tooltip: 'Semana siguiente',
              onPressed: () => _cambiarDia(_dia.add(const Duration(days: 7))),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
          child: Row(children: [
            Expanded(child: Text(Formatos.diaLargo(_dia), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
            if (!esHoy)
              TextButton(onPressed: () => _cambiarDia(DateTime.now()), child: const Text('Ir a hoy')),
          ]),
        ),
        Expanded(
          child: FutureBuilder(
            future: _citas,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const Cargando();
              if (snap.hasError) return ErrorView(mensaje: Formatos.error(snap.error!), onReintentar: () => setState(_cargar));
              final citas = snap.data!;
              final activas = citas.where((c) => c.estado != EstadoCita.cancelada).toList();
              final porAtender = citas.where((c) => c.estado.activa).length;
              final atendidas = citas.where((c) => c.estado == EstadoCita.atendida).length;
              final faltas = citas.where((c) => c.estado == EstadoCita.noAsistio).length;
              return RefreshIndicator(
                onRefresh: () async {
                  setState(_cargar);
                  await _citas;
                },
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
                  Row(children: [
                    _Resumen(valor: porAtender, texto: 'Por atender', color: AppColors.warning),
                    const SizedBox(width: 8),
                    _Resumen(valor: atendidas, texto: 'Atendidos', color: AppColors.success),
                    const SizedBox(width: 8),
                    _Resumen(valor: faltas, texto: 'No vinieron', color: AppColors.danger),
                  ]),
                  const SizedBox(height: 16),
                  if (activas.isEmpty)
                    SizedBox(
                      height: 300,
                      child: VacioView(
                        icono: Icons.free_breakfast_rounded,
                        titulo: 'Sin citas este día',
                        mensaje: 'Cuando un paciente reserve, aparecerá aquí.',
                        accion: citas.isNotEmpty
                            ? Text('${citas.length} cita(s) cancelada(s)', style: TextStyle(color: cs.primary))
                            : null,
                      ),
                    ),
                  for (final turno in ['mañana', 'tarde'])
                    if (activas.any((c) => c.turno == turno)) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10, top: 4),
                        child: Row(children: [
                          Icon(turno == 'mañana' ? Icons.wb_sunny_rounded : Icons.wb_twilight_rounded, color: AppColors.accent, size: 20),
                          const SizedBox(width: 6),
                          Text(turno == 'mañana' ? 'Turno mañana' : 'Turno tarde', style: const TextStyle(fontWeight: FontWeight.w800)),
                        ]),
                      ),
                      for (final c in activas.where((c) => c.turno == turno)) ...[
                        CitaCard(cita: c, vista: VistaCita.profesional, onTap: () => _abrir(c)),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 8),
                    ],
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _DiaChip extends StatelessWidget {
  const _DiaChip({required this.dia, required this.seleccionado, required this.onTap});
  final DateTime dia;
  final bool seleccionado;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hoy = dia == Formatos.soloFecha(DateTime.now());
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => onTap(dia),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: seleccionado ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: hoy && !seleccionado ? Border.all(color: cs.primary) : null,
        ),
        child: Column(children: [
          Text(Formatos.diaSemanaCorto(dia).substring(0, 2),
              style: TextStyle(fontSize: 12, color: seleccionado ? Colors.white : Theme.of(context).hintColor)),
          const SizedBox(height: 2),
          Text('${dia.day}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: seleccionado ? Colors.white : null)),
        ]),
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.valor, required this.texto, required this.color});
  final int valor;
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            Text('$valor', style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
            Text(texto, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}
