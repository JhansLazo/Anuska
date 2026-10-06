import 'package:flutter/material.dart';

import '../../core/utils/formatos.dart';
import '../../core/widgets/ui.dart';
import '../../data/services/sesion.dart';
import 'register_screen.dart';
import 'widgets_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _ocultar = true;
  bool _enviando = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _enviando = true);
    try {
      await Sesion.instancia.iniciarSesion(_email.text, _password.text);
    } catch (e) {
      if (mounted) mostrarMensaje(context, Formatos.error(e), error: true);
    }
    if (mounted) setState(() => _enviando = false);
  }

  Future<void> _recuperar() async {
    if (!_email.text.contains('@')) {
      mostrarMensaje(context, 'Escribe tu correo arriba y vuelve a tocar "¿Olvidaste tu contraseña?"', error: true);
      return;
    }
    try {
      await Sesion.instancia.recuperarContrasena(_email.text);
      if (mounted) mostrarMensaje(context, 'Te enviamos un correo para restablecer tu contraseña');
    } catch (e) {
      if (mounted) mostrarMensaje(context, Formatos.error(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(children: [
          const EncabezadoAuth(
            titulo: 'Tu salud, sin llamadas ni colas',
            subtitulo: 'Reserva citas de Medicina, Enfermería, Psicología y Odontología en segundos.',
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _form,
              child: AutofillGroup(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('Iniciar sesión', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Correo institucional', prefixIcon: Icon(Icons.alternate_email_rounded)),
                    validator: (v) => (v == null || !v.contains('@')) ? 'Ingresa un correo válido' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _password,
                    obscureText: _ocultar,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _ingresar(),
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        tooltip: _ocultar ? 'Mostrar' : 'Ocultar',
                        icon: Icon(_ocultar ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _ocultar = !_ocultar),
                      ),
                    ),
                    validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(onPressed: _recuperar, child: const Text('¿Olvidaste tu contraseña?')),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _enviando ? null : _ingresar,
                    child: _enviando
                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                        : const Text('Ingresar'),
                  ),
                  const SizedBox(height: 24),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text('¿Aún no tienes cuenta?'),
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                      child: const Text('Regístrate', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
