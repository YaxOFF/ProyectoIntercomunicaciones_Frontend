# Guion de demo (10-12 min)

Objetivo: mostrar las tres técnicas (firma digital, cifrado híbrido, cifrado simétrico) funcionando y dos ataques
rechazados en vivo.

## Antes de empezar

1. Backend: en el repo Backend, `docker compose up -d --build` y comprobar `curl http://localhost:5002/productos`.
2. Abrir el emulador Android e instalar la app (`flutter run`).
3. Tener a mano `SEGURIDAD.md` (diagramas) y una terminal con `psql` para mostrar la BD.
4. Usar una cuenta nueva para que el wallet empiece vacío (o `ana@demo.com` / `demo123`).

## 1. El problema (1 min)

Un banco emite bonos de $500, $300, $100, $50 y $20; una tienda los acepta como pago. Riesgos: bonos
falsificados o alterados, pagos espiados en la red, celular robado, base de datos filtrada, y gastar el mismo
bono dos veces.

## 2. Cuenta y cifrado en la BD (2 min)

1. Registrar una cuenta nueva en la app. Nace con $10,000 y una CLABE.
2. La pantalla de Inicio muestra la CLABE enmascarada (`01-inicio.png`).
3. En la terminal mostrar que en la BD la CLABE no se puede leer:
   ```bash
   docker exec -it intercom-banco-db-1 psql -U postgres -d banco -c 'select "Email","ClabeCifrada","PasswordHash" from "Usuarios" order by "Id" desc limit 1;'
   ```
   Decir: la CLABE va cifrada con **AES-256-GCM** (simétrica). La contraseña no se cifra: se guarda con hash PBKDF2.

## 3. Comprar bonos firmados (2 min)

1. Abrir **Mi wallet y tienda**. La primera vez se crea un PIN (`02-pin.png`).
2. **Comprar bonos**: por ejemplo 1 × $500 y 1 × $100. El saldo baja $600.
3. En el wallet cada bono muestra **Firma válida** (`03-wallet.png`). Decir: el banco firma
   `serie|denominacion|emitidoEn` con su llave privada **RSA-PSS SHA-256**; la app verifica con la llave
   pública (`GET /llave-publica`). Nadie sin la llave privada puede crear un bono válido.

## 4. Wallet cifrado en el celular (1 min)

1. Cerrar la app y volver a abrirla. Entrar al wallet con un PIN incorrecto: no abre.
2. Con el PIN correcto abre. Decir: el wallet se guarda con **AES-256-GCM** y la llave sale del PIN con
   PBKDF2 (100,000 iteraciones). Si roban el celular, los bonos están cifrados.

## 5. Ataque 1: bono alterado (1.5 min)

1. En la tienda poner en el carrito productos por $600 (5 tazas de $120).
2. Tocar **Pagar con un bono alterado (prueba de firma)**: la app cambia el bono de $100 a $500 y lo envía con
   su firma original (`05-ataque-bono-alterado.png`).
3. La tienda responde **"Firma inválida en el bono …"**. No se cobra nada; el wallet sigue igual.
   Decir: cambiar un solo dígito invalida la firma, y la tienda verifica cada bono con la llave del banco.

## 6. Compra cifrada (2 min)

1. Tocar **Pagar**. La app elige la combinación exacta ($500 + $100) (`06-pagar.png`).
2. Decir el flujo híbrido (diagrama de `SEGURIDAD.md`): la app genera una llave AES de un solo uso, cifra el
   pedido y los bonos con **AES-256-GCM**, y cifra esa llave con **RSA-OAEP** usando la llave pública de la
   tienda. Solo la tienda puede descifrar. Quien espíe la red ve tres textos en base64.
3. Resultado: **Pedido pagado** (`07-pedido-pagado.png`). La existencia baja y los bonos salen del wallet.

## 7. Ataque 2: doble gasto (1 min)

1. Tocar **Reenviar el último paquete (prueba de doble gasto)**. Es el mismo paquete cifrado que alguien
   pudo copiar de la red.
2. Respuesta: **"Algún bono ya fue gastado; no se cobró nada"** (`08-ataque-doble-gasto.png`).
   Decir: la tienda canjea los bonos en el banco (server-to-server con `X-Api-Key`); el banco los marca
   `CANJEADO` en una transacción todo-o-nada.

## 8. Cierre (1 min)

- Pruebas automáticas: `dotnet test` en el backend (8) y `flutter test` en la app.
- Propuestas no implementadas: HTTPS/TLS con certificados, llaves en HSM, rotación de llaves.
