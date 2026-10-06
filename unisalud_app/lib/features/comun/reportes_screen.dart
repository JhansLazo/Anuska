import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatos.dart';
import '../../core/widgets/cita_card.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/cita.dart';
import '../../data/models/especialidad.dart';
import '../../data/models/perfil.dart';
import '../../data/services/catalogo_service.dart';
import '../../data/services/citas_service.dart';
import '../../data/services/sesion.dart';
import '../doctor/gestionar_cita_screen.dart';
import 'exportar_reporte.dart';
import 'resumen_reporte.dart';

enum _Rango { hoy, semana, mes, personalizado }

/// Reportes con filtros, indicadores y exportación.
/// El administrador ve toda la universidad; el profesional, solo sus citas (RLS).
class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  _Rango _rango = _Rango.mes;
  late DateTime _desde;
  late DateTime _hasta;
  int? _especialidadId;
  String? _turno;
  List<Especialidad> _especialidades = [];
  Future<List<Cita>>? _datos;
  bool _exportando = false;

  bool get _esAdmin => Sesion.instancia.perfil?.rol == RolUsuario.admin;

  @override
  void initState() {
    super.initState();
    _aplicarRango(_Rango.mes);
    CatalogoService.especialidades().then((e) {
      if (mounted) setState(() => _especialidades = e);
    }).catchError((_) {});
  }

  void _aplicarRango(_Rango r) {
    final hoy = Formatos.soloFecha(DateTime.now());
    switch (r) {
      case _Rango.hoy:
        _desde = hoy;
        _hasta = hoy;
      case _Rango.semana:
        _desde = hoy.subtract(Duration(days: hoy.weekday - 1));
        _hasta = _desde.add(const Duration(days: 6));
      case _Rango.mes:
        _desde = DateTime(hoy.year, hoy.month, 1);
        _hasta = DateTime(hoy.year, hoy.month + 1, 0);
      case _Rango.personalizado:
        break;
    }
    _rango = r;
    _cargar();
  }

  void _cargar() {
    setState(() {
      _datos = CitasService.buscar(
        desde: _desde,
        hasta: _hasta,
        especialidadId: _especialidadId,
        turno: _turno,
        doctorId: _esAdmin ? null : Sesion.instancia.perfil!.id,
      );
    });
  }

  Future<void> _elegirRango() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      initialDateRange: DateTimeRange(start: _desde, end: _hasta),
      helpText: 'Periodo del reporte',
    );
    if (r == null) return;
    _desde = r.start;
    _hasta = r.end;
    _aplicarRango(_Rango.personalizado);
  }

  Future<void> _exportar(List<Cita> citas, bool pdf) async {
    if (citas.isEmpty) {
      mostrarMensaje(context, 'No hay datos para exportar en este periodo', error: true);
      return;
    }
    setState(() => _exportando = true);
    try {
      if (pdf) {
        await ExportarReporte.pdf(citas, _desde, _hasta, generadoPor: Sesion.instancia.perfil!.nombreCompleto);
      } else {
        await ExportarReporte.csv(citas, _desde, _hasta);
      }
    } catch (e) {
      if (mounted) mostrarMensaje(context, 'No se pudo exportar: ${Formatos.error(e)}', error: true);
    }
    if (mounted) setState(() => _exportando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_esAdmin ? 'Reportes' : 'Mis reportes')),
      body: FutureBuilder(
        future: _datos,
        builder: (context, snap) {
          final citas = snap.data ?? const <Cita>[];
          return RefreshIndicator(
            onRefresh: () async {
              _cargar();
              await _datos;
            },
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
              _filtros(),
              const SizedBox(height: 16),
              if (snap.connectionState != ConnectionState.done)
                const SizedBox(height: 300, child: Cargando(texto: 'Calculando indicadores...'))
              else if (snap.hasError)
                SizedBox(height: 360, child: ErrorView(mensaje: Formatos.error(snap.error!), onReintentar: _cargar))
              else
                ..._contenido(citas),
            ]),
          );
        },
      ),
    );
  }

  Widget _filtros() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (r, t) in [(_Rango.hoy, 'Hoy'), (_Rango.semana, 'Esta semana'), (_Rango.mes, 'Este mes')])
            ChoiceChip(label: Text(t), selected: _rango == r, onSelected: (_) => _aplicarRango(r)),
          ChoiceChip(
            avatar: const Icon(Icons.date_range_rounded, size: 18),
            label: const Text('Elegir fechas'),
            selected: _rango == _Rango.personalizado,
            onSelected: (_) => _elegirRango(),
          ),
        ]),
        const SizedBox(height: 8),
        Text('Del ${Formatos.fecha(_desde)} al ${Formatos.fecha(_hasta)}',
            style: TextStyle(color: Theme.of(context).hintColor, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(children: [
          if (_esAdmin) ...[
            Expanded(
              child: DropdownButtonFormField<int?>(
                initialValue: _especialidadId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Área', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todas')),
                  for (final e in _especialidades) DropdownMenuItem(value: e.id, child: Text(e.nombre, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) {
                  _especialidadId = v;
                  _cargar();
                },
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: DropdownButtonFormField<String?>(
              initialValue: _turno,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Turno', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
              items: const [
                DropdownMenuItem(value: null, child: Text('Mañana y tarde')),
                DropdownMenuItem(value: 'mañana', child: Text('Mañana')),
                DropdownMenuItem(value: 'tarde', child: Text('Tarde')),
              ],
              onChanged: (v) {
                _turno = v;
                _cargar();
              },
            ),
          ),
        ]),
      ]);

  List<Widget> _contenido(List<Cita> citas) {
    final r = ResumenReporte(citas);
    if (citas.isEmpty) {
      return const [
        SizedBox(
          height: 320,
          child: VacioView(icono: Icons.insert_chart_outlined_rounded, titulo: 'Sin citas en este periodo', mensaje: 'Cambia el rango de fechas o los filtros.'),
        ),
      ];
    }
    final maxArea = r.porArea.values.fold(0, (a, b) => a > b ? a : b);
    final maxDeriv = r.derivaciones.values.fold(0, (a, b) => a > b ? a : b);
    final colorArea = {for (final c in citas) c.especialidadNombre: c.especialidadColor};
    final atendidas = citas.where((c) => c.estado == EstadoCita.atendida).toList()
      ..sort((a, b) => (b.atendidaEn ?? b.inicio).compareTo(a.atendidaEn ?? a.inicio));

    return [
      Row(children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _exportando ? null : () => _exportar(citas, true),
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: const Text('PDF'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _exportando ? null : () => _exportar(citas, false),
            icon: const Icon(Icons.table_view_rounded),
            label: const Text('Excel (CSV)'),
          ),
        ),
      ]),
      const SizedBox(height: 16),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.55,
        children: [
          KpiTile(titulo: 'Citas totales', valor: '${r.total}', icono: Icons.event_note_rounded, color: AppColors.primary),
          KpiTile(
            titulo: 'Atendidas',
            valor: '${r.cuenta(EstadoCita.atendida)}',
            icono: Icons.check_circle_rounded,
            color: AppColors.success,
            detalle: '${r.tasaAsistencia.toStringAsFixed(0)}% asist.',
          ),
          KpiTile(titulo: 'No asistieron', valor: '${r.cuenta(EstadoCita.noAsistio)}', icono: Icons.person_off_rounded, color: AppColors.danger),
          KpiTile(titulo: 'Canceladas', valor: '${r.cuenta(EstadoCita.cancelada)}', icono: Icons.cancel_rounded, color: AppColors.neutral),
          KpiTile(
            titulo: 'Por atender',
            valor: '${r.cuenta(EstadoCita.pendiente) + r.cuenta(EstadoCita.confirmada)}',
            icono: Icons.schedule_rounded,
            color: AppColors.warning,
          ),
          KpiTile(titulo: 'Derivaciones', valor: '${r.totalDerivaciones}', icono: Icons.alt_route_rounded, color: AppColors.accent),
        ],
      ),
      const SizedBox(height: 16),
      Bloque(
        titulo: 'Citas por área',
        child: Column(children: [
          for (final e in ResumenReporte.ordenar(r.porArea))
            BarraDato(etiqueta: e.key, valor: e.value, maximo: maxArea, color: colorArea[e.key] ?? AppColors.primary),
        ]),
      ),
      const SizedBox(height: 12),
      Bloque(
        titulo: 'Turno de atención',
        child: _BarraTurnos(manana: r.porTurno['Mañana'] ?? 0, tarde: r.porTurno['Tarde'] ?? 0),
      ),
      const SizedBox(height: 12),
      Bloque(
        titulo: 'Asistencia',
        child: Column(children: [
          for (final e in [EstadoCita.atendida, EstadoCita.noAsistio, EstadoCita.cancelada, EstadoCita.confirmada, EstadoCita.pendiente])
            BarraDato(etiqueta: e.etiqueta, valor: r.cuenta(e), maximo: r.total, color: e.color),
        ]),
      ),
      const SizedBox(height: 12),
      Bloque(
        titulo: 'A dónde se derivó a los pacientes',
        child: r.derivaciones.isEmpty
            ? Text('Sin derivaciones en este periodo', style: TextStyle(color: Theme.of(context).hintColor))
            : Column(children: [
                for (final e in ResumenReporte.ordenar(r.derivaciones))
                  BarraDato(etiqueta: e.key, valor: e.value, maximo: maxDeriv, color: AppColors.accent),
              ]),
      ),
      if (_esAdmin) ...[
        const SizedBox(height: 12),
        Bloque(
          titulo: 'Por profesional',
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(children: [
            for (final p in r.porProfesional.values.toList()..sort((a, b) => b.total.compareTo(a.total)))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(p.area),
                trailing: Wrap(spacing: 6, children: [
                  Etiqueta('${p.atendidas}', color: AppColors.success, icono: Icons.check_rounded),
                  Etiqueta('${p.inasistencias}', color: AppColors.danger, icono: Icons.person_off_rounded),
                  Etiqueta('${p.total}', color: AppColors.primary, icono: Icons.event_note_rounded),
                ]),
              ),
          ]),
        ),
      ],
      const SizedBox(height: 20),
      SeccionTitulo('Últimas atenciones (${atendidas.length})'),
      if (atendidas.isEmpty)
        Text('Aún no hay atenciones registradas en este periodo.', style: TextStyle(color: Theme.of(context).hintColor))
      else
        for (final c in atendidas.take(30)) ...[
          _FilaAtencion(cita: c),
          const SizedBox(height: 10),
        ],
      if (atendidas.length > 30)
        Text('Exporta el PDF o CSV para ver las ${atendidas.length} atenciones.',
            textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).hintColor)),
    ];
  }
}

