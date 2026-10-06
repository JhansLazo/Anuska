import 'package:flutter/material.dart';

import '../../core/utils/formatos.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/perfil.dart';
import '../../data/services/sesion.dart';
import 'widgets_auth.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _nombres = TextEditingController();
  final _apellidos = TextEditingController();
  final _dni = TextEditingController();
  final _codigo = TextEditingController();
  final _escuela = TextEditingController();
  final _telefono = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();
  String _tipo = 'estudiante';
  bool _ocultar = true;
  bool _enviando = false;

  @override
  void dispose() {
    for (final c in [_nombres, _apellidos, _dni, _codigo, _escuela, _telefono, _email, _password, _password2]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _requerido(String? v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null;

  Future<void> _registrar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _enviando = true);
    try {
      final conSesion = await Sesion.instancia.registrar(
        email: _email.text,
        password: _password.text,
        nombres: _nombres.text,
        apellidos: _apellidos.text,
        dni: _dni.text,
        codigoUniversitario: _codigo.text,
        telefono: _telefono.text,
        tipoUsuario: _tipo,
        escuela: _escuela.text,
      );
      if (!mounted) return;
      if (conSesion) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      } else {
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            icon: const Icon(Icons.mark_email_read_rounded, size: 40),
            title: const Text('Revisa tu correo'),
            content: Text('Enviamos un enlace de confirmación a ${_email.text.trim()}. '
                'Confírmalo y luego inicia sesión.'),
            actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Entendido'))],
          ),
        );
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) mostrarMensaje(context, Formatos.error(e), error: true);
    }
    if (mounted) setState(() => _enviando = false);
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14);
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(children: [
          const EncabezadoAuth(
            titulo: 'Crea tu cuenta',
            subtitulo: 'Solo te tomará un minuto. Usa tus datos reales para que te atiendan.',
            mostrarAtras: true,
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _form,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SeccionTitulo('Datos personales'),
                TextFormField(
                  controller: _nombres,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nombres', prefixIcon: Icon(Icons.person_outline_rounded)),
                  validator: _requerido,
                ),
                gap,
                TextFormField(
                  controller: _apellidos,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Apellidos', prefixIcon: Icon(Icons.badge_outlined)),
                  validator: _requerido,
                ),
                gap,
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _dni,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'DNI'),
                      validator: (v) => (v == null || v.trim().length < 8) ? 'DNI inválido' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _telefono,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Celular'),
                      validator: (v) => (v == null || v.trim().length < 9) ? 'Celular inválido' : null,
                    ),
                  ),
                ]),
                const SizedBox(height: 20),
                const SeccionTitulo('Datos universitarios'),
                DropdownButtonFormField<String>(
                  initialValue: _tipo,
                  decoration: const InputDecoration(labelText: 'Soy', prefixIcon: Icon(Icons.school_outlined)),
                  items: [
                    for (final e in tiposUsuario.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() => _tipo = v ?? 'estudiante'),
                ),
                gap,
                TextFormField(
                  controller: _codigo,
                  decoration: InputDecoration(
                    labelText: _tipo == 'estudiante' ? 'Código universitario' : 'Código / N.° de identificación',
                    prefixIcon: const Icon(Icons.credit_card_rounded),
                  ),
                  validator: _tipo == 'externo' ? null : _requerido,
                ),
                gap,
                TextFormField(
                  controller: _escuela,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Facultad / Escuela / Área (opcional)',
                    prefixIcon: Icon(Icons.apartment_rounded),
                  ),
                ),
                const SizedBox(height: 20),
                const SeccionTitulo('Acceso'),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Correo', prefixIcon: Icon(Icons.alternate_email_rounded)),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Correo inválido' : null,
                ),
                gap,
                TextFormField(
                  controller: _password,
                  obscureText: _ocultar,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    helperText: 'Mínimo 6 caracteres',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_ocultar ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _ocultar = !_ocultar),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                ),
                gap,
                TextFormField(
                  controller: _password2,
                  obscureText: _ocultar,
                  decoration: const InputDecoration(labelText: 'Repite la contraseña', prefixIcon: Icon(Icons.lock_reset_rounded)),
                  validator: (v) => v != _password.text ? 'Las contraseñas no coinciden' : null,
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _enviando ? null : _registrar,
                  child: _enviando
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : const Text('Crear cuenta'),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tus datos solo los ve el personal de salud de la universidad.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12.5),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
