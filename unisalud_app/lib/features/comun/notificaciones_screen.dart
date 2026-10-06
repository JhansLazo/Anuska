import 'package:flutter/material.dart';

import '../../core/utils/formatos.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/notificacion.dart';
import '../../data/services/notificaciones_service.dart';

class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key, this.onCambio});
  final VoidCallback? onCambio;

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  late Future<List<Notificacion>> _datos;

  @override
  void initState() {
    super.initState();
    _datos = NotificacionesService.listar();
  }

  Future<void> _refrescar() async {
    setState(() => _datos = NotificacionesService.listar());
    await _datos;
    widget.onCambio?.call();
  }

  Future<void> _marcar(Notificacion n) async {
    if (n.leida) return;
    try {
      await NotificacionesService.marcarLeida(n.id);
      _refrescar();
    } catch (_) {}
  }

  Future<void> _marcarTodas() async {
    try {
      await NotificacionesService.marcarTodas();
      _refrescar();
    } catch (e) {
      if (mounted) mostrarMensaje(context, Formatos.error(e), error: true);
    }
  }

  IconData _icono(String titulo) {
    final t = titulo.toLowerCase();
    if (t.contains('cancel')) return Icons.event_busy_rounded;
    if (t.contains('confirm')) return Icons.event_available_rounded;
    if (t.contains('atenci')) return Icons.check_circle_rounded;
    if (t.contains('inasist')) return Icons.person_off_rounded;
    return Icons.event_note_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avisos'),
        actions: [
          TextButton.icon(onPressed: _marcarTodas, icon: const Icon(Icons.done_all_rounded), label: const Text('Leer todo')),
        ],
      ),
      body: FutureBuilder(
        future: _datos,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Cargando();
          if (snap.hasError) return ErrorView(mensaje: Formatos.error(snap.error!), onReintentar: _refrescar);
          final items = snap.data!;
          return RefreshIndicator(
            onRefresh: _refrescar,
            child: items.isEmpty
                ? ListView(children: const [
                    SizedBox(
                      height: 460,
                      child: VacioView(
                        icono: Icons.notifications_none_rounded,
                        titulo: 'Todo al día',
                        mensaje: 'Aquí te avisaremos cuando reserves, se confirme o cambie una cita.',
                      ),
                    ),
                  ])
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final n = items[i];
                      return Card(
                        color: n.leida ? null : cs.primary.withValues(alpha: 0.06),
                        child: ListTile(
                          onTap: () => _marcar(n),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: CircleAvatar(
                            backgroundColor: cs.primary.withValues(alpha: 0.12),
                            child: Icon(_icono(n.titulo), color: cs.primary),
                          ),
                          title: Row(children: [
                            Expanded(child: Text(n.titulo, style: const TextStyle(fontWeight: FontWeight.w800))),
                            if (!n.leida)
                              Container(width: 9, height: 9, decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle)),
                          ]),
                          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const SizedBox(height: 4),
                            Text(n.mensaje),
                            const SizedBox(height: 6),
                            Text(Formatos.fechaHora(n.creadaEn), style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                          ]),
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}
