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

  test('elegirBonos: menor suma que cubra, luego menos bonos; null si no alcanza', () {
    final bonos = [for (final d in [100, 50, 20, 20, 20, 500, 300]) {'denominacion': d}];
    int suma(List<Map<String, dynamic>> l) => l.fold(0, (s, b) => s + (b['denominacion'] as int));
    expect(suma(elegirBonos(bonos, 360)!), 360);
    expect(elegirBonos(bonos, 800)!.length, 2); // 500 + 300
    expect(elegirBonos(bonos, 40)!.length, 2);
    expect(elegirBonos(bonos, 2000), isNull); // el wallet no alcanza
    expect(suma(elegirBonos(bonos, 30)!), 40); // sin exacto: el excedente más chico (20 + 20)
    expect(suma(elegirBonos(bonos, 120)!), 120); // exacto si existe (100 + 20)
    expect(elegirBonos([for (final d in [500, 20]) {'denominacion': d}], 120)!.single['denominacion'], 500);
  });
}
