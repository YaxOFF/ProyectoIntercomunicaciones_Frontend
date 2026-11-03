import 'package:flutter/material.dart';

import '../api.dart';
import '../main.dart';
import 'inicio.dart';
import 'registro.dart';

class LoginPantalla extends StatefulWidget {
  const LoginPantalla({super.key});
  @override
  State<LoginPantalla> createState() => _LoginPantallaState();
}

class _LoginPantallaState extends State<LoginPantalla> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _cargando = false;

  Future<void> _entrar() async {
    setState(() => _cargando = true);
    try {
      await Api.login(_email.text.trim(), _password.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const InicioPantalla()));
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: AutofillGroup(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Icon(Icons.account_balance_wallet, size: 72),
                  const SizedBox(height: 8),
                  Text('Monedero de bonos', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _entrar(),
                    decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _cargando ? null : _entrar,
                    child: _cargando
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Entrar'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegistroPantalla())),
                    child: const Text('Crear cuenta'),
                  ),
                  const SizedBox(height: 8),
                  Text('Demo: ana@demo.com / demo123', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                ]),
              ),
            ),
          ),
        ),
      );
}
