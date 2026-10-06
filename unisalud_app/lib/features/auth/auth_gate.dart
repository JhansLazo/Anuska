import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/utils/formatos.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/perfil.dart';
import '../../data/services/sesion.dart';
import '../admin/admin_shell.dart';
import '../doctor/doctor_shell.dart';
import '../paciente/paciente_shell.dart';
import 'login_screen.dart';

/// Decide qué mostrar: login, o la app según el rol del usuario.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _sub;
  bool _cargando = true;
  String? _error;

  Sesion get _sesion => Sesion.instancia;

  @override
  void initState() {
    super.initState();
    if (!SupabaseConfig.configurado) return;
    _sub = _sesion.cambios.listen((estado) {
      if (estado.event == AuthChangeEvent.tokenRefreshed) return;
      _cargar();
    });
    _cargar();
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await _sesion.cargarPerfil();
    } catch (e) {
      _error = Formatos.error(e);
    }
    if (mounted) setState(() => _cargando = false);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!SupabaseConfig.configurado) return const _FaltaConfiguracion();
    if (_cargando) return const Scaffold(body: Cargando(texto: 'Preparando tu espacio...'));
    if (_sesion.usuario == null) return const LoginScreen();
    if (_error != null) {
      return Scaffold(body: ErrorView(mensaje: _error!, onReintentar: _cargar));
    }

    return ListenableBuilder(
      listenable: _sesion,
      builder: (context, _) {
        final perfil = _sesion.perfil;
        if (perfil == null) {
          return Scaffold(
            body: VacioView(
              icono: Icons.person_search_rounded,
              titulo: 'No encontramos tu perfil',
              mensaje: '¿Ejecutaste el script 01_esquema.sql en Supabase antes de registrarte?',
              accion: OutlinedButton(onPressed: _sesion.cerrarSesion, child: const Text('Cerrar sesión')),
            ),
          );
        }
        if (!perfil.activo) {
          return Scaffold(
            body: VacioView(
              icono: Icons.block_rounded,
              titulo: 'Cuenta desactivada',
              mensaje: 'Comunícate con Bienestar Universitario para reactivarla.',
              accion: OutlinedButton(onPressed: _sesion.cerrarSesion, child: const Text('Cerrar sesión')),
            ),
          );
        }
        return switch (perfil.rol) {
          RolUsuario.paciente => const PacienteShell(),
          RolUsuario.doctor => const DoctorShell(),
          RolUsuario.admin => const AdminShell(),
        };
      },
    );
  }
}

class _FaltaConfiguracion extends StatelessWidget {
  const _FaltaConfiguracion();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: VacioView(
          icono: Icons.settings_suggest_rounded,
          titulo: 'Falta conectar Supabase',
          mensaje: 'Abre lib/core/config/supabase_config.dart y pega la URL y la Publishable key de tu proyecto '
              '(paso 4 de la guía).',
        ),
      );
}
