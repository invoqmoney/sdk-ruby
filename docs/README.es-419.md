# SDK de invoq para Ruby

[English](../README.md) · [Bahasa Indonesia](./README.id.md) · **Español** · [Français](./README.fr.md) · [Português](./README.pt-BR.md) · [Tiếng Việt](./README.vi.md) · [Türkçe](./README.tr.md) · [ไทย](./README.th.md) · [简体中文](./README.zh-Hans.md) · [繁體中文](./README.zh-Hant.md)

> Este documento es una traducción del README en inglés; si algo difiere, vale la [versión en inglés](../README.md).

Acepta pagos en stablecoins con invoq desde código de servidor en Ruby. Este SDK envuelve las APIs de servidor de invoq y verifica webhooks firmados.

Usa esta gem solo en tu servidor. Maneja claves secretas y no debería incluirse en el código del navegador.

## SDKs de servidor

Crea facturas y verifica webhooks desde tu backend en cualquiera de estos lenguajes — la misma REST API y la misma firma de webhook. Este repositorio es el SDK de Ruby.

| Lenguaje | Repositorio |
| --- | --- |
| Node.js | [github.com/invoqmoney/sdk-js](https://github.com/invoqmoney/sdk-js) (`@invoq/server`) |
| Python | [github.com/invoqmoney/sdk-python](https://github.com/invoqmoney/sdk-python) |
| PHP | [github.com/invoqmoney/sdk-php](https://github.com/invoqmoney/sdk-php) |
| Go | [github.com/invoqmoney/sdk-go](https://github.com/invoqmoney/sdk-go) |
| Rust | [github.com/invoqmoney/sdk-rust](https://github.com/invoqmoney/sdk-rust) |
| Ruby | **este repositorio** |

El lado del navegador es el mismo para cualquier backend: **`@invoq/checkout`** (JavaScript, en [github.com/invoqmoney/sdk-js](https://github.com/invoqmoney/sdk-js)) abre la ventana de pago integrada en la página para cualquier frontend.

## Instalación

Instala la gem:

```sh
gem install invoq
```

O agrégala a un Gemfile:

```ruby
gem "invoq"
```

Requiere Ruby 2.6 o más nuevo.

## Consigue tus claves

1. Inicia sesión en el [panel de invoq](https://app.invoq.money) y crea un proyecto.
2. En la página **API keys**, crea una clave secreta. Las claves de prueba empiezan con `sk_test_`, las claves de producción con `sk_live_`. El modo de la clave determina si las facturas son de prueba o de producción.
3. En la configuración de **webhooks** de tu proyecto, guarda tu URL de webhook. El secreto del webhook (`whsec_...`) de ese modo se muestra una sola vez, cuando activas el webhook por primera vez. Guárdalo de inmediato. Las URL de webhook deben ser HTTPS y públicas.
4. Configura tu **Receiving wallet** antes de pasar a producción. Las facturas de prueba no la necesitan; una factura real sin destino de liquidación falla con `409 no_payment_options_available`.

Agrega ambos al entorno de tu servidor:

```sh
INVOQ_SECRET_KEY=sk_test_...
INVOQ_WEBHOOK_SECRET=whsec_...
```

Empieza con las claves de prueba. Cambia a la clave de producción y al secreto de webhook de producción cuando pases a producción.

## Crea un cliente

```ruby
require "invoq"

invoq = Invoq.new(ENV.fetch("INVOQ_SECRET_KEY"))
```

Origen de la API de producción por defecto:

```txt
https://api.invoq.money
```

Sobrescribe el origen de la API y el tiempo de espera de la solicitud durante el desarrollo:

```ruby
invoq = Invoq.new(
  ENV.fetch("INVOQ_SECRET_KEY"),
  api_origin: "http://localhost:8787",
  timeout_ms: 10_000
)
```

`api_origin` debe ser un origen `http` o `https` absoluto, sin ruta, cadena de consulta, fragmento, usuario ni contraseña. El SDK agrega las rutas de recursos `/v1/...`.

Las solicitudes expiran a los 10 segundos por defecto. Pasa `timeout_ms` para cambiar el tiempo de espera. `timeout_ms` debe ser un entero positivo en milisegundos.

## Facturas

Crea una factura:

```ruby
invoice = invoq.invoices.create(
  amount: "129",
  description: "SaaS boilerplate",
  reference_id: "order_1234",
  return_url: "https://merchant.example/thanks"
)

invoice_id = invoice.fetch("id")
checkout_url = "https://pay.invoq.money/#{invoice_id}"
```

Notas:

- Define el monto en el servidor. No confíes en montos que manda el cliente.
- `amount` es una cadena decimal en USD de `"0.01"` a `"1000000.00"` con hasta 2 decimales, como `"129"` o `"129.99"`. La moneda siempre es USD, y el modo de prueba o real viene de la clave — ninguno de los dos es un campo de la solicitud.
- Usa un `reference_id` estable y no vacío para vincular los webhooks `invoice.paid` con tu pedido. Si vuelves a crear con el mismo `reference_id` y los mismos términos de factura, recibes la factura existente; con términos distintos, falla con un error de API `409 reference_id_conflict`.
- Si procesas el pedido por ID de factura en lugar de `reference_id`, guarda `invoice_id` junto con tu pedido al crear la factura.
- Omite `return_url` para usar la URL de retorno predeterminada del proyecto. Pasa `nil` para enviar `null` en JSON y crear la factura sin URL de retorno. En los reintentos por `reference_id`, pasa `return_url` de forma explícita cuando necesites garantizar un valor específico.
- `description` y `reference_id` deben ser cadenas cuando están presentes.

Obtén una factura:

```ruby
invoice = invoq.invoices.get("inv_123")
```

`invoices.get` devuelve la forma de factura pública usada por la página de checkout hospedada: la forma de la respuesta de creación más `amount_paid`, `project` y `transfers`, y sin `reference_id`. Usa la respuesta de creación o el webhook `invoice.paid` cuando necesites tu `reference_id` de comercio.

Crea un pago de prueba:

```ruby
paid_invoice = invoq.invoices.create_test_payment(
  "inv_123",
  amount: "129",
  reference_id: "test_payment_001"
)
```

Las facturas de prueba no pueden recibir fondos reales. En su lugar, simula los pagos desde tu servidor.

`create_test_payment` solo funciona con facturas creadas con una clave `sk_test_`. Se permiten montos parciales, que producen `partially_paid`; cuando los pagos alcanzan el monto de la factura, invoq envía un webhook `invoice.paid` firmado a tu URL de webhook de prueba.

`reference_id` es opcional para los pagos de prueba. Omítelo cuando no esté definido; no pases `nil`.

Para recibir webhooks en tu máquina, expón tu servidor local con un túnel HTTPS como ngrok o cloudflared y guarda la URL del túnel como tu URL de webhook de prueba en el panel.

Cada método de factura devuelve el objeto `data` de la respuesta directamente como un hash de Ruby.

## Página de pago alojada

Cada factura también tiene una página de pago alojada en:

```txt
https://pay.invoq.money/<invoice id>
```

Comparte el enlace o redirige ahí cuando una ventana de pago integrada en la página no encaje.

## Entradas y respuestas

El SDK verifica que los valores de `amount` y los argumentos `invoice_id` sean cadenas no vacías antes de enviar las solicitudes. La API de invoq valida el formato y el rango del monto.

Deja fuera del hash de la solicitud los campos opcionales sin definir. Cuando incluyas `description` o `reference_id`, pasa una cadena. `return_url` puede ser una cadena o `nil`. Cualquier otra clave del hash se descarta en lugar de enviarse, porque la API rechaza claves de cuerpo desconocidas.

Los montos en las respuestas se normalizan a 4 decimales: crea con `"129"` y la factura devuelve `amount: "129.0000"`. Compara montos numéricamente, no como cadenas. `amount_due` se deriva como `max(amount - amount_paid, 0)` y usa la misma escala de 18 decimales que `amount_paid`; `amount_overpaid` es su reflejo, `max(amount_paid - amount, 0)`, así que nunca restas dinero por tu cuenta.

Dos campos de estado. `status` es el contable — `unpaid`, `partially_paid`, `paid`, `settling`, `settled`, `review_required` — y los tres valores equivalentes a pagada solo se diferencian en qué tan lejos llegaron los fondos hacia tu billetera. `checkout_status` es el que ve quien paga — `open`, `confirming`, `expired`, `paid`, `unavailable` — y nunca autoriza procesar el pedido. `payment_revision` es un entero no negativo que sube cada vez que cambia el conjunto de pagos confirmados, así descartas una instantánea más vieja que la que ya tienes.

`payment_options` contiene las instrucciones de pago, fijadas al crear la factura y `[]` en modo de prueba. Las entradas se discriminan por `status` y luego por `collection_method`: solo `"ready"` es pagable, `"evm_deposit"` trae `deposit_address` y `suggested_amount`, `"direct_exact"` trae `recipient_address` y un `exact_amount` que el comprador debe enviar hasta el último dígito. `transfers` es el registro confirmado de recepciones — `transaction_id`, `event_index`, `amount`, `explorer_transaction_url` — y queda en `[]` hasta que se confirme un pago. Referencia completa: [documentación de la API REST](https://github.com/invoqmoney/api).

Identifica una opción de pago por `chain_namespace`, `chain_reference` y `token_address`, nunca por su posición en el arreglo. `monitoring_ends_at` es el fin de la ventana de pago y es `nil` en las facturas de prueba.

## Webhooks

Pasa el cuerpo sin procesar de la solicitud a `verify_webhook`. No proceses el JSON ni lo vuelvas a codificar antes de la verificación.

Este ejemplo con Rack devuelve `[status, headers, body]`. En Rails, usa `request.raw_post` y `request.get_header("HTTP_INVOQ_SIGNATURE")`; en Sinatra u otro framework de Ruby, usa el cuerpo sin procesar de la solicitud del framework y el encabezado `invoq-signature` o `HTTP_INVOQ_SIGNATURE` que exponga.

```ruby
def handle_invoq_webhook(env)
  raw_body = env.fetch("rack.input").read

  begin
    event = Invoq.verify_webhook(
      raw_body,
      { "invoq-signature" => env["HTTP_INVOQ_SIGNATURE"] },
      ENV.fetch("INVOQ_WEBHOOK_SECRET")
    )
  rescue Invoq::SignatureVerificationError
    return [
      400,
      { "content-type" => "application/json" },
      ['{"error":"invalid signature"}']
    ]
  end

  if Invoq.invoice_paid?(event)
    invoice = event.fetch("data").fetch("invoice")
    fulfillment_key = invoice["reference_id"] || invoice.fetch("id")

    # Procesa el pedido de fulfillment_key de forma idempotente.
  elsif Invoq.invoice_payment_reversed?(event)
    invoice = event.fetch("data").fetch("invoice")
    fulfillment_key = invoice["reference_id"] || invoice.fetch("id")

    # Retén o revierte el pedido de fulfillment_key.
  end

  [
    200,
    { "content-type" => "application/json" },
    ['{"received":true}']
  ]
end
```

Usa los webhooks `invoice.paid` para procesar los pedidos en tu servidor. Los resultados del checkout en el navegador solo sirven para actualizar la experiencia del cliente; no proceses pedidos a partir de resultados del navegador.

Cuando `Invoq.invoice_paid?(event)` es true, la factura está lista para procesarse automáticamente; usa el `reference_id` de la factura o un `id` de factura guardado para encontrar y procesar tu pedido. Una factura `review_required` aún no emite un webhook `invoice.paid`. Si el checkout informa `review_required`, muestra un estado pendiente de revisión y espera un webhook `invoice.paid` posterior después de que se apruebe la revisión.

invoq también envía `invoice.payment_reversed` cuando una factura ya pagada vuelve a quedar por debajo de su monto — por ejemplo, si una reorganización de la cadena descarta una transferencia confirmada. Detéctalo con `Invoq.invoice_payment_reversed?(event)` y retén o revierte el procesamiento según tu propia política.

Importante:

- Pasa la cadena exacta del cuerpo sin procesar de la solicitud que recibe tu framework de Ruby.
- Pasa el encabezado `invoq-signature`.
- `verify_webhook` no requiere `Invoq.new(...)` ni tu clave secreta de la API de invoq.
- Usa el secreto de tu webhook (`whsec_...`), no `INVOQ_SECRET_KEY`.
- Haz que el procesamiento sea idempotente. Las entregas de webhook reintentadas pueden enviar el mismo evento más de una vez.
- Responde con un 2xx rápido. Cualquier otro estado cuenta como entrega fallida y se reintenta, incluidos los redireccionamientos y los `4xx`, así que una ventana de despliegue o una ruta mal dirigida por un rato se reintenta en lugar de descartarse. Los reintentos esperan 1 minuto, 5 minutos, 30 minutos y luego 2 horas, hasta 5 intentos en total.
- Las entregas pueden llegar desordenadas. Quédate con la instantánea que tenga el `payment_revision` más alto.

`Invoq.invoice_paid?` acepta eventos `invoice.paid` procesables cuyo estado de factura es `paid`, `settling` o `settled`; rechaza `review_required`. `Invoq.invoice_payment_reversed?` acepta eventos `invoice.payment_reversed` sin revisar el estado en absoluto: una reversión que descartes deja un pedido procesado sobre un pago que ya no existe. Un tipo de evento que esta versión del SDK todavía no modela igual se verifica y se devuelve tal cual.

Las fallas de verificación de webhook lanzan `Invoq::SignatureVerificationError`. El SDK permite una tolerancia de 5 minutos en el timestamp. El encabezado de firma es:

```txt
invoq-signature: t=<unix seconds>,v1=<hex HMAC-SHA256 of "<t>.<raw body>">
```

## Errores

```ruby
begin
  invoq.invoices.create(amount: "0.001")
rescue Invoq::ApiError => error
  warn error.status
  warn error.code
  warn error.fields
  warn error.meta
  warn error.payload
rescue Invoq::Error
  raise
end
```

Las respuestas de API no 2xx lanzan `Invoq::ApiError` con `status`, `code`, `fields`, `meta` y el `payload` crudo.

Las fallas de conexión, los tiempos de espera agotados, las entradas inválidas y las fallas al procesar la respuesta lanzan `Invoq::Error`. Una creación de factura que expiró es segura de reintentar con el mismo `reference_id`.

Las fallas de verificación de webhook lanzan `Invoq::SignatureVerificationError` con uno de estos códigos:

```txt
missing_signature
invalid_signature_header
timestamp_outside_tolerance
signature_mismatch
invalid_payload
```

## Desarrollo

```sh
bundle exec rake test
```

## Licencia

Distribuido bajo la licencia MIT.
