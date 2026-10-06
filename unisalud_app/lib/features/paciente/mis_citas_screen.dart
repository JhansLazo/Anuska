import 'package:flutter/material.dart';

import '../../core/utils/formatos.dart';
import '../../core/widgets/cita_card.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/cita.dart';
import '../../data/services/citas_service.dart';
import '../../data/services/sesion.dart';
import 'cita_detalle_screen.dart';
import 'reservar_cita_screen.dart';

class MisCitasScreen extends StatefulWidget {
  const MisCitasScreen({super.key});

  @override
  State<MisCitasScreen> createState() => _MisCitasScreenState();
}

class _MisCitasScreenState extends State<MisCitasScreen> {
  late Future<List<Cita>> _citas;

  @override
  void initState() {
    super.initState();
    _citas = CitasService.delPaciente(Sesion.instancia.perfil!.id);
  }

  Future<void> _refrescar() async {
    setState(() => _citas = CitasService.delPaciente(Sesion.instancia.perfil!.id));
    await _citas;
  }

  Future<void> _abrir(Cita c) async {
    final cambio = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => CitaDetalleScreen(citaId: c.id)));
    if (cambio == true) _refrescar();
  }

  Future<void> _nueva() async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const ReservarCitaScreen()));
    if (ok == true) _refrescar();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mis citas'),
          bottom: const TabBar(tabs: [Tab(text: 'Próximas'), Tab(text: 'Historial')]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _nueva,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Reservar'),
        ),
        body: FutureBuilder(
          future: _citas,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Cargando();
            if (snap.hasError) return ErrorView(mensaje: Formatos.error(snap.error!), onReintentar: _refrescar);
            final hoy = Formatos.soloFecha(DateTime.now());
            final todas = snap.data!;
            final proximas = todas.where((c) => c.estado.activa && !c.fecha.isBefore(hoy)).toList()
              ..sort((a, b) => a.inicio.compareTo(b.inicio));
            final historial = todas.where((c) => !proximas.contains(c)).toList();
            return TabBarView(children: [
              _lista(proximas, const VacioView(
                icono: Icons.event_available_rounded,
                titulo: 'Sin citas próximas',
                mensaje: 'Toca "Reservar" para agendar tu atención.',
              )),
              _lista(historial, const VacioView(
                icono: Icons.history_rounded,
                titulo: 'Aún no tienes historial',
                mensaje: 'Aquí verás tus citas atendidas, canceladas o perdidas.',
              )),
            ]);
          },
        ),
      ),
    );
  }

  Widget _lista(List<Cita> citas, Widget vacio) => RefreshIndicator(
        onRefresh: _refrescar,
        child: citas.isEmpty
            ? ListView(children: [SizedBox(height: 420, child: vacio)])
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: citas.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) => CitaCard(cita: citas[i], vista: VistaCita.paciente, onTap: () => _abrir(citas[i])),
              ),
      );
}
