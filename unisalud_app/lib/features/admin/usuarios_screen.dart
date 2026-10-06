import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatos.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/especialidad.dart';
import '../../data/models/perfil.dart';
import '../../data/services/catalogo_service.dart';
import '../../data/services/sesion.dart';
import '../../data/services/usuarios_service.dart';
import '../doctor/horarios_screen.dart';

/// Administración de cuentas: asignar rol de profesional/admin, área y consultorio.
class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  RolUsuario? _rol;
  String _busqueda = '';
  Timer? _debounce;
  late Future<List<Perfil>> _usuarios;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _cargar() => _usuarios = UsuariosService.listar(busqueda: _busqueda, rol: _rol);

  void _buscar(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _busqueda = v;
        _cargar();
      });
    });
  }

  Color _colorRol(RolUsuario r) => switch (r) {
        RolUsuario.admin => AppColors.accent,
        RolUsuario.doctor => AppColors.info,
        RolUsuario.paciente => AppColors.primary,
      };

  Future<void> _editar(Perfil p) async {
    final especialidades = await CatalogoService.especialidades();
    if (!mounted) return;
    final guardado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EditarUsuario(perfil: p, especialidades: especialidades),
    );
    if (guardado == true) setState(_cargar);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Usuarios')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            decoration: const InputDecoration(hintText: 'Buscar por nombre, DNI, código o correo', prefixIcon: Icon(Icons.search_rounded)),
            onChanged: _buscar,
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            for (final (r, t) in [(null, 'Todos'), (RolUsuario.paciente, 'Pacientes'), (RolUsuario.doctor, 'Profesionales'), (RolUsuario.admin, 'Admins')])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(t),
                  selected: _rol == r,
                  onSelected: (_) => setState(() {
                    _rol = r;
                    _cargar();
                  }),
                ),
              ),
          ]),
        ),
        Expanded(
          child: FutureBuilder(
            future: _usuarios,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const Cargando();
              if (snap.hasError) return ErrorView(mensaje: Formatos.error(snap.error!), onReintentar: () => setState(_cargar));
              final us = snap.data!;
              if (us.isEmpty) return const VacioView(icono: Icons.person_search_rounded, titulo: 'Sin resultados');
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: us.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final p = us[i];
                  return Card(
                    child: ListTile(
                      onTap: () => _editar(p),
                      leading: AvatarIniciales(p.iniciales, color: _colorRol(p.rol)),
                      title: Text(p.nombreCompleto, style: TextStyle(fontWeight: FontWeight.w700, decoration: p.activo ? null : TextDecoration.lineThrough)),
                      subtitle: Text([
                        p.rol == RolUsuario.doctor ? (p.especialidad?.nombre ?? 'Sin área') : p.tipoUsuarioEtiqueta,
                        if (p.dni != null) 'DNI ${p.dni}',
                      ].join(' · ')),
                      trailing: Etiqueta(p.rol == RolUsuario.doctor ? 'Profesional' : p.rol.etiqueta, color: _colorRol(p.rol)),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _EditarUsuario extends StatefulWidget {
  const _EditarUsuario({required this.perfil, required this.especialidades});
  final Perfil perfil;
  final List<Especialidad> especialidades;

  @override
  State<_EditarUsuario> createState() => _EditarUsuarioState();
}

class _EditarUsuarioState extends State<_EditarUsuario> {
  late RolUsuario _rol = widget.perfil.rol;
  late int? _especialidadId = widget.perfil.especialidadId;
  late bool _activo = widget.perfil.activo;
  late final _consultorio = TextEditingController(text: widget.perfil.consultorio);
  bool _guardando = false;

  bool get _esYo => widget.perfil.id == Sesion.instancia.perfil?.id;

  @override
  void dispose() {
    _consultorio.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_rol == RolUsuario.doctor && _especialidadId == null) {
      mostrarMensaje(context, 'Elige el área del profesional', error: true);
      return;
    }
    setState(() => _guardando = true);
    try {
      await UsuariosService.actualizar(
        widget.perfil.id,
        rol: _rol,
        especialidadId: _especialidadId,
        consultorio: _consultorio.text.trim().isEmpty ? null : _consultorio.text.trim(),
        activo: _activo,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) mostrarMensaje(context, Formatos.error(e), error: true);
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.perfil;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(p.nombreCompleto, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          Text([p.email, p.dni != null ? 'DNI ${p.dni}' : null, p.telefono].whereType<String>().join(' · '),
              style: TextStyle(color: Theme.of(context).hintColor)),
          const SizedBox(height: 20),
          const Text('Rol', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SegmentedButton<RolUsuario>(
            segments: const [
              ButtonSegment(value: RolUsuario.paciente, label: Text('Paciente')),
              ButtonSegment(value: RolUsuario.doctor, label: Text('Profesional')),
              ButtonSegment(value: RolUsuario.admin, label: Text('Admin')),
            ],
            selected: {_rol},
            onSelectionChanged: _esYo ? null : (s) => setState(() => _rol = s.first),
            showSelectedIcon: false,
          ),
          if (_esYo)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('No puedes cambiar tu propio rol.', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
            ),
          if (_rol == RolUsuario.doctor) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              initialValue: _especialidadId,
              decoration: const InputDecoration(labelText: 'Área de atención'),
              items: [for (final e in widget.especialidades) DropdownMenuItem(value: e.id, child: Text(e.nombre))],
              onChanged: (v) => setState(() => _especialidadId = v),
            ),
            const SizedBox(height: 12),
            TextField(controller: _consultorio, decoration: const InputDecoration(labelText: 'Consultorio / lugar', hintText: 'Ej.: Tópico 2 - Pabellón B')),
            if (p.rol == RolUsuario.doctor) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => HorariosScreen(doctorId: p.id, titulo: 'Horarios de ${p.primerNombre}')),
                ),
                icon: const Icon(Icons.schedule_rounded),
                label: const Text('Gestionar sus horarios'),
              ),
            ],
          ],
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _activo,
            onChanged: _esYo ? null : (v) => setState(() => _activo = v),
            title: const Text('Cuenta activa', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Si la desactivas, la persona no podrá usar la app'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _guardando ? null : _guardar,
            child: _guardando
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : const Text('Guardar cambios'),
          ),
        ]),
      ),
    );
  }
}
