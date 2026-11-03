import 'package:flutter/material.dart';

import '../api.dart';
import '../main.dart';
import 'inicio.dart' show dinero;

/// Elige cuántos bonos de cada denominación comprar. Devuelve (pop) la lista de bonos emitidos.
class ComprarBonosPantalla extends StatefulWidget {
  const ComprarBonosPantalla({super.key});
  @override
  State<ComprarBonosPantalla> createState() => _ComprarBonosPantallaState();
}

class _ComprarBonosPantallaState extends State<ComprarBonosPantalla> {
  static const _denominaciones = [500, 300, 100, 50, 20];
  final _cantidades = {for (final d in _denominaciones) d: 0};
  bool _cargando = false;

  int get _total => _cantidades.entries.fold(0, (s, e) => s + e.key * e.value);
  int get _piezas => _cantidades.values.fold(0, (s, n) => s + n);

  Future<void> _confirmar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Confirmar compra'),
        content: Text('Se descontarán ${dinero(_total)} de tu saldo por $_piezas bonos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Comprar')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _cargando = true);
    try {
      final bonos = await Api.comprarBonos(Map.of(_cantidades)..removeWhere((_, n) => n == 0));
      if (mounted) Navigator.pop(context, bonos);
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Comprar bonos')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          for (final d in _denominaciones)
            ListTile(
              title: Text('Bono de ${dinero(d)}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _cantidades[d]! > 0 ? () => setState(() => _cantidades[d] = _cantidades[d]! - 1) : null,
                ),
                SizedBox(width: 28, child: Text('${_cantidades[d]}', textAlign: TextAlign.center)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _piezas < 100 ? () => setState(() => _cantidades[d] = _cantidades[d]! + 1) : null,
                ),
              ]),
            ),
          const Divider(),
          ListTile(title: const Text('Total'), trailing: Text(dinero(_total), style: Theme.of(context).textTheme.titleLarge)),
        ]),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: _total == 0 || _cargando ? null : _confirmar,
              child: _cargando
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Comprar'),
            ),
          ),
        ),
      );
}
