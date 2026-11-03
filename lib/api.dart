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

  static Future<void> _guardarToken(Future<dynamic> respuesta) async {
    _token = (await respuesta)['token'] as String;
    await _storage.write(key: _kToken, value: _token);
  }

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  static Future<dynamic> _post(String url, Object body) async =>
      _leer(await http.post(Uri.parse(url), headers: _headers, body: jsonEncode(body)).timeout(_timeout));

  static Future<dynamic> _get(String url) async =>
      _leer(await http.get(Uri.parse(url), headers: _headers).timeout(_timeout));

  static const _timeout = Duration(seconds: 10);

  static dynamic _leer(http.Response r) {
    final cuerpo = r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode >= 200 && r.statusCode < 300) return cuerpo;
    if (r.statusCode == 401 && _token != null) cerrarSesion(); // JWT expirado
    final msg = cuerpo is Map ? (cuerpo['error'] ?? cuerpo['title'] ?? 'Error ${r.statusCode}') : 'Error ${r.statusCode}';
    throw ApiError(r.statusCode, msg.toString());
  }
}
