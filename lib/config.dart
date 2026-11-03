/// URLs del backend. 10.0.2.2 es el localhost de la PC visto desde el emulador Android.
/// En producción serían URLs HTTPS (TLS); en local se usa HTTP.
const bancoUrl = String.fromEnvironment('BANCO_URL', defaultValue: 'http://10.0.2.2:5001');
const tiendaUrl = String.fromEnvironment('TIENDA_URL', defaultValue: 'http://10.0.2.2:5002');
