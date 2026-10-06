import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatos.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/perfil.dart';
import '../../data/services/sesion.dart';

class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  Future<void> _editar(BuildContext context, Perfil p) async {
    final telefono = TextEditingController(text: p.telefono);
    final escuela = TextEditingController(text: p.escuela);
    final consultorio = TextEditingController(text: p.consultorio);
    final guardado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(c).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Editar mis datos', style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextField(controller: telefono, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Celular')),
          const SizedBox(height: 12),
          TextField(controller: escuela, decoration: const InputDecoration(labelText: 'Facultad / Escuela / Área')),
          if (p.rol == RolUsuario.doctor) ...[
            const SizedBox(height: 12),
            TextField(controller: consultorio, decoration: const InputDecoration(labelText: 'Consultorio / lugar de atención')),
          ],
          const SizedBox(height: 20),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Guardar cambios')),
        ]),
      ),
    );
    if (guardado != true) return;
    try {
      await Sesion.instancia.actualizarPerfil({
        'telefono': telefono.text.trim(),
        'escuela': escuela.text.trim(),
        if (p.rol == RolUsuario.doctor) 'consultorio': consultorio.text.trim(),
      });
      if (context.mounted) mostrarMensaje(context, 'Datos actualizados');
    } catch (e) {
      if (context.mounted) mostrarMensaje(context, Formatos.error(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Sesion.instancia,
      builder: (context, _) {
        final p = Sesion.instancia.perfil;
        if (p == null) return const SizedBox.shrink();
        return Scaffold(
          body: ListView(padding: EdgeInsets.zero, children: [
            Container(
              decoration: const BoxDecoration(
                gradient: AppColors.headerGradient,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                  child: Column(children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: Text(p.iniciales,
                          style: const TextStyle(color: AppColors.primary, fontSize: 28, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(height: 12),
                    Text(p.nombreCompleto,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(p.email ?? '', style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(99)),
                      child: Text(
                        p.rol == RolUsuario.doctor && p.especialidad != null
                            ? '${p.rol.etiqueta} · ${p.especialidad!.nombre}'
                            : p.rol == RolUsuario.paciente
                                ? p.tipoUsuarioEtiqueta
                                : p.rol.etiqueta,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Bloque(
                  titulo: 'Mis datos',
                  child: Column(children: [
                    if (p.dni != null) InfoFila(icono: Icons.badge_rounded, etiqueta: 'DNI', valor: p.dni!),
                    if (p.codigoUniversitario != null)
                      InfoFila(icono: Icons.credit_card_rounded, etiqueta: 'Código', valor: p.codigoUniversitario!),
                    InfoFila(icono: Icons.phone_rounded, etiqueta: 'Celular', valor: p.telefono ?? '—'),
                    InfoFila(icono: Icons.apartment_rounded, etiqueta: 'Facultad / Escuela / Área', valor: p.escuela ?? '—'),
                    if (p.rol == RolUsuario.doctor)
                      InfoFila(icono: Icons.location_on_rounded, etiqueta: 'Consultorio', valor: p.consultorio ?? '—'),
                  ]),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _editar(context, p),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Editar mis datos'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                  onPressed: () async {
                    if (await confirmar(context, titulo: 'Cerrar sesión', mensaje: '¿Seguro que quieres salir?', aceptar: 'Salir')) {
                      await Sesion.instancia.cerrarSesion();
                    }
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Cerrar sesión'),
                ),
                const SizedBox(height: 24),
                Text('UniSalud · Bienestar Universitario',
                    textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
              ]),
            ),
          ]),
        );
      },
    );
  }
}
