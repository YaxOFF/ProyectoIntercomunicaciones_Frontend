import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_intercomunicaciones/cripto.dart';

// Fixture real: bono emitido por Banco.Api y su llave pública (test/bono.json, test/banco.pem).
void main() {
  final llave = llaveDePem(File('test/banco.pem').readAsStringSync());
  final bono = (jsonDecode(File('test/bono.json').readAsStringSync()) as List).first as Map<String, dynamic>;

  test('bono del banco verifica; alterado no', () {
    expect(verificarBono(bono, llave), isTrue);
    expect(verificarBono({...bono, 'denominacion': 500}, llave), isFalse);
  });

  test('wallet: PIN correcto abre, PIN incorrecto no', () {
    final guardado = LlaveWallet.nueva('1234').cifrar('[{"x":1}]');
    expect(LlaveWallet.abrir('1234', guardado)!.json, '[{"x":1}]');
    expect(LlaveWallet.abrir('9999', guardado), isNull);
  });
}
