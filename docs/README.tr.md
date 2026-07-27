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
4. Canlıya geçmeden önce **Receiving wallet** ayarınızı yapın. Test faturaları buna ihtiyaç duymaz; paranın gideceği yer olmayan canlı bir fatura `409 no_payment_options_available` ile başarısız olur.

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
  description: "SaaS boilerplate",
  reference_id: "order_1234",
  return_url: "https://merchant.example/thanks"
)

invoice_id = invoice.fetch("id")
checkout_url = "https://pay.invoq.money/#{invoice_id}"
```

Notlar:

- Tutarı sunucu tarafında belirleyin. İstemciden gelen tutarlara güvenmeyin.
- `amount`, `"0.01"` ile `"1000000.00"` arasında, en fazla 2 ondalık basamaklı, USD cinsinden ondalık bir dizedir — örneğin `"129"` veya `"129.99"`. Para birimi her zaman USD'dir ve test mi live mı olduğu anahtardan gelir — ikisi de istek alanı değildir.
- `invoice.paid` webhook'larını siparişinize geri bağlamak için sabit ve boş olmayan bir `reference_id` kullanın. Aynı `reference_id` ve aynı fatura koşullarıyla tekrar oluşturmak mevcut faturayı döndürür; farklı koşullar ise `409 reference_id_conflict` API hatasıyla başarısız olur.
- Siparişleri `reference_id` yerine fatura ID'sine göre işliyorsanız, faturayı oluşturduğunuzda `invoice_id` değerini siparişinizle birlikte saklayın.
- Projenin varsayılan dönüş URL'sini kullanmak için `return_url`'yi belirtmeyin. JSON `null` göndermek ve faturayı dönüş URL'si olmadan oluşturmak için `nil` geçin. `reference_id` ile yeniden denemelerde, belirli bir değeri garanti etmeniz gerektiğinde `return_url`'yi açıkça geçin.
- `description` ve `reference_id`, belirtildiğinde dize olmalı.

Bir faturayı getirin:

```ruby
invoice = invoq.invoices.get("inv_123")
```

`invoices.get` barındırılan checkout sayfasının kullandığı herkese açık fatura şeklini döndürür: oluşturma yanıtının şekli, artı `amount_paid`, `project` ve `transfers`, eksi `reference_id`. Merchant `reference_id` değeriniz gerektiğinde oluşturma yanıtını veya `invoice.paid` webhook'unu kullanın.

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

Webhook'ları kendi makinenizde almak için yerel sunucunuzu ngrok veya cloudflared gibi bir HTTPS tüneliyle dışa açın ve tünel URL'sini panelde test webhook URL'niz olarak kaydedin.

Her fatura metodu, yanıttaki `data` nesnesini doğrudan bir Ruby hash'i olarak döndürür.

## Barındırılan ödeme sayfası

Her faturanın ayrıca şu adreste barındırılan bir ödeme sayfası vardır:

```txt
https://pay.invoq.money/<invoice id>
```

Sayfa içi ödeme penceresi uygun olmadığında bağlantıyı paylaşın ya da oraya yönlendirin.

## Girdiler ve yanıtlar

SDK, istekleri göndermeden önce `amount` değerlerinin ve `invoice_id` argümanlarının boş olmayan dizeler olduğunu denetler. invoq API'si tutar biçimini ve aralığını doğrular.

Ayarlanmamış isteğe bağlı alanları istek hash'inin dışında bırakın. `description` veya `reference_id` eklediğinizde bir dize geçin. `return_url` bir dize ya da `nil` olabilir. Hash'teki başka her anahtar gönderilmez, atılır; çünkü API bilinmeyen gövde anahtarlarını reddeder.

Yanıtlardaki tutarlar 4 ondalık basamağa normalize edilir: `"129"` ile oluşturun, fatura `amount: "129.0000"` döndürür. Tutarları dize olarak değil, sayısal olarak karşılaştırın. `amount_due`, `max(amount - amount_paid, 0)` olarak türetilir ve `amount_paid` ile aynı 18 ondalık basamak ölçeğini kullanır; `amount_overpaid` ise onun aynasıdır, `max(amount_paid - amount, 0)`, yani parayı kendiniz çıkarmanız hiç gerekmez.

İki durum alanı. `status` muhasebe durumudur — `unpaid`, `partially_paid`, `paid`, `settling`, `settled`, `review_required` — ve ödeme tamamlanmış sayılan üç değer yalnızca paranın cüzdanınıza ne kadar yaklaştığıyla ayrılır. `checkout_status` ödeyenin gördüğüdür — `open`, `confirming`, `expired`, `paid`, `unavailable` — ve siparişi işlemek için asla yetki vermez. `payment_revision`, negatif olmayan bir tam sayıdır ve onaylanmış ödeme kümesi her değiştiğinde artar; böylece elinizdekinden eski bir anlık görüntüyü eleyebilirsiniz.

`payment_options` ödeme talimatlarını taşır; oluşturulurken sabitlenir ve test modunda `[]` olur. Girdiler önce `status`, sonra `collection_method` ile ayrışır: yalnızca `"ready"` ödenebilir, `"evm_deposit"` `deposit_address` ve `suggested_amount` taşır, `"direct_exact"` `recipient_address` ile alıcının son hanesine kadar göndermesi gereken `exact_amount` değerini taşır. `transfers` onaylanmış tahsilat kaydıdır — `transaction_id`, `event_index`, `amount`, `explorer_transaction_url` — ve bir ödeme onaylanana kadar `[]` kalır. Tüm alanlar: [REST API belgeleri](https://github.com/invoqmoney/api).

Bir ödeme seçeneğini `chain_namespace`, `chain_reference` ve `token_address` ile tanıyın; dizideki sırasıyla asla. `monitoring_ends_at` ödeme penceresinin sonudur ve test faturalarında `nil` olur.

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
  elsif Invoq.invoice_payment_reversed?(event)
    invoice = event.fetch("data").fetch("invoice")
    fulfillment_key = invoice["reference_id"] || invoice.fetch("id")

    # fulfillment_key için siparişi bekletin veya geri alın.
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

invoq, daha önce ödenmiş bir fatura kendi tutarının altına geri düştüğünde `invoice.payment_reversed` de gönderir — örneğin zincir reorg'u onaylanmış bir transferi düşürdüğünde. Bunu `Invoq.invoice_payment_reversed?(event)` ile yakalayın ve kendi politikanıza göre siparişi bekletin veya geri alın.

Önemli:

- Ruby framework'ünüzün aldığı tam ham istek gövdesi dizesini geçin.
- `invoq-signature` başlığını geçin.
- `verify_webhook`, `Invoq.new(...)` çağrısını ya da invoq API gizli anahtarınızı gerektirmez.
- `INVOQ_SECRET_KEY`'i değil, webhook sırrınızı (`whsec_...`) kullanın.
- Sipariş işlemeyi idempotent yapın. Yeniden denenen webhook teslimatları aynı olayı birden fazla kez gönderebilir.
- Hızla 2xx dönün. Diğer her durum kodu başarısız teslimat sayılır ve yeniden denenir; yönlendirmeler ve `4xx` yanıtları da buna dahildir; yani bir dağıtım penceresi ya da geçici olarak yanlış yönlenmiş bir yol atılmaz, yeniden denenir. Aralar 1 dakika, 5 dakika, 30 dakika, ardından 2 saat; toplamda 5 deneme.
- Teslimatlar sırasız gelebilir. `payment_revision` değeri en yüksek olan anlık görüntüyü saklayın.

`Invoq.invoice_paid?`, fatura durumu `paid`, `settling` veya `settled` olan işlenebilir `invoice.paid` olaylarını kabul eder; `review_required` durumunu reddeder. `Invoq.invoice_payment_reversed?`, `invoice.payment_reversed` olaylarını durumu hiç denetlemeden kabul eder: elden kaçırdığınız bir geri alma, artık var olmayan bir ödemenin üzerine işlenmiş bir sipariş bırakır. Bu SDK sürümünün henüz modellemediği bir olay tipi de doğrulanır ve olduğu gibi döndürülür.

Webhook doğrulama hataları `Invoq::SignatureVerificationError` fırlatır. SDK, 5 dakikalık bir zaman damgası toleransına izin verir. İmza başlığı şudur:

```txt
invoq-signature: t=<unix seconds>,v1=<hex HMAC-SHA256 of "<t>.<raw body>">
```

## Hatalar

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
