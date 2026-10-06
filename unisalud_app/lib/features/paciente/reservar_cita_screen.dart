import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatos.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/especialidad.dart';
import '../../data/models/horario.dart';
import '../../data/models/perfil.dart';
import '../../data/services/catalogo_service.dart';
import '../../data/services/citas_service.dart';

/// Reserva en 4 pasos: área → profesional → fecha y hora → confirmar.
class ReservarCitaScreen extends StatefulWidget {
  const ReservarCitaScreen({super.key, this.especialidadInicial, this.citaOrigenId});
  final Especialidad? especialidadInicial;
  final int? citaOrigenId;

  @override
  State<ReservarCitaScreen> createState() => _ReservarCitaScreenState();
}

class _ReservarCitaScreenState extends State<ReservarCitaScreen> {
  static const _diasVisibles = 21;
  static const _titulos = ['Elige el área', 'Elige al profesional', 'Elige fecha y hora', 'Confirma tu cita'];

  int _paso = 0;
  Especialidad? _esp;
  Perfil? _doctor;
  DateTime? _fecha;
  BloqueHorario? _bloque;
  final _motivo = TextEditingController();

  List<Especialidad>? _especialidades;
  List<Perfil>? _doctores;
  Map<String, List<Horario>> _horarios = {};
  List<BloqueHorario>? _bloques;
  String? _error;
  bool _cargando = false;
  bool _reservando = false;

