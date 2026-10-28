import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _webUrl =
      'https://villadiegorodrigo7-coder.github.io/neuroplan-ai/';

  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _cargando = false;
  bool _modoRegistro = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _enviar() async {
    final email = _email.text.trim();
    final pass = _password.text;
    if (email.isEmpty || pass.length < 6) {
      _aviso('Escribe un correo y una contraseña de al menos 6 caracteres.');
      return;
    }

    setState(() => _cargando = true);
    final auth = Supabase.instance.client.auth;
    try {
      if (_modoRegistro) {
        final res = await auth.signUp(
          email: email,
          password: pass,
          emailRedirectTo: kIsWeb ? _webUrl : null,
        );
        // Si "Confirm email" está activo, no hay sesión hasta confirmar.
        if (res.session == null) {
          _aviso('Revisa tu correo para confirmar la cuenta.');
        }
      } else {
        await auth.signInWithPassword(email: email, password: pass);
        // AuthGate reacciona solo al cambio de sesión.
      }
    } on AuthException catch (e) {
      _aviso(e.message);
    } catch (_) {
      _aviso('Error inesperado. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('NEUROPLAN AI',
                      textAlign: TextAlign.center,
                      style: tema.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    _modoRegistro
                        ? 'Crea tu cuenta para guardar tu progreso'
                        : 'Ingresa para continuar tu plan',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.bodyMedium
                        ?.copyWith(color: const Color(0xFFA9A7C4)),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'Correo'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _cargando ? null : _enviar(),
                    decoration: const InputDecoration(labelText: 'Contraseña'),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _cargando ? null : _enviar,
                    child: _cargando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_modoRegistro ? 'Crear cuenta' : 'Ingresar'),
                  ),
                  TextButton(
                    onPressed: _cargando
                        ? null
                        : () => setState(() => _modoRegistro = !_modoRegistro),
                    child: Text(_modoRegistro
                        ? 'Ya tengo cuenta'
                        : 'Crear una cuenta nueva'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
