import 'package:flutter/material.dart';

import '../../core/utils/formatos.dart';
import '../../core/widgets/cita_card.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/cita.dart';
import '../../data/models/especialidad.dart';
import '../../data/services/catalogo_service.dart';
import '../../data/services/citas_service.dart';
import '../doctor/gestionar_cita_screen.dart';

/// Todas las citas de la universidad con filtros y búsqueda.
class CitasAdminScreen extends StatefulWidget {
  const CitasAdminScreen({super.key});

  @override
  State<CitasAdminScreen> createState() => _CitasAdminScreenState();
}

class _CitasAdminScreenState extends State<CitasAdminScreen> {
  DateTimeRange _rango = DateTimeRange(start: Formatos.soloFecha(DateTime.now()), end: Formatos.soloFecha(DateTime.now()));
  int? _especialidadId;
  EstadoCita? _estado;
  String _busqueda = '';
  List<Especialidad> _especialidades = [];
  late Future<List<Cita>> _citas;

  @override
  void initState() {
    super.initState();
    _cargar();
    CatalogoService.especialidades().then((e) {
      if (mounted) setState(() => _especialidades = e);
    }).catchError((_) {});
  }

  void _cargar() {
    _citas = CitasService.buscar(
      desde: _rango.start,
      hasta: _rango.end,
      especialidadId: _especialidadId,
      estado: _estado,
      limite: 1000,
    );
  }

  Future<void> _elegirRango() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      initialDateRange: _rango,
    );
    if (r == null) return;
    setState(() {
      _rango = r;
      _cargar();
    });
  }

  bool _coincide(Cita c) {
    if (_busqueda.isEmpty) return true;
    final q = _busqueda.toLowerCase();
    return c.pacienteNombre.toLowerCase().contains(q) ||
        (c.pacienteDni ?? '').contains(q) ||
        (c.pacienteCodigo ?? '').toLowerCase().contains(q) ||
        c.doctorNombre.toLowerCase().contains(q) ||
        c.codigo.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final mismoDia = _rango.start == _rango.end;
    return Scaffold(
      appBar: AppBar(title: const Text('Citas')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar paciente, DNI, código o profesional',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (v) => setState(() => _busqueda = v.trim()),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            ActionChip(
              avatar: const Icon(Icons.date_range_rounded, size: 18),
              label: Text(mismoDia ? Formatos.fechaCorta(_rango.start) : '${Formatos.fechaCorta(_rango.start)} - ${Formatos.fechaCorta(_rango.end)}'),
              onPressed: _elegirRango,
            ),
            const SizedBox(width: 8),
            PopupMenuButton<int?>(
              onSelected: (v) => setState(() {
                _especialidadId = v == -1 ? null : v;
                _cargar();
              }),
              itemBuilder: (_) => [
                const PopupMenuItem(value: -1, child: Text('Todas las áreas')),
                for (final e in _especialidades) PopupMenuItem(value: e.id, child: Text(e.nombre)),
              ],
              child: Chip(
                avatar: const Icon(Icons.local_hospital_rounded, size: 18),
                label: Text(_especialidades.where((e) => e.id == _especialidadId).firstOrNull?.nombre ?? 'Área'),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<int>(
              onSelected: (v) => setState(() {
                _estado = v < 0 ? null : EstadoCita.values[v];
                _cargar();
              }),
              itemBuilder: (_) => [
                const PopupMenuItem(value: -1, child: Text('Todos los estados')),
                for (final e in EstadoCita.values) PopupMenuItem(value: e.index, child: Text(e.etiqueta)),
              ],
              child: Chip(avatar: const Icon(Icons.filter_list_rounded, size: 18), label: Text(_estado?.etiqueta ?? 'Estado')),
            ),
          ]),
        ),
        Expanded(
          child: FutureBuilder(
            future: _citas,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const Cargando();
              if (snap.hasError) return ErrorView(mensaje: Formatos.error(snap.error!), onReintentar: () => setState(_cargar));
              final citas = snap.data!.where(_coincide).toList()..sort((a, b) => a.inicio.compareTo(b.inicio));
              return RefreshIndicator(
                onRefresh: () async {
                  setState(_cargar);
                  await _citas;
                },
                child: citas.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 380, child: VacioView(icono: Icons.search_off_rounded, titulo: 'Sin resultados', mensaje: 'Prueba con otras fechas o filtros.')),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: citas.length + 1,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          if (i == 0) {
                            return Text('${citas.length} cita(s)', style: TextStyle(color: Theme.of(context).hintColor, fontWeight: FontWeight.w600));
                          }
                          final c = citas[i - 1];
                          return CitaCard(
                            cita: c,
                            vista: VistaCita.admin,
                            onTap: () async {
                              final cambio = await Navigator.push<bool>(
                                  context, MaterialPageRoute(builder: (_) => GestionarCitaScreen(citaId: c.id)));
                              if (cambio == true) setState(_cargar);
                            },
                          );
                        },
                      ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
