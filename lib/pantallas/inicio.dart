import 'package:flutter/material.dart';

import '../api.dart';
import '../main.dart';
import 'login.dart';
import 'wallet.dart';

String dinero(num n) {
  final s = n.abs().toStringAsFixed(2).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '${n < 0 ? '-' : ''}\$$s';
}

class InicioPantalla extends StatefulWidget {
  const InicioPantalla({super.key});
  @override
  State<InicioPantalla> createState() => _InicioPantallaState();
}

class _InicioPantallaState extends State<InicioPantalla> {
  Map<String, dynamic>? _cuenta;
  List<dynamic> _movimientos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final r = await Future.wait([Api.cuenta(), Api.movimientos()]);
      if (!mounted) return;
      setState(() {
        _cuenta = r[0] as Map<String, dynamic>;
        _movimientos = r[1] as List<dynamic>;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is ApiError && e.status == 401) return _salir();
      mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _salir() async {
    await Api.cerrarSesion();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPantalla()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final c = _cuenta;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(c == null ? 'Mi cuenta' : 'Hola, ${c['nombre']}'),
        actions: [IconButton(tooltip: 'Cerrar sesión', icon: const Icon(Icons.logout), onPressed: _salir)],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                if (c != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Saldo disponible', style: t.labelLarge),
                        Text(dinero(c['saldo'] as num), style: t.displaySmall),
                        const SizedBox(height: 12),
                        Text(c['email'] as String),
                        Text('CLABE ${c['clabe'] ?? '—'}', style: t.bodyMedium?.copyWith(fontFamily: 'monospace')),
                      ]),
                    ),
                  ),
                if (c != null) ...[
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.account_balance_wallet),
                    label: const Text('Mi wallet de bonos'),
                    onPressed: () async {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => WalletPantalla(email: c['email'] as String)));
                      _cargar(); // el saldo cambia al comprar bonos
                    },
                  ),
                ],
                const SizedBox(height: 16),
                Text('Movimientos', style: t.titleMedium),
                if (_movimientos.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Sin movimientos')),
                for (final m in _movimientos)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon((m['monto'] as num) < 0 ? Icons.arrow_upward : Icons.arrow_downward),
                    title: Text(m['detalle'] as String? ?? m['tipo'] as String),
                    subtitle: Text(DateTime.parse(m['fecha'] as String).toLocal().toString().substring(0, 16)),
                    trailing: Text(dinero(m['monto'] as num)),
                  ),
              ]),
            ),
    );
  }
}
