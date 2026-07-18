# invoq Ruby SDK'sı

[English](../README.md) · [Bahasa Indonesia](./README.id.md) · [Español](./README.es-419.md) · [Français](./README.fr.md) · [Português](./README.pt-BR.md) · [Tiếng Việt](./README.vi.md) · **Türkçe** · [ไทย](./README.th.md) · [简体中文](./README.zh-Hans.md) · [繁體中文](./README.zh-Hant.md)

> Bu belge İngilizce README'nin çevirisidir; bir fark olursa [İngilizce sürüm](../README.md) esas alınır.

Ruby sunucu kodunuzdan invoq ile stablecoin ödemeleri kabul edin. Bu SDK, invoq sunucu API'lerini sarmalar ve imzalı webhook'ları doğrular.

Bu gem'i yalnızca sunucunuzda kullanın. Gizli anahtarları işler ve tarayıcı koduna dahil edilmemelidir.

## Sunucu SDK'ları

Bu dillerin herhangi biriyle arka ucunuzdan fatura oluşturun ve webhook'ları doğrulayın — aynı REST API, aynı webhook imzası. Bu repo, Ruby SDK'sıdır.

| Dil | Repo |
| --- | --- |
| Node.js | [github.com/invoqmoney/sdk-js](https://github.com/invoqmoney/sdk-js) (`@invoq/server`) |
| Python | [github.com/invoqmoney/sdk-python](https://github.com/invoqmoney/sdk-python) |
| PHP | [github.com/invoqmoney/sdk-php](https://github.com/invoqmoney/sdk-php) |
| Go | [github.com/invoqmoney/sdk-go](https://github.com/invoqmoney/sdk-go) |
| Rust | [github.com/invoqmoney/sdk-rust](https://github.com/invoqmoney/sdk-rust) |
| Ruby | **bu repo** |

Tarayıcı tarafı her arka uç için aynıdır: **`@invoq/checkout`** (JavaScript, [github.com/invoqmoney/sdk-js](https://github.com/invoqmoney/sdk-js) içinde) her ön uç için sayfa içi ödeme penceresini açar.

## Kurulum

Gem'i kurun:

```sh
gem install invoq
```

Ya da bir Gemfile'a ekleyin:

```ruby
gem "invoq"
```

Ruby 2.6 veya üstünü gerektirir.

## Anahtarlarınızı alın

1. [invoq paneline](https://app.invoq.money) giriş yapın ve bir proje oluşturun.
2. **API keys** sayfasında bir gizli anahtar oluşturun. Test anahtarları `sk_test_` ile, canlı anahtarlar `sk_live_` ile başlar. Anahtarın modu, faturaların test mi canlı mı olacağını belirler.
3. Projenizin **webhooks** ayarlarında webhook URL'nizi kaydedin. O modun webhook sırrı (`whsec_...`) yalnızca bir kez, webhook'u ilk etkinleştirdiğinizde gösterilir — hemen saklayın. Webhook URL'leri herkese açık HTTPS URL'leri olmalı.

İkisini de sunucu ortamınıza ekleyin:

```sh
INVOQ_SECRET_KEY=sk_test_...
INVOQ_WEBHOOK_SECRET=whsec_...
```

Test anahtarlarıyla başlayın. Canlı ortama geçerken canlı anahtara ve canlı webhook sırrına geçin.

## İstemci oluşturma

```ruby
require "invoq"

invoq = Invoq.new(ENV.fetch("INVOQ_SECRET_KEY"))
```

Varsayılan canlı ortam API origin'i:

```txt
https://api.invoq.money
```

Geliştirme sırasında API origin'ini ve istek zaman aşımını değiştirin:

```ruby
invoq = Invoq.new(
  ENV.fetch("INVOQ_SECRET_KEY"),
  api_origin: "http://localhost:8787",
  timeout_ms: 10_000
)
```

`api_origin`, yol, sorgu, hash, kullanıcı adı veya parola içermeyen mutlak bir `http` ya da `https` origin'i olmalı. SDK, sonuna `/v1/...` kaynak yollarını ekler.

İstekler varsayılan olarak 10 saniyede zaman aşımına uğrar. Zaman aşımını değiştirmek için `timeout_ms` değerini geçin. `timeout_ms`, milisaniye cinsinden pozitif bir tam sayı olmalı.

## Faturalar

Bir fatura oluşturun:

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

Notlar:

- Tutarı sunucu tarafında belirleyin. İstemciden gelen tutarlara güvenmeyin.
- `amount`, `"0.01"` ile `"1000000.00"` arasında, en fazla 2 ondalık basamaklı, USD cinsinden ondalık bir dizedir — örneğin `"129"` veya `"129.99"`.
- `currency` isteğe bağlıdır ve varsayılan olarak `"USD"` kullanılır.
- `invoice.paid` webhook'larını siparişinize geri bağlamak için sabit ve boş olmayan bir `reference_id` kullanın. Aynı `reference_id` ve aynı fatura koşullarıyla tekrar oluşturmak mevcut faturayı döndürür; farklı koşullar ise `409 reference_id_conflict` API hatasıyla başarısız olur.
- Siparişleri `reference_id` yerine fatura ID'sine göre işliyorsanız, faturayı oluşturduğunuzda `invoice_id` değerini siparişinizle birlikte saklayın.
- Projenin varsayılan dönüş URL'sini kullanmak için `return_url`'yi belirtmeyin. JSON `null` göndermek ve faturayı dönüş URL'si olmadan oluşturmak için `nil` geçin. `reference_id` ile yeniden denemelerde, belirli bir değeri garanti etmeniz gerektiğinde `return_url`'yi açıkça geçin.
- `description` ve `reference_id`, belirtildiğinde dize olmalı.

Bir faturayı getirin:

```ruby
invoice = invoq.invoices.get("inv_123")
```

`invoices.get`, barındırılan ödeme sayfasının kullandığı herkese açık fatura şeklini döndürür. `amount_paid`, `amount_due`, `amount_overpaid`, `payment_status`, `project`, `deposit_address`, `monitoring_ends_at`, `monitoring_status`, `transfers` ve `direct_onchain_rails` gibi alanları içerir, ancak `reference_id` içermez. Merchant `reference_id` değeriniz gerektiğinde oluşturma yanıtını veya `invoice.paid` webhook'unu kullanın.

Test ödemesi oluşturun:

```ruby
paid_invoice = invoq.invoices.create_test_payment(
  "inv_123",
  amount: "129",
  reference_id: "test_payment_001"
)
```

Test faturaları gerçek para alamaz. Bunun yerine ödemeleri sunucunuzdan simüle edin.

`create_test_payment` yalnızca `sk_test_` anahtarıyla oluşturulmuş faturalarda çalışır. Kısmi tutarlara izin verilir ve sonuç `partially_paid` olur; ödemeler fatura tutarına ulaştığında invoq, test webhook URL'nize imzalı bir `invoice.paid` webhook'u gönderir.

Test ödemeleri için `reference_id` isteğe bağlıdır. Ayarlanmamışsa belirtmeyin; `nil` geçmeyin.

Webhook'ları kendi makinenizde almak için yerel sunucunuzu ngrok veya cloudflared gibi bir HTTPS tüneliyle dışa açın ve tünel URL'sini panelde test webhook URL'niz olarak kaydedin. Panel, bağlantıyı denetlemek için imzalı bir `webhook.ping` de gönderebilir.

Her fatura metodu, yanıttaki `data` nesnesini doğrudan bir Ruby hash'i olarak döndürür.

## Barındırılan ödeme sayfası

Her faturanın ayrıca şu adreste barındırılan bir ödeme sayfası vardır:

```txt
https://pay.invoq.money/<invoice id>
```

Sayfa içi ödeme penceresi uygun olmadığında bağlantıyı paylaşın ya da oraya yönlendirin.

## Girdiler ve yanıtlar

SDK, istekleri göndermeden önce `amount` değerlerinin ve `invoice_id` argümanlarının boş olmayan dizeler olduğunu denetler. invoq API'si tutar biçimini, aralığını ve para birimini doğrular.

Ayarlanmamış isteğe bağlı alanları istek hash'inin dışında bırakın. `description` veya `reference_id` eklediğinizde bir dize geçin. `return_url` bir dize ya da `nil` olabilir.

Yanıtlardaki tutarlar 4 ondalık basamağa normalize edilir: `"129"` ile oluşturun, fatura `amount: "129.0000"` döndürür. Tutarları dize olarak değil, sayısal olarak karşılaştırın. `amount_due`, `max(amount - amount_paid, 0)` olarak türetilir ve `amount_paid` ile aynı 18 ondalık basamak ölçeğini kullanır; `amount_overpaid` ise onun aynasıdır, `max(amount_paid - amount, 0)`, yani parayı kendiniz çıkarmanız hiç gerekmez. `monitoring_status`, `"active"` ya da `"ended"` olur — `"ended"` olduğunda yatırma adresi artık izlenmez — ve `transfers`, onaylanmış zincir üstü tahsilat kaydıdır (her girdide `tx_hash`, `amount` ve `explorer_tx_url` bulunur). İkisi de test faturaları için `nil` / `[]` olur.

## Webhook'lar

Ham istek gövdesini `verify_webhook`'a geçin. Doğrulamadan önce JSON'u ayrıştırıp yeniden kodlamayın.

Bu Rack örneği `[status, headers, body]` döndürür. Rails'te `request.raw_post` ve `request.get_header("HTTP_INVOQ_SIGNATURE")` kullanın; Sinatra'da veya başka bir Ruby framework'ünde, framework'ün ham istek gövdesini ve sunduğu `invoq-signature` ya da `HTTP_INVOQ_SIGNATURE` başlığını kullanın.

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

    # fulfillment_key için siparişi idempotent şekilde işleyin.
  end

  [
    200,
    { "content-type" => "application/json" },
    ['{"received":true}']
  ]
end
```

Siparişleri sunucunuzda işlemek için `invoice.paid` webhook'larını kullanın. Tarayıcı ödeme sonuçları yalnızca müşteri deneyimini güncellemek içindir; siparişleri tarayıcı sonuçlarına göre işlemeyin.

`Invoq.invoice_paid?(event)` true olduğunda fatura otomatik işlenmeye hazırdır; siparişinizi bulup işlemek için faturanın `reference_id` değerini ya da sakladığınız fatura `id`'sini kullanın. `review_required` durumundaki bir fatura henüz `invoice.paid` webhook'u göndermez. Checkout `review_required` bildirirse inceleme bekleyen bir durum gösterin ve inceleme onaylandıktan sonra gelecek `invoice.paid` webhook'unu bekleyin.

Önemli:

- Ruby framework'ünüzün aldığı tam ham istek gövdesi dizesini geçin.
- `invoq-signature` başlığını geçin.
- `verify_webhook`, `Invoq.new(...)` çağrısını ya da invoq API gizli anahtarınızı gerektirmez.
- `INVOQ_SECRET_KEY`'i değil, webhook sırrınızı (`whsec_...`) kullanın.
- Sipariş işlemeyi idempotent yapın. Yeniden denenen webhook teslimatları aynı olayı birden fazla kez gönderebilir.
- Hızlıca 2xx yanıtı dönün. Başka herhangi bir durum kodu başarısız teslimat sayılır. Zaman aşımları, `429` ve `5xx` yanıtları gibi geçici hatalar yeniden denenir; diğer `4xx` yanıtları denenmez.

`Invoq.invoice_paid?`, fatura durumu `paid`, `settling` veya `settled` olan işlenebilir `invoice.paid` olaylarını kabul eder; `review_required` durumunu reddeder.

Webhook doğrulama hataları `Invoq::SignatureVerificationError` fırlatır. SDK, 5 dakikalık bir zaman damgası toleransına izin verir. İmza başlığı şudur:

```txt
invoq-signature: t=<unix seconds>,v1=<hex HMAC-SHA256 of "<t>.<raw body>">
```

## Hatalar

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

2xx olmayan API yanıtları, `status`, `code`, `fields`, `meta` ve ham `payload` içeren bir `Invoq::ApiError` fırlatır.

Bağlantı hataları, zaman aşımları, geçersiz girdi ve yanıt ayrıştırma hataları `Invoq::Error` fırlatır. Zaman aşımına uğrayan fatura oluşturma, aynı `reference_id` ile güvenle yeniden denenebilir.

Webhook doğrulama hataları, şu kodlardan biriyle `Invoq::SignatureVerificationError` fırlatır:

```txt
missing_signature
invalid_signature_header
timestamp_outside_tolerance
signature_mismatch
invalid_payload
```

## Geliştirme

```sh
bundle exec rake test
```

## Lisans

MIT lisansı altında lisanslanmıştır.
