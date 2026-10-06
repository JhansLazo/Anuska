import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatos.dart';
import '../../core/widgets/cita_card.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/cita.dart';
import '../../data/models/especialidad.dart';
import '../../data/services/catalogo_service.dart';
import '../../data/services/citas_service.dart';
import '../../data/services/sesion.dart';
import 'cita_detalle_screen.dart';
import 'reservar_cita_screen.dart';

class InicioPaciente extends StatefulWidget {
  const InicioPaciente({super.key, required this.onVerCitas, required this.onVerAvisos, required this.noLeidas});
  final VoidCallback onVerCitas;
  final VoidCallback onVerAvisos;
  final int noLeidas;

  @override
  State<InicioPaciente> createState() => _InicioPacienteState();
}

class _InicioPacienteState extends State<InicioPaciente> {
  late Future<(List<Especialidad>, List<Cita>)> _datos;

  @override
  void initState() {
    super.initState();
    _datos = _cargar();
  }

  Future<(List<Especialidad>, List<Cita>)> _cargar() async {
    final perfil = Sesion.instancia.perfil!;
    final r = await Future.wait([
      CatalogoService.especialidades(),
      CitasService.delPaciente(perfil.id),
    ]);
    return (r[0] as List<Especialidad>, r[1] as List<Cita>);
  }

  Future<void> _refrescar() async {
    setState(() => _datos = _cargar());
    await _datos;
  }

  Future<void> _reservar({Especialidad? esp, int? origen}) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ReservarCitaScreen(especialidadInicial: esp, citaOrigenId: origen)),
    );
    if (ok == true) _refrescar();
  }

  Future<void> _abrir(Cita c) async {
    final cambio = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => CitaDetalleScreen(citaId: c.id)));
    if (cambio == true) _refrescar();
  }

  @override
  Widget build(BuildContext context) {
    final perfil = Sesion.instancia.perfil!;
    return RefreshIndicator(
      onRefresh: _refrescar,
      child: FutureBuilder(
        future: _datos,
        builder: (context, snap) {
          return CustomScrollView(slivers: [
            SliverToBoxAdapter(child: _Encabezado(nombre: perfil.primerNombre, noLeidas: widget.noLeidas, onAvisos: widget.onVerAvisos)),
            if (snap.connectionState != ConnectionState.done)
              const SliverFillRemaining(child: Cargando())
            else if (snap.hasError)
              SliverFillRemaining(child: ErrorView(mensaje: Formatos.error(snap.error!), onReintentar: _refrescar))
            else
              ..._contenido(snap.data!.$1, snap.data!.$2),
          ]);
        },
      ),
    );
  }

  List<Widget> _contenido(List<Especialidad> especialidades, List<Cita> citas) {
    final proximas = citas.where((c) => c.estado.activa && !c.inicio.isBefore(Formatos.soloFecha(DateTime.now()))).toList()
      ..sort((a, b) => a.inicio.compareTo(b.inicio));
    final atendidas = citas.where((c) => c.estado == EstadoCita.atendida).length;
    final origenesUsados = citas.where((c) => c.citaOrigenId != null && c.estado != EstadoCita.cancelada).map((c) => c.citaOrigenId).toSet();
    final derivacionPendiente = citas
        .where((c) => c.estado == EstadoCita.atendida && c.derivadoA != null && !origenesUsados.contains(c.id))
        .firstOrNull;

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        sliver: SliverList.list(children: [
          if (derivacionPendiente != null) ...[
            _AvisoDerivacion(
              cita: derivacionPendiente,
              onReservar: () => _reservar(
                esp: especialidades.where((e) => e.id == derivacionPendiente.derivadoA).firstOrNull,
                origen: derivacionPendiente.id,
              ),
            ),
            const SizedBox(height: 20),
          ],
          SeccionTitulo(
            'Tu próxima cita',
            accion: proximas.length > 1
                ? TextButton(onPressed: widget.onVerCitas, child: Text('Ver ${proximas.length}'))
                : null,
          ),
          if (proximas.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(children: [
                  const Icon(Icons.event_available_rounded, color: AppColors.primary, size: 36),
                  const SizedBox(width: 14),
                  const Expanded(child: Text('No tienes citas programadas. Elige un área abajo para reservar.')),
                ]),
              ),
            )
          else
            CitaCard(cita: proximas.first, vista: VistaCita.paciente, onTap: () => _abrir(proximas.first)),
          const SizedBox(height: 24),
          const SeccionTitulo('¿Qué atención necesitas?'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.05,
            children: [for (final e in especialidades) _TarjetaEspecialidad(esp: e, onTap: () => _reservar(esp: e))],
          ),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: KpiTile(titulo: 'Próximas', valor: '${proximas.length}', icono: Icons.upcoming_rounded, color: AppColors.info),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: KpiTile(titulo: 'Atenciones', valor: '$atendidas', icono: Icons.verified_rounded, color: AppColors.success),
            ),
          ]),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => _reservar(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Reservar nueva cita'),
          ),
        ]),
      ),
    ];
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.nombre, required this.noLeidas, required this.onAvisos});
  final String nombre;
  final int noLeidas;
  final VoidCallback onAvisos;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: AppColors.headerGradient,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 28),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(Formatos.diaLargo(DateTime.now()), style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
                  const SizedBox(height: 4),
                  Text('Hola, $nombre',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('¿Cómo podemos cuidarte hoy?', style: TextStyle(color: Colors.white.withValues(alpha: 0.9))),
                ]),
              ),
              IconButton.filledTonal(
                style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.2), minimumSize: const Size(48, 48)),
                tooltip: 'Avisos',
                onPressed: onAvisos,
                icon: Badge(
                  isLabelVisible: noLeidas > 0,
                  label: Text('$noLeidas'),
                  child: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                ),
              ),
            ]),
          ),
        ),
      );
}

class _TarjetaEspecialidad extends StatelessWidget {
  const _TarjetaEspecialidad({required this.esp, required this.onTap});
  final Especialidad esp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: esp.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
                child: Icon(esp.icono, color: esp.color, size: 28),
              ),
              const Spacer(),
              Text(esp.nombre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 2),
              Row(children: [
                Text('Reservar', style: TextStyle(color: esp.color, fontWeight: FontWeight.w700, fontSize: 13)),
                Icon(Icons.arrow_forward_rounded, size: 16, color: esp.color),
              ]),
            ]),
          ),
        ),
      );
}

class _AvisoDerivacion extends StatelessWidget {
  const _AvisoDerivacion({required this.cita, required this.onReservar});
  final Cita cita;
  final VoidCallback onReservar;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.alt_route_rounded, color: AppColors.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Tienes una derivación a ${cita.derivadoANombre}',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 6),
          Text('${cita.doctorNombre} (${cita.especialidadNombre}) te derivó'
              '${cita.motivoDerivacion != null ? ': ${cita.motivoDerivacion}' : '.'}'),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
            onPressed: onReservar,
            icon: const Icon(Icons.event_rounded),
            label: const Text('Reservar ahora'),
          ),
        ]),
      );
}
