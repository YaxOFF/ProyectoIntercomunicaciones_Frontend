import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'config.dart';

class ApiError implements Exception {
  final int status;
  final String mensaje;
  ApiError(this.status, this.mensaje);
  @override
  String toString() => mensaje;
}

/// Cliente del Banco. El JWT se guarda en flutter_secure_storage (Keystore de Android).
class Api {
  static const _storage = FlutterSecureStorage();
  static const _kToken = 'jwt';
  static String? _token;

  static Future<bool> cargarSesion() async {
    _token = await _storage.read(key: _kToken);
    return _token != null;
  }

  static Future<void> cerrarSesion() async {
    _token = null;
    await _storage.delete(key: _kToken);
  }

  static Future<void> login(String email, String password) =>
      _guardarToken(_post('$bancoUrl/auth/login', {'email': email, 'password': password}));

  static Future<void> registro(String nombre, String email, String password) => _guardarToken(
      _post('$bancoUrl/auth/registro', {'nombre': nombre, 'email': email, 'password': password}));

  static Future<Map<String, dynamic>> cuenta() async => await _get('$bancoUrl/cuenta') as Map<String, dynamic>;

  static Future<List<dynamic>> movimientos() async => await _get('$bancoUrl/cuenta/movimientos') as List<dynamic>;

  /// `{500: 1, 100: 3}` → bonos firmados recién emitidos.
  static Future<List<dynamic>> comprarBonos(Map<int, int> cantidades) async =>
      await _post('$bancoUrl/bonos/comprar', cantidades.map((d, n) => MapEntry('$d', n))) as List<dynamic>;

  /// Bonos EMITIDO del usuario según el banco (para resincronizar el wallet).
  static Future<List<dynamic>> bonos() async => await _get('$bancoUrl/bonos') as List<dynamic>;

  static String? _pemBanco;

  /// PEM de la llave pública de firma del banco (cacheada).
  static Future<String> llavePublicaBanco() async {
    if (_pemBanco != null) return _pemBanco!;
    final r = await http.get(Uri.parse('$bancoUrl/llave-publica')).timeout(_timeout);
    if (r.statusCode != 200) throw ApiError(r.statusCode, 'No se pudo obtener la llave del banco');
    return _pemBanco = r.body;
  }

  // ---- Tienda (sin JWT: la tienda no tiene cuentas, el pedido lleva el email dentro del paquete cifrado) ----

  static Future<List<dynamic>> productos() async => await _get('$tiendaUrl/productos', auth: false) as List<dynamic>;

  static Future<List<dynamic>> pedidos(String email) async =>
      await _get('$tiendaUrl/pedidos?email=${Uri.encodeQueryComponent(email)}', auth: false) as List<dynamic>;

  /// Paquete híbrido `{llaveCifrada, nonce, datos}` → `{pedidoId, total}`.
  static Future<Map<String, dynamic>> pagar(Map<String, String> paquete) async =>
      await _post('$tiendaUrl/compras', paquete, auth: false) as Map<String, dynamic>;

  static String? _pemTienda;

  /// PEM de la llave pública de cifrado de la tienda (cacheada).
  static Future<String> llavePublicaTienda() async {
    if (_pemTienda != null) return _pemTienda!;
    final r = await http.get(Uri.parse('$tiendaUrl/llave-publica')).timeout(_timeout);
    if (r.statusCode != 200) throw ApiError(r.statusCode, 'No se pudo obtener la llave de la tienda');
    return _pemTienda = r.body;
  }

  static Future<void> _guardarToken(Future<dynamic> respuesta) async {
    _token = (await respuesta)['token'] as String;
    await _storage.write(key: _kToken, value: _token);
  }

  static Map<String, String> _headers(bool auth) => {
        'Content-Type': 'application/json',
        if (auth && _token != null) 'Authorization': 'Bearer $_token',
      };

  static Future<dynamic> _post(String url, Object body, {bool auth = true}) async =>
      _leer(await http.post(Uri.parse(url), headers: _headers(auth), body: jsonEncode(body)).timeout(_timeout), auth);

  static Future<dynamic> _get(String url, {bool auth = true}) async =>
      _leer(await http.get(Uri.parse(url), headers: _headers(auth)).timeout(_timeout), auth);

  static const _timeout = Duration(seconds: 10);

  static dynamic _leer(http.Response r, bool auth) {
    final cuerpo = r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode >= 200 && r.statusCode < 300) return cuerpo;
    if (auth && r.statusCode == 401 && _token != null) cerrarSesion(); // JWT expirado
    final msg = cuerpo is Map ? (cuerpo['error'] ?? cuerpo['title'] ?? 'Error ${r.statusCode}') : 'Error ${r.statusCode}';
    throw ApiError(r.statusCode, msg.toString());
  }
}
