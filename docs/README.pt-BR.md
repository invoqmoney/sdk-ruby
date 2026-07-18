# SDK Ruby da invoq

[English](../README.md) · [Bahasa Indonesia](./README.id.md) · [Español](./README.es-419.md) · [Français](./README.fr.md) · **Português** · [Tiếng Việt](./README.vi.md) · [Türkçe](./README.tr.md) · [ไทย](./README.th.md) · [简体中文](./README.zh-Hans.md) · [繁體中文](./README.zh-Hant.md)

> Este documento é uma tradução do README em inglês; se algo divergir, vale a [versão em inglês](../README.md).

Aceite pagamentos em stablecoin com a invoq a partir de código de servidor em Ruby. Este SDK encapsula as APIs de servidor da invoq e verifica webhooks assinados.

Use esta gem apenas no seu servidor. Ela lida com chaves secretas e não deve ser empacotada no código do navegador.

## SDKs de servidor

Crie faturas e verifique webhooks a partir do seu backend em qualquer uma destas linguagens — mesma REST API, mesma assinatura de webhook. Este repositório é o SDK de Ruby.

| Linguagem | Repositório |
| --- | --- |
| Node.js | [github.com/invoqmoney/sdk-js](https://github.com/invoqmoney/sdk-js) (`@invoq/server`) |
| Python | [github.com/invoqmoney/sdk-python](https://github.com/invoqmoney/sdk-python) |
| PHP | [github.com/invoqmoney/sdk-php](https://github.com/invoqmoney/sdk-php) |
| Go | [github.com/invoqmoney/sdk-go](https://github.com/invoqmoney/sdk-go) |
| Rust | [github.com/invoqmoney/sdk-rust](https://github.com/invoqmoney/sdk-rust) |
| Ruby | **este repositório** |

O lado do navegador é o mesmo para qualquer backend: **`@invoq/checkout`** (JavaScript, em [github.com/invoqmoney/sdk-js](https://github.com/invoqmoney/sdk-js)) abre a janela de checkout dentro da página para qualquer frontend.

## Instalação

Instale a gem:

```sh
gem install invoq
```

Ou adicione a um Gemfile:

```ruby
gem "invoq"
```

Requer Ruby 2.6 ou mais novo.

## Pegue suas chaves

1. Entre no [painel da invoq](https://app.invoq.money) e crie um projeto.
2. Na página **API keys**, crie uma chave secreta. Chaves de teste começam com
   `sk_test_`, chaves de produção com `sk_live_`. O modo da chave define se as
   faturas são de teste ou de produção.
3. Nas configurações de **webhooks** do projeto, salve a URL do seu webhook. O
   segredo do webhook (`whsec_...`) daquele modo aparece uma única vez, quando
   você ativa o webhook pela primeira vez. Guarde na hora. A URL do webhook
   precisa ser HTTPS e pública.

Adicione os dois ao ambiente do seu servidor:

```sh
INVOQ_SECRET_KEY=sk_test_...
INVOQ_WEBHOOK_SECRET=whsec_...
```

Comece com as chaves de teste. Troque para a chave de produção e o segredo de
webhook de produção quando for para produção.

## Crie um cliente

```ruby
require "invoq"

invoq = Invoq.new(ENV.fetch("INVOQ_SECRET_KEY"))
```

Origin da API padrão em produção:

```txt
https://api.invoq.money
```

Sobrescreva o origin da API e o timeout da requisição durante o desenvolvimento:

```ruby
invoq = Invoq.new(
  ENV.fetch("INVOQ_SECRET_KEY"),
  api_origin: "http://localhost:8787",
  timeout_ms: 10_000
)
```

`api_origin` precisa ser um origin `http` ou `https` absoluto, sem caminho,
query, hash, usuário ou senha. O SDK anexa os caminhos de recurso `/v1/...`.

As requisições expiram em 10 segundos por padrão. Passe `timeout_ms` para mudar
o timeout. `timeout_ms` precisa ser um inteiro positivo em milissegundos.

## Faturas

Crie uma fatura:

```ruby
invoice = invoq.invoices.create(
  amount: "129",
  currency: "USD",
  description: "SaaS boilerplate",
  reference_id: "order_1234",
  return_url: "https://merchant.example/thanks"
)

invoice_id = invoice.fetch("id")
checkout_url = "https://pay.invoq.money/#{invoice_id}"
```

Notas:

- Use um valor definido no servidor. Não confie em valores vindos do cliente.
- `amount` é uma string decimal em USD de `"0.01"` a `"1000000.00"`, com até 2
  casas decimais, como `"129"` ou `"129.99"`.
- `currency` é opcional e assume `"USD"` por padrão.
- Use um `reference_id` estável e não vazio para ligar os webhooks
  `invoice.paid` ao seu pedido. Criar de novo com o mesmo `reference_id` e os
  mesmos termos da fatura retorna a fatura existente; termos diferentes falham
  com o erro de API `409 reference_id_conflict`.
- Se você processa pelo ID da fatura em vez do `reference_id`, guarde o
  `invoice_id` junto do seu pedido ao criar a fatura.
- Omita `return_url` para usar a URL de retorno padrão do projeto. Passe `nil`
  para enviar `null` em JSON e criar a fatura sem URL de retorno. Em novas
  tentativas com o mesmo `reference_id`, passe `return_url` explicitamente
  quando precisar garantir um valor específico.
- `description` e `reference_id` precisam ser strings quando presentes.

Busque uma fatura:

```ruby
invoice = invoq.invoices.get("inv_123")
```

`invoices.get` retorna o formato de fatura pública usado pelo checkout
hospedado. Ele inclui campos como `amount_paid`, `amount_due`,
`amount_overpaid`, `payment_status`, `project`, `deposit_address`,
`monitoring_ends_at`, `monitoring_status`, `transfers` e `direct_onchain_rails`,
mas não inclui `reference_id`. Use a resposta de criação ou o webhook
`invoice.paid` quando precisar do seu `reference_id` de comerciante.

Crie um pagamento de teste:

```ruby
paid_invoice = invoq.invoices.create_test_payment(
  "inv_123",
  amount: "129",
  reference_id: "test_payment_001"
)
```

Faturas de teste não recebem dinheiro de verdade. Simule os pagamentos a partir
do seu servidor.

`create_test_payment` só funciona em faturas criadas com uma chave `sk_test_`.
Valores parciais são permitidos e produzem `partially_paid`; quando os
pagamentos atingem o valor da fatura, a invoq envia um webhook `invoice.paid`
assinado para a sua URL de webhook de teste.

`reference_id` é opcional para pagamentos de teste. Omita quando não houver
valor; não passe `nil`.

Para receber webhooks na sua máquina, exponha o servidor local com um túnel
HTTPS como ngrok ou cloudflared e salve a URL do túnel como URL de webhook de
teste no painel. O painel também consegue enviar um `webhook.ping` assinado para
checar a conectividade.

Cada método de fatura retorna o objeto `data` da resposta diretamente como um
hash Ruby.

## Página de checkout hospedada

Toda fatura também tem uma página de checkout hospedada em:

```txt
https://pay.invoq.money/<invoice id>
```

Compartilhe o link ou redirecione para ele quando a janela de checkout dentro da
página não for adequada.

## Entradas e respostas

O SDK verifica se os valores de `amount` e os argumentos `invoice_id` são
strings não vazias antes de enviar as requisições. A API da invoq valida o
formato, o intervalo e a moeda do valor.

Deixe os campos opcionais não usados fora do hash da requisição. Quando incluir
`description` ou `reference_id`, passe uma string. `return_url` pode ser uma
string ou `nil`.

Os valores nas respostas são normalizados para 4 casas decimais: crie com
`"129"` e a fatura devolve `amount: "129.0000"`. Compare valores numericamente,
não como texto. `amount_due` é derivado como `max(amount - amount_paid, 0)` e
usa a mesma escala de 18 casas decimais de `amount_paid`; `amount_overpaid` é o
espelho dele, `max(amount_paid - amount, 0)`, então você nunca precisa subtrair
dinheiro por conta própria. `monitoring_status` é `"active"` ou `"ended"` — assim
que fica `"ended"`, o endereço de depósito deixa de ser monitorado — e
`transfers` é o registro confirmado de recebimentos on-chain (cada entrada tem
`tx_hash`, `amount` e `explorer_tx_url`). Ambos são `nil` / `[]` em faturas de
teste.

## Webhooks

Passe o corpo bruto da requisição para `verify_webhook`. Não interprete o JSON e
o codifique novamente antes da verificação.

Este exemplo em Rack retorna `[status, headers, body]`. No Rails, use
`request.raw_post` e `request.get_header("HTTP_INVOQ_SIGNATURE")`; no Sinatra ou
em outro framework Ruby, use o corpo bruto da requisição do framework e o
cabeçalho `invoq-signature` ou `HTTP_INVOQ_SIGNATURE` exposto por ele.

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

    # Processe o pedido de fulfillment_key de forma idempotente.
  end

  [
    200,
    { "content-type" => "application/json" },
    ['{"received":true}']
  ]
end
```

Use os webhooks `invoice.paid` para processar os pedidos no seu servidor. Os
resultados do checkout no navegador servem apenas para atualizar a experiência
do cliente; não processe pedidos a partir de resultados do navegador.

Quando `Invoq.invoice_paid?(event)` for true, a fatura está pronta para
processamento automático; use o `reference_id` da fatura ou um `id` de fatura
armazenado para achar e processar o pedido. Uma fatura `review_required` ainda
não emite um webhook `invoice.paid`. Se o checkout retornar `review_required`,
mostre um estado de revisão pendente e aguarde um webhook `invoice.paid`
posterior depois que a revisão for aprovada.

Importante:

- Passe a string exata do corpo bruto da requisição recebida pelo seu framework
  Ruby.
- Passe o cabeçalho `invoq-signature`.
- `verify_webhook` não exige `Invoq.new(...)` nem a sua chave secreta de API da
  invoq.
- Use o segredo do webhook (`whsec_...`), não o `INVOQ_SECRET_KEY`.
- Faça o processamento de forma idempotente. Entregas reenviadas de webhook
  podem enviar o mesmo evento mais de uma vez.
- Responda com um 2xx rapidamente. Qualquer outro status conta como uma entrega
  falhada. Falhas transitórias como timeouts, `429` e respostas `5xx` são
  reenviadas; outras respostas `4xx` não.

`Invoq.invoice_paid?` aceita eventos `invoice.paid` processáveis cujo status da
fatura seja `paid`, `settling` ou `settled`; ele rejeita `review_required`.

Falhas de verificação de webhook lançam `Invoq::SignatureVerificationError`. O
SDK permite uma tolerância de 5 minutos no timestamp. O cabeçalho de assinatura
é:

```txt
invoq-signature: t=<unix seconds>,v1=<hex HMAC-SHA256 of "<t>.<raw body>">
```

## Erros

```ruby
begin
  invoq.invoices.create(amount: "0.001", currency: "USD")
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

Respostas de API não 2xx lançam `Invoq::ApiError` com `status`, `code`,
`fields`, `meta` e o `payload` bruto.

Falhas de conexão, timeouts, entrada inválida e falhas ao interpretar a resposta
lançam `Invoq::Error`. A criação de fatura que expirou é segura de repetir com o
mesmo `reference_id`.

Falhas de verificação de webhook lançam `Invoq::SignatureVerificationError` com
um destes códigos:

```txt
missing_signature
invalid_signature_header
timestamp_outside_tolerance
signature_mismatch
invalid_payload
```

## Desenvolvimento

```sh
bundle exec rake test
```

## Licença

Licenciado sob a licença MIT.
