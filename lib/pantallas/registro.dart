import 'package:flutter/material.dart';

import '../api.dart';
import '../main.dart';
import 'inicio.dart';

class RegistroPantalla extends StatefulWidget {
  const RegistroPantalla({super.key});
  @override
  State<RegistroPantalla> createState() => _RegistroPantallaState();
}

class _RegistroPantallaState extends State<RegistroPantalla> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _cargando = false;

  Future<void> _registrar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      await Api.registro(_nombre.text.trim(), _email.text.trim(), _password.text);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const InicioPantalla()), (_) => false);
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Crear cuenta')),
        body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(24), children: [
            TextFormField(
              controller: _nombre,
              decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Obligatorio' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
              validator: (v) => (v ?? '').contains('@') ? null : 'Email inválido',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
              validator: (v) => (v ?? '').length >= 6 ? null : 'Mínimo 6 caracteres',
            ),
            const SizedBox(height: 8),
            Text('Tu cuenta nace con \$10,000 de saldo (mock).', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _cargando ? null : _registrar,
              child: _cargando
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Registrarme'),
            ),
          ]),
        ),
      );
}
