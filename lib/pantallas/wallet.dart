import 'package:flutter/material.dart';
import 'package:pointycastle/export.dart' show RSAPublicKey;

import '../api.dart';
import '../cripto.dart';
import '../main.dart';
import '../wallet.dart';
import 'comprar_bonos.dart';
import 'inicio.dart' show dinero;

class WalletPantalla extends StatefulWidget {
  final String email;
  const WalletPantalla({super.key, required this.email});
  @override
  State<WalletPantalla> createState() => _WalletPantallaState();
}

class _WalletPantallaState extends State<WalletPantalla> {
  final _pin = TextEditingController();
  final _pin2 = TextEditingController();
  bool? _existe; // null = cargando
  bool _ocupado = false;
  String? _errorPin;
  Wallet? _wallet;
  RSAPublicKey? _llaveBanco;

  @override
  void initState() {
    super.initState();
    Wallet.existe(widget.email).then((e) => setState(() => _existe = e));
  }

  Future<void> _desbloquear() async {
    final pin = _pin.text;
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) return setState(() => _errorPin = 'El PIN es de 4 a 8 dígitos');
    if (_existe == false && pin != _pin2.text) return setState(() => _errorPin = 'Los PIN no coinciden');
    setState(() {
      _ocupado = true;
      _errorPin = null;
    });
    final w = _existe! ? await Wallet.abrir(widget.email, pin) : await Wallet.crear(widget.email, pin);
    if (!mounted) return;
    setState(() {
      _ocupado = false;
      _wallet = w;
      if (w == null) _errorPin = 'PIN incorrecto';
    });
    _pin.clear();
    if (w != null) _cargarLlave();
  }

  Future<void> _cargarLlave() async {
    try {
      final k = llaveDePem(await Api.llavePublicaBanco());
      if (mounted) setState(() => _llaveBanco = k);
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  Future<void> _comprar() async {
    final nuevos = await Navigator.of(context).push<List<dynamic>>(MaterialPageRoute(builder: (_) => const ComprarBonosPantalla()));
    if (nuevos == null) return;
    await _wallet!.agregar(nuevos);
    if (mounted) setState(() {});
  }

  Future<void> _sincronizar() async {
    try {
      await _wallet!.reemplazar(await Api.bonos());
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = _wallet;
    return Scaffold(
      appBar: AppBar(title: const Text('Mi wallet'), actions: [
        if (w != null) IconButton(tooltip: 'Sincronizar con el banco', icon: const Icon(Icons.sync), onPressed: _sincronizar),
      ]),
      floatingActionButton: w == null
          ? null
          : FloatingActionButton.extended(onPressed: _comprar, icon: const Icon(Icons.add), label: const Text('Comprar bonos')),
      body: _existe == null ? const Center(child: CircularProgressIndicator()) : (w == null ? _formPin() : _lista(w)),
    );
  }

  Widget _formPin() {
    final nuevo = _existe == false;
    InputDecoration deco(String l) => InputDecoration(labelText: l, border: const OutlineInputBorder(), counterText: '');
    return ListView(padding: const EdgeInsets.all(24), children: [
      const Icon(Icons.lock, size: 56),
      const SizedBox(height: 8),
      Text(nuevo ? 'Crea un PIN para cifrar tu wallet en este celular' : 'Ingresa tu PIN para abrir el wallet',
          textAlign: TextAlign.center),
      const SizedBox(height: 20),
      TextField(controller: _pin, obscureText: true, keyboardType: TextInputType.number, maxLength: 8, decoration: deco('PIN')),
      if (nuevo) ...[
        const SizedBox(height: 12),
        TextField(controller: _pin2, obscureText: true, keyboardType: TextInputType.number, maxLength: 8, decoration: deco('Confirmar PIN')),
      ],
      if (_errorPin != null)
        Padding(padding: const EdgeInsets.only(top: 8), child: Text(_errorPin!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _ocupado ? null : _desbloquear,
        child: _ocupado
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(nuevo ? 'Crear wallet' : 'Abrir'),
      ),
    ]);
  }

  Widget _lista(Wallet w) {
    final t = Theme.of(context).textTheme;
    final k = _llaveBanco;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 88), children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Total en bonos', style: t.labelLarge),
            Text(dinero(w.total), style: t.displaySmall),
            Text('${w.bonos.length} bonos · guardado cifrado con AES-256-GCM'),
          ]),
        ),
      ),
      if (w.bonos.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Aún no tienes bonos')),
      for (final b in w.bonos)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(child: Text('${b['denominacion']}')),
          title: Text(dinero(b['denominacion'] as int)),
          subtitle: Text('Serie ${(b['serie'] as String).substring(0, 8)}… · ${(b['emitidoEn'] as String).substring(0, 10)}'),
          trailing: k == null
              ? const Text('…')
              : verificarBono(b, k)
                  ? const Chip(avatar: Icon(Icons.verified, color: Colors.green), label: Text('Firma válida'))
                  : const Chip(avatar: Icon(Icons.gpp_bad, color: Colors.red), label: Text('Firma inválida')),
        ),
    ]);
  }
}
