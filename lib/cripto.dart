import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart' show CryptoUtils;
import 'package:pointycastle/export.dart';

/// Firma digital: verifica un bono con la llave pública del banco (RSA-PSS SHA-256, salt 32).
/// Mensaje canónico: `serie|denominacion|emitidoEn` (formato fijado en Backend/PLAN.md).
bool verificarBono(Map<String, dynamic> bono, RSAPublicKey llaveBanco) {
  try {
    final mensaje = utf8.encode('${bono['serie']}|${bono['denominacion']}|${bono['emitidoEn']}');
    final signer = PSSSigner(RSAEngine(), SHA256Digest(), SHA256Digest())
      ..init(false, ParametersWithSaltConfiguration(PublicKeyParameter<RSAPublicKey>(llaveBanco), _random(), 32));
    return signer.verifySignature(mensaje, PSSSignature(base64Decode(bono['firma'] as String)));
  } catch (_) {
    return false;
  }
}

RSAPublicKey llaveDePem(String pem) => CryptoUtils.rsaPublicKeyFromPem(pem);

/// Cifrado simétrico del wallet: AES-256-GCM con llave derivada del PIN (PBKDF2-HMAC-SHA256).
/// Formato guardado: base64(salt16 | nonce12 | cifrado | tag16).
const _iteraciones = 100000;

class LlaveWallet {
  final Uint8List salt;
  final Uint8List llave;
  LlaveWallet._(this.salt, this.llave);

  /// PIN nuevo: salt aleatorio.
  factory LlaveWallet.nueva(String pin) {
    final salt = _random().nextBytes(16);
    return LlaveWallet._(salt, _derivar(pin, salt));
  }

  /// Deriva la llave con el salt guardado. Devuelve null si el PIN es incorrecto (falla el tag GCM).
  static ({LlaveWallet llave, String json})? abrir(String pin, String guardado) {
    final b = base64Decode(guardado);
    final salt = b.sublist(0, 16);
    final llave = LlaveWallet._(salt, _derivar(pin, salt));
    try {
      final claro = _gcm(false, llave.llave, b.sublist(16, 28)).process(b.sublist(28));
      return (llave: llave, json: utf8.decode(claro));
    } on InvalidCipherTextException {
      return null;
    }
  }

  String cifrar(String json) {
    final nonce = _random().nextBytes(12);
    final cifrado = _gcm(true, llave, nonce).process(utf8.encode(json));
    return base64Encode([...salt, ...nonce, ...cifrado]);
  }

  static Uint8List _derivar(String pin, Uint8List salt) =>
      (PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))..init(Pbkdf2Parameters(salt, _iteraciones, 32)))
          .process(utf8.encode(pin));

  static GCMBlockCipher _gcm(bool cifrar, Uint8List llave, Uint8List nonce) =>
      GCMBlockCipher(AESEngine())..init(cifrar, AEADParameters(KeyParameter(llave), 128, nonce, Uint8List(0)));
}

SecureRandom _random() {
  final r = Random.secure();
  return FortunaRandom()..seed(KeyParameter(Uint8List.fromList(List.generate(32, (_) => r.nextInt(256)))));
}
