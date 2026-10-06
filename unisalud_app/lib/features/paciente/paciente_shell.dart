import 'package:flutter/material.dart';

import '../../data/services/notificaciones_service.dart';
import '../comun/notificaciones_screen.dart';
import '../comun/perfil_screen.dart';
import 'inicio_paciente.dart';
import 'mis_citas_screen.dart';

class PacienteShell extends StatefulWidget {
  const PacienteShell({super.key});

  @override
  State<PacienteShell> createState() => _PacienteShellState();
}

class _PacienteShellState extends State<PacienteShell> {
  int _tab = 0;
  int _noLeidas = 0;

  @override
  void initState() {
    super.initState();
    _contarAvisos();
  }

  Future<void> _contarAvisos() async {
    try {
      final n = await NotificacionesService.noLeidas();
      if (mounted) setState(() => _noLeidas = n);
    } catch (_) {}
  }

  void _irA(int i) {
    setState(() => _tab = i);
    _contarAvisos();
  }

  @override
  Widget build(BuildContext context) {
    final paginas = [
      InicioPaciente(onVerCitas: () => _irA(1), onVerAvisos: () => _irA(2), noLeidas: _noLeidas),
      const MisCitasScreen(),
      NotificacionesScreen(onCambio: _contarAvisos),
      const PerfilScreen(),
    ];
    return Scaffold(
      body: paginas[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _irA,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Inicio'),
          const NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month_rounded), label: 'Mis citas'),
          NavigationDestination(
            icon: Badge(isLabelVisible: _noLeidas > 0, label: Text('$_noLeidas'), child: const Icon(Icons.notifications_outlined)),
            selectedIcon: const Icon(Icons.notifications_rounded),
            label: 'Avisos',
          ),
          const NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Perfil'),
        ],
      ),
    );
  }
}
