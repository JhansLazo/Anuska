import 'package:flutter/material.dart';

import '../../data/models/cita.dart';
import '../theme/app_colors.dart';

void mostrarMensaje(BuildContext context, String texto, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(child: Text(texto)),
      ]),
      backgroundColor: error ? AppColors.danger : AppColors.primaryDark,
    ));
}

Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String aceptar = 'Aceptar',
  bool peligro = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Volver')),
        FilledButton(
          style: peligro ? FilledButton.styleFrom(backgroundColor: AppColors.danger, minimumSize: const Size(0, 44)) : FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () => Navigator.pop(c, true),
          child: Text(aceptar),
        ),
      ],
    ),
  );
  return r ?? false;
}

class Cargando extends StatelessWidget {
  const Cargando({super.key, this.texto});
  final String? texto;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(),
          if (texto != null) ...[
            const SizedBox(height: 16),
            Text(texto!, style: TextStyle(color: Theme.of(context).hintColor)),
          ],
        ]),
      );
}

class VacioView extends StatelessWidget {
  const VacioView({super.key, required this.icono, required this.titulo, this.mensaje, this.accion});
  final IconData icono;
  final String titulo;
  final String? mensaje;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.10), shape: BoxShape.circle),
            child: Icon(icono, size: 44, color: cs.primary),
          ),
          const SizedBox(height: 20),
          Text(titulo, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          if (mensaje != null) ...[
            const SizedBox(height: 8),
            Text(mensaje!, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).hintColor)),
          ],
          if (accion != null) ...[const SizedBox(height: 20), accion!],
        ]),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.mensaje, required this.onReintentar});
  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) => VacioView(
        icono: Icons.wifi_off_rounded,
        titulo: 'Algo salió mal',
        mensaje: mensaje,
        accion: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size(160, 48)),
          onPressed: onReintentar,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Reintentar'),
        ),
      );
}

class EstadoChip extends StatelessWidget {
  const EstadoChip(this.estado, {super.key, this.compacto = false});
  final EstadoCita estado;
  final bool compacto;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: compacto ? 8 : 10, vertical: compacto ? 4 : 6),
        decoration: BoxDecoration(
          color: estado.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(estado.icono, size: compacto ? 13 : 15, color: estado.color),
          const SizedBox(width: 4),
          Text(estado.etiqueta,
              style: TextStyle(color: estado.color, fontWeight: FontWeight.w700, fontSize: compacto ? 11 : 12)),
        ]),
      );
}

class Etiqueta extends StatelessWidget {
  const Etiqueta(this.texto, {super.key, required this.color, this.icono});
  final String texto;
  final Color color;
  final IconData? icono;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icono != null) ...[Icon(icono, size: 14, color: color), const SizedBox(width: 4)],
          Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
        ]),
      );
}

class AvatarIniciales extends StatelessWidget {
  const AvatarIniciales(this.iniciales, {super.key, this.color, this.radio = 22});
  final String iniciales;
  final Color? color;
  final double radio;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return CircleAvatar(
      radius: radio,
      backgroundColor: c.withValues(alpha: 0.14),
      child: Text(iniciales, style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: radio * 0.75)),
    );
  }
}

class SeccionTitulo extends StatelessWidget {
  const SeccionTitulo(this.titulo, {super.key, this.accion});
  final String titulo;
  final Widget? accion;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: Row(children: [
          Expanded(
            child: Text(titulo, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          ),
          ?accion,
        ]),
      );
}

/// Fila "icono · etiqueta · valor" para fichas de detalle.
class InfoFila extends StatelessWidget {
  const InfoFila({super.key, required this.icono, required this.etiqueta, required this.valor, this.color});
  final IconData icono;
  final String etiqueta;
  final String valor;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: c.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
          child: Icon(icono, size: 18, color: c),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(etiqueta, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
            const SizedBox(height: 2),
            Text(valor, style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }
}

/// Tarjeta con título para agrupar contenido.
class Bloque extends StatelessWidget {
  const Bloque({super.key, this.titulo, required this.child, this.padding = const EdgeInsets.all(16)});
  final String? titulo;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: padding,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (titulo != null) ...[
              Text(titulo!, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
            ],
            child,
          ]),
        ),
      );
}

/// Indicador numérico (KPI) para paneles y reportes.
class KpiTile extends StatelessWidget {
  const KpiTile({super.key, required this.titulo, required this.valor, required this.icono, required this.color, this.detalle});
  final String titulo;
  final String valor;
  final IconData icono;
  final Color color;
  final String? detalle;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icono, color: color, size: 18),
              ),
              const Spacer(),
              if (detalle != null)
                Text(detalle!, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
            ]),
            const SizedBox(height: 10),
            Text(valor, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            Text(titulo, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12.5)),
          ]),
        ),
      );
}

/// Barra horizontal etiquetada para gráficos simples.
class BarraDato extends StatelessWidget {
  const BarraDato({super.key, required this.etiqueta, required this.valor, required this.maximo, required this.color, this.sufijo});
  final String etiqueta;
  final int valor;
  final int maximo;
  final Color color;
  final String? sufijo;

  @override
  Widget build(BuildContext context) {
    final f = maximo == 0 ? 0.0 : valor / maximo;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(etiqueta, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
          Text('$valor${sufijo ?? ''}', style: TextStyle(fontWeight: FontWeight.w800, color: color)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: f,
            minHeight: 10,
            color: color,
            backgroundColor: color.withValues(alpha: 0.12),
          ),
        ),
      ]),
    );
  }
}
