import 'package:flutter/material.dart';

import 'api.dart';
import 'pantallas/inicio.dart';
import 'pantallas/login.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final conSesion = await Api.cargarSesion();
  runApp(MonederoApp(conSesion: conSesion));
}

class MonederoApp extends StatelessWidget {
  final bool conSesion;
  const MonederoApp({super.key, required this.conSesion});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Monedero de bonos',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        home: conSesion ? const InicioPantalla() : const LoginPantalla(),
      );
}

/// Muestra un error en un SnackBar.
void mostrarError(BuildContext context, Object e) {
  final msg = e is ApiError ? e.mensaje : 'No se pudo conectar con el servidor';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}
