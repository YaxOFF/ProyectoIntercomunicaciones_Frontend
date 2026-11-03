import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'cripto.dart';

/// Wallet de bonos del usuario. En el celular solo existe cifrado (AES-GCM, llave del PIN).
class Wallet {
  static const _storage = FlutterSecureStorage();
  static String _clave(String email) => 'wallet_$email';

  final String email;
  final LlaveWallet _llave;
  List<Map<String, dynamic>> bonos;
  Wallet._(this.email, this._llave, this.bonos);

  static Future<bool> existe(String email) => _storage.containsKey(key: _clave(email));

  /// Crea un wallet vacío con PIN nuevo.
  static Future<Wallet> crear(String email, String pin) async {
    final w = Wallet._(email, await compute(LlaveWallet.nueva, pin), []);
    await w.guardar();
    return w;
  }

  /// null = PIN incorrecto. PBKDF2 corre en otro isolate para no congelar la UI.
  static Future<Wallet?> abrir(String email, String pin) async {
    final guardado = (await _storage.read(key: _clave(email)))!;
    final r = await compute((_) => LlaveWallet.abrir(pin, guardado), null);
    if (r == null) return null;
    return Wallet._(email, r.llave, (jsonDecode(r.json) as List).cast<Map<String, dynamic>>());
  }

  int get total => bonos.fold(0, (s, b) => s + (b['denominacion'] as int));

  /// Agrega bonos sin duplicar series.
  Future<void> agregar(Iterable<dynamic> nuevos) {
    final series = bonos.map((b) => b['serie']).toSet();
    bonos = [...bonos, ...nuevos.cast<Map<String, dynamic>>().where((b) => !series.contains(b['serie']))];
    return guardar();
  }

  /// Reemplaza el contenido por lo que el banco reporta como EMITIDO.
  Future<void> reemplazar(Iterable<dynamic> delBanco) {
    bonos = delBanco.cast<Map<String, dynamic>>().toList();
    return guardar();
  }

  Future<void> guardar() => _storage.write(key: _clave(email), value: _llave.cifrar(jsonEncode(bonos)));
}
