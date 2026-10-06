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
import '../doctor/gestionar_cita_screen.dart';

/// Panel del día para Bienestar Universitario.
class PanelAdminScreen extends StatefulWidget {
  const PanelAdminScreen({super.key, required this.onVerCitas});
  final VoidCallback onVerCitas;

  @override
  State<PanelAdminScreen> createState() => _PanelAdminScreenState();
}

class _PanelAdminScreenState extends State<PanelAdminScreen> {
  late Future<(List<Cita>, List<Especialidad>, int)> _datos;

  @override
  void initState() {
    super.initState();
    _datos = _cargar();
  }

  Future<(List<Cita>, List<Especialidad>, int)> _cargar() async {
    final hoy = Formatos.soloFecha(DateTime.now());
    final r = await Future.wait([
      CitasService.buscar(desde: hoy, hasta: hoy),
      CatalogoService.especialidades(),
      CatalogoService.profesionales(),
    ]);
    return (r[0] as List<Cita>, r[1] as List<Especialidad>, (r[2] as List).length);
  }

  Future<void> _refrescar() async {
    setState(() => _datos = _cargar());
    await _datos;
  }

  @override
  Widget build(BuildContext context) {
    final perfil = Sesion.instancia.perfil!;
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hola, ${perfil.primerNombre}'),
          Text(Formatos.diaLargo(DateTime.now()),
              style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor, fontWeight: FontWeight.w500)),
        ]),
      ),
      body: RefreshIndicator(
        onRefresh: _refrescar,
        child: FutureBuilder(
          future: _datos,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Cargando();
            if (snap.hasError) return ErrorView(mensaje: Formatos.error(snap.error!), onReintentar: _refrescar);
            final (citas, especialidades, nProfesionales) = snap.data!;
            final activas = citas.where((c) => c.estado != EstadoCita.cancelada).toList();
            final enEspera = activas.where((c) => c.estado.activa && c.horaLlegada != null).toList();
            final proximas = activas.where((c) => c.estado.activa && c.esFutura).toList()
              ..sort((a, b) => a.inicio.compareTo(b.inicio));
            int cuenta(EstadoCita e) => citas.where((c) => c.estado == e).length;

            return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.55,
                children: [
                  KpiTile(titulo: 'Citas de hoy', valor: '${activas.length}', icono: Icons.today_rounded, color: AppColors.primary),
                  KpiTile(titulo: 'Atendidas', valor: '${cuenta(EstadoCita.atendida)}', icono: Icons.check_circle_rounded, color: AppColors.success),
                  KpiTile(titulo: 'En espera (llegaron)', valor: '${enEspera.length}', icono: Icons.chair_rounded, color: AppColors.info),
                  KpiTile(titulo: 'No asistieron', valor: '${cuenta(EstadoCita.noAsistio)}', icono: Icons.person_off_rounded, color: AppColors.danger),
                ],
              ),
              const SizedBox(height: 16),
              Bloque(
                titulo: 'Hoy por área',
                child: Column(children: [
                  for (final e in especialidades)
                    BarraDato(
                      etiqueta: e.nombre,
                      valor: activas.where((c) => c.especialidadId == e.id).length,
                      maximo: activas.isEmpty ? 1 : activas.length,
                      color: e.color,
                    ),
                ]),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.medical_services_rounded)),
                  title: Text('$nProfesionales profesionales activos', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Gestiona roles y horarios en la pestaña Usuarios'),
                ),
              ),
              const SizedBox(height: 20),
              SeccionTitulo('Próximas de hoy', accion: TextButton(onPressed: widget.onVerCitas, child: const Text('Ver todas'))),
              if (proximas.isEmpty)
                Text('No quedan citas pendientes hoy.', style: TextStyle(color: Theme.of(context).hintColor))
              else
                for (final c in proximas.take(8)) ...[
                  CitaCard(
                    cita: c,
                    vista: VistaCita.admin,
                    onTap: () async {
                      final cambio = await Navigator.push<bool>(
                          context, MaterialPageRoute(builder: (_) => GestionarCitaScreen(citaId: c.id)));
                      if (cambio == true) _refrescar();
                    },
                  ),
                  const SizedBox(height: 10),
                ],
            ]);
          },
        ),
      ),
    );
  }
}