  @override
  void initState() {
    super.initState();
    _esp = widget.especialidadInicial;
    if (_esp != null) {
      _paso = 1;
      _cargarDoctores();
    } else {
      _cargarEspecialidades();
    }
  }

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _ejecutar(Future<void> Function() tarea) async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await tarea();
    } catch (e) {
      _error = Formatos.error(e);
    }
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _cargarEspecialidades() => _ejecutar(() async {
        _especialidades = await CatalogoService.especialidades();
      });

  Future<void> _cargarDoctores() => _ejecutar(() async {
        _doctores = await CatalogoService.profesionales(especialidadId: _esp!.id);
        _horarios = await CatalogoService.horariosDe(_doctores!.map((d) => d.id).toList());
      });

  Future<void> _cargarBloques() => _ejecutar(() async {
        _bloques = await CitasService.bloquesDisponibles(_doctor!.id, _fecha!);
      });

  Set<int> get _diasDoctor => (_horarios[_doctor?.id] ?? []).map((h) => h.diaSemana).toSet();

  void _elegirEspecialidad(Especialidad e) {
    setState(() {
      _esp = e;
      _doctor = null;
      _paso = 1;
    });
    _cargarDoctores();
  }

  void _elegirDoctor(Perfil d) {
    setState(() {
      _doctor = d;
      _fecha = null;
      _bloque = null;
      _bloques = null;
      _paso = 2;
    });
    final hoy = Formatos.soloFecha(DateTime.now());
    final primerDia = List.generate(_diasVisibles, (i) => hoy.add(Duration(days: i)))
        .where((f) => _diasDoctor.contains(f.weekday))
        .firstOrNull;
    if (primerDia != null) _elegirFecha(primerDia);
  }

  void _elegirFecha(DateTime f) {
    setState(() {
      _fecha = f;
      _bloque = null;
    });
    _cargarBloques();
  }

  void _atras() {
    if (_paso == 0 || (_paso == 1 && widget.especialidadInicial != null)) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _paso--;
      _error = null;
    });
    if (_paso == 0 && _especialidades == null) _cargarEspecialidades();
  }

  Future<void> _reservar() async {
    setState(() => _reservando = true);
    try {
      await CitasService.reservar(
        doctorId: _doctor!.id,
        fecha: _fecha!,
        hora: _bloque!.inicio,
        motivo: _motivo.text,
        citaOrigenId: widget.citaOrigenId,
      );
      if (!mounted) return;
      await _mostrarExito();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      mostrarMensaje(context, Formatos.error(e), error: true);
      // El horario pudo haberse ocupado: refrescamos los bloques.
      setState(() {
        _paso = 2;
        _bloque = null;
      });
      _cargarBloques();
    } finally {
      if (mounted) setState(() => _reservando = false);
    }
  }

  Future<void> _mostrarExito() => showModalBottomSheet<void>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        builder: (c) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.4, end: 1),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (_, v, child) => Transform.scale(scale: v, child: child),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, color: AppColors.success, size: 48),
                ),
              ),
              const SizedBox(height: 16),
              Text('¡Cita reservada!', style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                '${_esp!.nombre} con ${_doctor!.nombreCompleto}\n'
                '${Formatos.diaLargo(_fecha!)} a las ${Formatos.horaSql(_bloque!.inicio)}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text('Llega 10 minutos antes con tu DNI o carné universitario.',
                  textAlign: TextAlign.center, style: TextStyle(color: Theme.of(c).hintColor)),
              const SizedBox(height: 24),
              FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Listo')),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _paso == 0 || (_paso == 1 && widget.especialidadInicial != null),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _atras();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: _atras, tooltip: 'Atrás'),
          title: Text(_titulos[_paso]),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(children: [
                for (var i = 0; i < 4; i++)
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 5,
                      decoration: BoxDecoration(
                        color: i <= _paso
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: KeyedSubtree(key: ValueKey(_paso), child: _cuerpo()),
        ),
      ),
    );
  }

  Widget _cuerpo() {
    if (_paso != 2 && _cargando) return const Cargando();
    if (_paso != 2 && _error != null) {
      return ErrorView(mensaje: _error!, onReintentar: _paso == 0 ? _cargarEspecialidades : _cargarDoctores);
    }
    return switch (_paso) {
      0 => _pasoEspecialidad(),
      1 => _pasoDoctor(),
      2 => _pasoFecha(),
      _ => _pasoConfirmar(),
    };
  }

  // ---------------- Paso 1 ----------------
  Widget _pasoEspecialidad() => ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _especialidades?.length ?? 0,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final e = _especialidades![i];
          return Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _elegirEspecialidad(e),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: e.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
                    child: Icon(e.icono, color: e.color, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.nombre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      if (e.descripcion != null) ...[
                        const SizedBox(height: 4),
                        Text(e.descripcion!, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
                      ],
                    ]),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ]),
              ),
            ),
          );
        },
      );

  // ---------------- Paso 2 ----------------
  Widget _pasoDoctor() {
    final docs = _doctores ?? [];
    if (docs.isEmpty) {
      return const VacioView(
        icono: Icons.person_search_rounded,
        titulo: 'Aún no hay profesionales',
        mensaje: 'Esta área todavía no tiene profesionales con agenda. Intenta más tarde.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: docs.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        if (i == 0) return _ResumenSeleccion(esp: _esp!);
        final d = docs[i - 1];
        final dias = (_horarios[d.id] ?? []).map((h) => h.diaSemana).toSet().toList()..sort();
        final sinAgenda = dias.isEmpty;
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: sinAgenda ? null : () => _elegirDoctor(d),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                AvatarIniciales(d.iniciales, color: _esp!.color, radio: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d.nombreCompleto, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                    if (d.consultorio != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(d.consultorio!, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
                      ),
                    const SizedBox(height: 8),
                    sinAgenda
                        ? const Etiqueta('Sin horarios publicados', color: AppColors.neutral)
                        : Wrap(spacing: 4, runSpacing: 4, children: [
                            for (final dia in dias)
                              Etiqueta(Formatos.diasSemana[dia - 1].substring(0, 3), color: _esp!.color),
                          ]),
                  ]),
                ),
                if (!sinAgenda) const Icon(Icons.chevron_right_rounded),
              ]),
            ),
          ),
        );
      },
    );
  }

  // ---------------- Paso 3 ----------------
  Widget _pasoFecha() {
    final hoy = Formatos.soloFecha(DateTime.now());
    final dias = List.generate(_diasVisibles, (i) => hoy.add(Duration(days: i)));
    final atiende = _diasDoctor;
    final cs = Theme.of(context).colorScheme;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
        child: _ResumenSeleccion(esp: _esp!, doctor: _doctor),
      ),
      SizedBox(
        height: 96,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          scrollDirection: Axis.horizontal,
          itemCount: dias.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final f = dias[i];
            final habil = atiende.contains(f.weekday);
            final sel = _fecha == f;
            return Semantics(
              button: true,
              selected: sel,
              label: Formatos.diaLargo(f),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: habil ? () => _elegirFecha(f) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 62,
                  decoration: BoxDecoration(
                    color: sel ? cs.primary : (habil ? cs.surface : cs.surface.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: sel ? cs.primary : Theme.of(context).dividerColor),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(i == 0 ? 'Hoy' : Formatos.diaSemanaCorto(f),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? Colors.white : (habil ? null : Theme.of(context).disabledColor))),
                    Text('${f.day}',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: sel ? Colors.white : (habil ? null : Theme.of(context).disabledColor))),
                    Text(Formatos.mesCorto(f),
                        style: TextStyle(fontSize: 11, color: sel ? Colors.white70 : Theme.of(context).hintColor)),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
      const Divider(),
      Expanded(child: _listaBloques()),
      _BarraInferior(
        texto: _bloque == null
            ? 'Selecciona un horario'
            : '${Formatos.diaLargo(_fecha!)} · ${Formatos.horaSql(_bloque!.inicio)}',
        boton: 'Continuar',
        onPressed: _bloque == null ? null : () => setState(() => _paso = 3),
      ),
    ]);
  }

  Widget _listaBloques() {
    if (_fecha == null) {
      return const VacioView(icono: Icons.calendar_today_rounded, titulo: 'Elige un día', mensaje: 'Los días resaltados son los que atiende el profesional.');
    }
    if (_cargando) return const Cargando();
    if (_error != null) return ErrorView(mensaje: _error!, onReintentar: _cargarBloques);
    final bloques = _bloques ?? [];
    if (bloques.isEmpty || bloques.every((b) => !b.disponible)) {
      return const VacioView(
        icono: Icons.event_busy_rounded,
        titulo: 'Sin horarios libres',
        mensaje: 'Todos los cupos de este día están tomados o ya pasaron. Prueba con otra fecha.',
      );
    }
    Widget grupo(String titulo, IconData icono, List<BloqueHorario> lista) {
      if (lista.isEmpty) return const SizedBox.shrink();
      final libres = lista.where((b) => b.disponible).length;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icono, size: 20, color: AppColors.accent),
          const SizedBox(width: 6),
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Text('$libres libres', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final b in lista)
            ChoiceChip(
              label: Text(Formatos.horaSql(b.inicio),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    decoration: b.disponible ? null : TextDecoration.lineThrough,
                  )),
              selected: _bloque == b,
              onSelected: b.disponible ? (_) => setState(() => _bloque = b) : null,
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
        ]),
        const SizedBox(height: 22),
      ]);
    }

    return ListView(padding: const EdgeInsets.all(20), children: [
      grupo('Mañana', Icons.wb_sunny_rounded, bloques.where((b) => b.turno == 'mañana').toList()),
      grupo('Tarde', Icons.wb_twilight_rounded, bloques.where((b) => b.turno == 'tarde').toList()),
    ]);
  }

  // ---------------- Paso 4 ----------------
  Widget _pasoConfirmar() {
    final c = _esp!.color;
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                    child: Icon(_esp!.icono, color: c),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_esp!.nombre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
                ]),
                const SizedBox(height: 8),
                const Divider(),
                InfoFila(icono: Icons.person_rounded, etiqueta: 'Profesional', valor: _doctor!.nombreCompleto, color: c),
                if (_doctor!.consultorio != null)
                  InfoFila(icono: Icons.location_on_rounded, etiqueta: 'Lugar', valor: _doctor!.consultorio!, color: c),
                InfoFila(icono: Icons.calendar_today_rounded, etiqueta: 'Fecha', valor: Formatos.diaLargo(_fecha!), color: c),
                InfoFila(
                  icono: Icons.access_time_rounded,
                  etiqueta: 'Hora',
                  valor: '${Formatos.horaSql(_bloque!.inicio)} - ${Formatos.horaSql(_bloque!.fin)} '
                      '(turno ${_bloque!.turno})',
                  color: c,
                ),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _motivo,
            maxLines: 3,
            maxLength: 300,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Motivo de la consulta (opcional)',
              hintText: 'Ej.: dolor de cabeza desde hace 3 días',
              alignLabelWithHint: true,
            ),
          ),
          Row(children: [
            Icon(Icons.info_outline_rounded, size: 18, color: Theme.of(context).hintColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Puedes cancelar desde "Mis citas" si no podrás asistir; así liberas el cupo para otro compañero.',
                  style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12.5)),
            ),
          ]),
        ]),
      ),
      _BarraInferior(
        texto: 'Todo listo',
        boton: 'Confirmar reserva',
        cargando: _reservando,
        onPressed: _reservando ? null : _reservar,
      ),
    ]);
  }
}

class _ResumenSeleccion extends StatelessWidget {
  const _ResumenSeleccion({required this.esp, this.doctor});
  final Especialidad esp;
  final Perfil? doctor;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: esp.color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(esp.icono, color: esp.color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              doctor == null ? esp.nombre : '${esp.nombre} · ${doctor!.nombreCompleto}',
              style: TextStyle(color: esp.color, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
      );
}

class _BarraInferior extends StatelessWidget {
  const _BarraInferior({required this.texto, required this.boton, required this.onPressed, this.cargando = false});
  final String texto;
  final String boton;
  final VoidCallback? onPressed;
  final bool cargando;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(texto, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).hintColor, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: onPressed,
                child: cargando
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : Text(boton),
              ),
            ]),
          ),
        ),
      );
}
