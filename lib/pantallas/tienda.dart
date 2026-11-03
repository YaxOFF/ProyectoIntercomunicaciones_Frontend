import 'package:flutter/material.dart';

import '../api.dart';
import '../cripto.dart';
import '../main.dart';
import '../wallet.dart';
import 'inicio.dart' show dinero;

/// Catálogo + carrito + checkout. Necesita el wallet ya abierto con el PIN.
class TiendaPantalla extends StatefulWidget {
  final Wallet wallet;
  const TiendaPantalla({super.key, required this.wallet});
  @override
  State<TiendaPantalla> createState() => _TiendaPantallaState();
}

class _TiendaPantallaState extends State<TiendaPantalla> {
  List<dynamic> _productos = [];
  final _carrito = <int, int>{}; // productoId → cantidad
  bool _cargando = true;
  bool _pagando = false;
  Map<String, String>? _ultimoPaquete; // para la demo de repetición (doble gasto)

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final p = await Api.productos();
      if (mounted) setState(() => _productos = p);
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  int get _total => _productos.fold(0, (s, p) => s + (_carrito[p['id']] ?? 0) * (p['precio'] as num).toInt());

  void _cambiar(Map p, int delta) {
    final id = p['id'] as int;
    final n = ((_carrito[id] ?? 0) + delta).clamp(0, p['existencia'] as int);
    setState(() => n == 0 ? _carrito.remove(id) : _carrito[id] = n);
  }

  /// [alterado]: ataque de demo. Sube a $500 la denominación de un bono sin poder re-firmarlo → la tienda lo rechaza (400).
  Future<void> _pagar({bool alterado = false}) async {
    final w = widget.wallet;
    final total = _total;
    final elegidos = elegirBonos(w.bonos, total);
    if (elegidos == null) {
      return _aviso('Sin pago exacto',
          'Tus bonos (${dinero(w.total)}) no suman exactamente ${dinero(total)}. La tienda no da cambio: compra bonos de \$20 en tu wallet.');
    }
    var bonos = elegidos;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(alterado ? 'Ataque: bono alterado' : 'Pagar ${dinero(total)}'),
        content: Text('${alterado ? 'El bono de \$${bonos.first['denominacion']} se enviará como \$500 con su firma original.\n\n' : ''}Se usarán ${bonos.length} bonos: ${bonos.map((b) => '\$${b['denominacion']}').join(' + ')}.\n\n'
            'El pago se cifra con AES-256-GCM y la llave con RSA-OAEP de la tienda.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Pagar')),
        ],
      ),
    );
    if (ok != true) return;
    if (alterado) bonos = [{...bonos.first, 'denominacion': 500}, ...bonos.skip(1)];
    setState(() => _pagando = true);
    try {
      final llave = llaveDePem(await Api.llavePublicaTienda());
      final paquete = cifrarPaquete({
        'email': w.email,
        'items': [for (final e in _carrito.entries) {'productoId': e.key, 'cantidad': e.value}],
        'bonos': bonos,
      }, llave);
      if (!alterado) _ultimoPaquete = paquete;
      final r = await Api.pagar(paquete);
      final gastadas = bonos.map((b) => b['serie']).toSet();
      await w.reemplazar(w.bonos.where((b) => !gastadas.contains(b['serie'])));
      _carrito.clear();
      await _cargar(); // existencias nuevas
      if (mounted) _aviso('Pedido #${r['pedidoId']} pagado', 'Total ${dinero(r['total'] as num)}. Los bonos usados salieron de tu wallet.');
    } catch (e) {
      if (mounted) _error(e);
    } finally {
      if (mounted) setState(() => _pagando = false);
    }
  }

  /// Ataque de repetición: reenvía el mismo paquete cifrado. El banco ya marcó los bonos como CANJEADO → 409.
  Future<void> _reenviar() async {
    setState(() => _pagando = true);
    try {
      await Api.pagar(_ultimoPaquete!);
      if (mounted) _aviso('Aceptado', 'La tienda aceptó el paquete repetido (no debería pasar).');
    } catch (e) {
      if (mounted) _error(e);
    } finally {
      if (mounted) setState(() => _pagando = false);
    }
  }

  void _error(Object e) {
    if (e is ApiError && e.status == 409) {
      _aviso('Pago rechazado', '${e.mensaje}.\n\nSi tu wallet tiene bonos ya gastados, sincronízalo con el banco.');
    } else if (e is ApiError) {
      _aviso('Pago rechazado', e.mensaje);
    } else {
      mostrarError(context, e);
    }
  }

  Future<void> _aviso(String titulo, String texto) => showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(titulo),
          content: Text(texto),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final total = _total;
    return Scaffold(
      appBar: AppBar(title: const Text('Tienda'), actions: [
        IconButton(
          tooltip: 'Mis pedidos',
          icon: const Icon(Icons.receipt_long),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PedidosPantalla(email: widget.wallet.email))),
        ),
      ]),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(padding: const EdgeInsets.fromLTRB(8, 8, 8, 16), children: [
                for (final p in _productos)
                  ListTile(
                    title: Text(p['nombre'] as String),
                    subtitle: Text('${dinero(p['precio'] as num)} · ${p['existencia']} disponibles\n${p['descripcion'] ?? ''}'),
                    isThreeLine: true,
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => _cambiar(p, -1)),
                      Text('${_carrito[p['id']] ?? 0}'),
                      IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => _cambiar(p, 1)),
                    ]),
                  ),
                if (total > 0)
                  TextButton.icon(
                    icon: const Icon(Icons.gpp_bad_outlined),
                    label: const Text('Pagar con un bono alterado (prueba de firma)'),
                    onPressed: _pagando ? null : () => _pagar(alterado: true),
                  ),
                if (_ultimoPaquete != null)
                  TextButton.icon(
                    icon: const Icon(Icons.replay),
                    label: const Text('Reenviar el último paquete (prueba de doble gasto)'),
                    onPressed: _pagando ? null : _reenviar,
                  ),
              ]),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(child: Text('Wallet ${dinero(widget.wallet.total)}\nTotal ${dinero(total)}')),
            FilledButton.icon(
              icon: _pagando
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.lock),
              label: const Text('Pagar'),
              onPressed: total == 0 || _pagando ? null : _pagar,
            ),
          ]),
        ),
      ),
    );
  }
}

class PedidosPantalla extends StatelessWidget {
  final String email;
  const PedidosPantalla({super.key, required this.email});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mis pedidos')),
        body: FutureBuilder(
          future: Api.pedidos(email),
          builder: (context, s) {
            if (s.hasError) return Center(child: Text(s.error is ApiError ? '${s.error}' : 'No se pudo conectar con la tienda'));
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            final pedidos = s.data!;
            if (pedidos.isEmpty) return const Center(child: Text('Aún no tienes pedidos'));
            return ListView(children: [
              for (final p in pedidos)
                ListTile(
                  title: Text('Pedido #${p['id']} · ${dinero(p['total'] as num)}'),
                  subtitle: Text([
                    DateTime.parse(p['fecha'] as String).toLocal().toString().substring(0, 16),
                    for (final i in p['items'] as List) '${i['cantidad']} × ${i['producto']}',
                    '${(p['bonosUsados'] as List).length} bonos',
                  ].join('\n')),
                  trailing: Text('${p['estado']}'),
                ),
            ]);
          },
        ),
      );
}
