import 'package:flutter/material.dart';

import '../../data/services/sesion.dart';
import '../comun/perfil_screen.dart';
import '../comun/reportes_screen.dart';
import 'agenda_screen.dart';
import 'horarios_screen.dart';

class DoctorShell extends StatefulWidget {
  const DoctorShell({super.key});

  @override
  State<DoctorShell> createState() => _DoctorShellState();
}

class _DoctorShellState extends State<DoctorShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final perfil = Sesion.instancia.perfil!;
    final paginas = [
      const AgendaScreen(),
      HorariosScreen(doctorId: perfil.id, titulo: 'Mis horarios'),
      const ReportesScreen(),
      const PerfilScreen(),
    ];
    return Scaffold(
      body: paginas[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today_rounded), label: 'Agenda'),
          NavigationDestination(icon: Icon(Icons.schedule_outlined), selectedIcon: Icon(Icons.schedule_rounded), label: 'Horarios'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights_rounded), label: 'Reportes'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Perfil'),
        ],
      ),
    );
  }
}