class _BarraTurnos extends StatelessWidget {
  const _BarraTurnos({required this.manana, required this.tarde});
  final int manana;
  final int tarde;

  @override
  Widget build(BuildContext context) {
    final total = manana + tarde;
    const cM = Color(0xFFF59E0B);
    const cT = Color(0xFF6366F1);
    Widget leyenda(Color c, IconData i, String t, int v) => Row(children: [
          Icon(i, color: c, size: 20),
          const SizedBox(width: 6),
          Text('$t: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Text('$v (${total == 0 ? 0 : (v * 100 / total).round()}%)', style: TextStyle(color: c, fontWeight: FontWeight.w800)),
        ]);
    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: SizedBox(
          height: 16,
          child: Row(children: [
            if (manana > 0) Expanded(flex: manana, child: Container(color: cM)),
            if (tarde > 0) Expanded(flex: tarde, child: Container(color: cT)),
            if (total == 0) Expanded(child: Container(color: Theme.of(context).dividerColor)),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        leyenda(cM, Icons.wb_sunny_rounded, 'Mañana', manana),
        leyenda(cT, Icons.wb_twilight_rounded, 'Tarde', tarde),
      ]),
    ]);
  }
}

class _FilaAtencion extends StatelessWidget {
  const _FilaAtencion({required this.cita});
  final Cita cita;

  @override
  Widget build(BuildContext context) => CitaCard(
        cita: cita,
        vista: VistaCita.admin,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GestionarCitaScreen(citaId: cita.id))),
      );
}
