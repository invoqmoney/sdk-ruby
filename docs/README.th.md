# invoq Ruby SDK

[English](../README.md) · [Bahasa Indonesia](./README.id.md) · [Español](./README.es-419.md) · [Français](./README.fr.md) · [Português](./README.pt-BR.md) · [Tiếng Việt](./README.vi.md) · [Türkçe](./README.tr.md) · **ไทย** · [简体中文](./README.zh-Hans.md) · [繁體中文](./README.zh-Hant.md)

> เอกสารนี้แปลจาก README ภาษาอังกฤษ หากมีข้อความไม่ตรงกัน ให้ยึด[ฉบับภาษาอังกฤษ](../README.md)เป็นหลัก

รับชำระเงินด้วย stablecoin ผ่าน invoq ได้จากโค้ดเซิร์ฟเวอร์ Ruby ของคุณ SDK นี้ห่อหุ้ม API ฝั่งเซิร์ฟเวอร์ของ invoq เอาไว้ และตรวจสอบ webhook ที่มีลายเซ็นกำกับให้

ใช้ gem นี้บนเซิร์ฟเวอร์ของคุณเท่านั้น เพราะ gem นี้จัดการกับคีย์ลับ จึงไม่ควรนำไปรวมไว้ในโค้ดฝั่งเบราว์เซอร์

## SDK ฝั่งเซิร์ฟเวอร์

สร้างใบแจ้งหนี้และตรวจสอบ webhook จากแบ็กเอนด์ของคุณด้วยภาษาใดก็ได้เหล่านี้ — REST API และลายเซ็น webhook เหมือนกันทุกภาษา repo นี้คือ SDK สำหรับ Ruby

| ภาษา | Repo |
| --- | --- |
| Node.js | [github.com/invoqmoney/sdk-js](https://github.com/invoqmoney/sdk-js) (`@invoq/server`) |
| Python | [github.com/invoqmoney/sdk-python](https://github.com/invoqmoney/sdk-python) |
| PHP | [github.com/invoqmoney/sdk-php](https://github.com/invoqmoney/sdk-php) |
| Go | [github.com/invoqmoney/sdk-go](https://github.com/invoqmoney/sdk-go) |
| Rust | [github.com/invoqmoney/sdk-rust](https://github.com/invoqmoney/sdk-rust) |
| Ruby | **repo นี้** |

จะเลือกแบ็กเอนด์ตัวไหนก็ตาม ฝั่งเบราว์เซอร์เหมือนกันหมด: **`@invoq/checkout`** (JavaScript อยู่ใน [github.com/invoqmoney/sdk-js](https://github.com/invoqmoney/sdk-js)) เปิดหน้าชำระเงินแบบฝังในหน้าเว็บให้ฟรอนต์เอนด์ใดก็ได้

## ติดตั้ง

ติดตั้ง gem:

```sh
gem install invoq
```

หรือเพิ่มลงใน Gemfile:

```ruby
gem "invoq"
```

ต้องใช้ Ruby 2.6 ขึ้นไป

## รับคีย์ของคุณ

1. เข้าสู่ระบบ[แดชบอร์ด invoq](https://app.invoq.money) แล้วสร้างโปรเจกต์
2. ที่หน้า **API keys** สร้างคีย์ลับ (secret key) ขึ้นมา คีย์ทดสอบขึ้นต้นด้วย `sk_test_` คีย์จริงขึ้นต้นด้วย `sk_live_` โหมดของคีย์เป็นตัวกำหนดว่าใบแจ้งหนี้ที่สร้างจะเป็นแบบทดสอบหรือของจริง
3. ในการตั้งค่า **webhooks** ของโปรเจกต์ บันทึก URL ของ webhook ที่จะใช้ ซีเคร็ตของ webhook (`whsec_...`) สำหรับโหมดนั้นจะแสดงแค่ครั้งเดียวตอนเปิดใช้ webhook ครั้งแรก — รีบเก็บไว้ทันที URL ของ webhook ต้องเป็น HTTPS ที่เข้าถึงได้แบบสาธารณะ

เพิ่มทั้งสองค่าเข้าเป็นตัวแปรสภาพแวดล้อมของเซิร์ฟเวอร์:

```sh
INVOQ_SECRET_KEY=sk_test_...
INVOQ_WEBHOOK_SECRET=whsec_...
```

เริ่มจากคีย์ทดสอบก่อน แล้วค่อยสลับเป็นคีย์จริงกับซีเคร็ต webhook ของจริงตอนใช้งานจริง

## สร้างไคลเอนต์

```ruby
require "invoq"

invoq = Invoq.new(ENV.fetch("INVOQ_SECRET_KEY"))
```

origin ของ API เริ่มต้นในสภาพแวดล้อมจริง:

```txt
https://api.invoq.money
```

ปรับทับค่า origin ของ API และ timeout ของ request ระหว่างการพัฒนาได้:

```ruby
invoq = Invoq.new(
  ENV.fetch("INVOQ_SECRET_KEY"),
  api_origin: "http://localhost:8787",
  timeout_ms: 10_000
)
```

`api_origin` ต้องเป็น origin แบบ `http` หรือ `https` เต็มรูปแบบ โดยไม่มีพาธ, query, hash, ชื่อผู้ใช้ หรือรหัสผ่าน แล้ว SDK จะต่อท้ายด้วยพาธทรัพยากร `/v1/...` ให้เอง

โดยค่าเริ่มต้น request จะหมดเวลารอหลังจาก 10 วินาที ส่งค่า `timeout_ms` เพื่อเปลี่ยนเวลา timeout ได้ โดย `timeout_ms` ต้องเป็นจำนวนเต็มบวกในหน่วยมิลลิวินาที

## ใบแจ้งหนี้

สร้างใบแจ้งหนี้:

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

หมายเหตุ:

- ใช้ยอดเงินที่กำหนดจากฝั่งเซิร์ฟเวอร์ อย่าเชื่อยอดเงินที่ส่งมาจากฝั่งไคลเอนต์
- `amount` เป็นสตริงเลขทศนิยมสกุล USD ตั้งแต่ `"0.01"` ถึง `"999.99"` ทศนิยมไม่เกิน 2 ตำแหน่ง เช่น `"129"` หรือ `"129.99"`
- `currency` เป็นค่าที่ไม่บังคับ และมีค่าเริ่มต้นเป็น `"USD"`
- ใช้ `reference_id` ที่คงที่และไม่เป็นค่าว่าง เพื่อโยง webhook `invoice.paid` กลับไปหาคำสั่งซื้อของคุณ ถ้าสร้างใบแจ้งหนี้ซ้ำด้วย `reference_id` เดิมและเงื่อนไขเดิม จะได้ใบแจ้งหนี้ใบเดิมกลับมา ส่วนเงื่อนไขที่ต่างกันจะล้มเหลวด้วยข้อผิดพลาด API `409 reference_id_conflict`
- ถ้าคุณจัดการคำสั่งซื้อโดยใช้ invoice ID แทน `reference_id` ให้เก็บ `invoice_id` ไว้กับคำสั่งซื้อของคุณตอนที่สร้างใบแจ้งหนี้
- ไม่ต้องใส่ `return_url` หากต้องการใช้ return URL เริ่มต้นของโปรเจกต์ ส่งค่า `nil` เพื่อส่ง JSON `null` และสร้างใบแจ้งหนี้โดยไม่มี return URL เมื่อลองสร้างซ้ำด้วย `reference_id` ให้ส่ง `return_url` มาอย่างชัดเจนเมื่อคุณต้องการระบุค่าที่เจาะจง
- `description` และ `reference_id` ต้องเป็นสตริงเมื่อมีการระบุค่า

ดึงข้อมูลใบแจ้งหนี้:

```ruby
invoice = invoq.invoices.get("inv_123")
```

`invoices.get` จะคืนรูปแบบใบแจ้งหนี้สาธารณะที่หน้า checkout แบบโฮสต์ใช้ ซึ่งมีฟิลด์อย่าง `amount_paid`, `amount_due`, `amount_overpaid`, `payment_status`, `project`, `deposit_address`, `monitoring_ends_at`, `monitoring_status`, `transfers` และ `direct_onchain_rails` แต่ไม่มี `reference_id` ถ้าต้องใช้ `reference_id` ฝั่ง merchant ให้ใช้ response ตอนสร้างใบแจ้งหนี้หรือ webhook `invoice.paid`

สร้างการชำระเงินทดสอบ:

```ruby
paid_invoice = invoq.invoices.create_test_payment(
  "inv_123",
  amount: "129",
  reference_id: "test_payment_001"
)
```

ใบแจ้งหนี้ทดสอบรับเงินจริงไม่ได้ ให้จำลองการจ่ายจากเซิร์ฟเวอร์แทน

`create_test_payment` ใช้ได้เฉพาะกับใบแจ้งหนี้ที่สร้างด้วยคีย์ `sk_test_` เท่านั้น สามารถจ่ายบางส่วนได้ ซึ่งจะได้ผลเป็น `partially_paid` และเมื่อยอดจ่ายครบตามจำนวนของใบแจ้งหนี้ invoq จะส่ง webhook `invoice.paid` ที่มีลายเซ็นกำกับไปยัง URL webhook ทดสอบของคุณ

`reference_id` เป็นค่าที่ไม่บังคับสำหรับการชำระเงินทดสอบ หากไม่ได้กำหนดค่าก็ไม่ต้องใส่ อย่าส่งค่า `nil`

ถ้าอยากรับ webhook บนเครื่องตัวเอง ให้เปิดเซิร์ฟเวอร์ในเครื่องออกสู่ภายนอกผ่าน HTTPS tunnel อย่าง ngrok หรือ cloudflared แล้วบันทึก URL ของ tunnel เป็น URL webhook ทดสอบในแดชบอร์ด แดชบอร์ดยังส่ง `webhook.ping` แบบมีลายเซ็นมาให้เช็กการเชื่อมต่อได้ด้วย

เมธอดของใบแจ้งหนี้แต่ละตัวจะคืนออบเจกต์ `data` ของการตอบกลับมาเป็น Ruby hash โดยตรง

## หน้าชำระเงินที่โฮสต์ให้

ใบแจ้งหนี้ทุกใบยังมีหน้าชำระเงินที่โฮสต์ให้อยู่แล้วที่:

```txt
https://pay.invoq.money/<invoice id>
```

แชร์ลิงก์หรือเปลี่ยนเส้นทางไปยังหน้านั้นได้เลยเมื่อหน้าชำระเงินแบบฝังในหน้าเว็บไม่ตอบโจทย์

## อินพุตและการตอบกลับ

SDK จะตรวจสอบว่าค่า `amount` และอาร์กิวเมนต์ `invoice_id` เป็นสตริงที่ไม่ว่างเปล่าก่อนส่ง request ส่วน API ของ invoq จะตรวจสอบรูปแบบ, ช่วงค่า และสกุลเงินของยอดเงิน

ฟิลด์ที่ไม่บังคับและไม่ได้กำหนดค่า ให้ละไว้ไม่ต้องใส่ใน request hash เมื่อคุณใส่ `description` หรือ `reference_id` ให้ส่งเป็นสตริง ส่วน `return_url` เป็นได้ทั้งสตริงหรือ `nil`

ยอดเงินในการตอบกลับถูกปรับให้เป็นทศนิยม 4 ตำแหน่งเสมอ: สร้างด้วย `"129"` ใบแจ้งหนี้จะตอบกลับ `amount: "129.0000"` เวลาจะเทียบยอดเงินให้เทียบเป็นตัวเลข อย่าเทียบเป็นสตริง `amount_due` คำนวณจาก `max(amount - amount_paid, 0)` และใช้สเกลทศนิยม 18 ตำแหน่งเหมือน `amount_paid` ขณะที่ `amount_overpaid` เป็นภาพสะท้อนของมัน คือ `max(amount_paid - amount, 0)` คุณจึงไม่ต้องลบเงินเอง `monitoring_status` มีค่าเป็น `"active"` หรือ `"ended"` — พอเป็น `"ended"` แล้ว ที่อยู่รับเงินจะไม่ถูกเฝ้าดูอีกต่อไป — ส่วน `transfers` คือรายการรับเงินบนเชนที่ยืนยันแล้ว (แต่ละรายการมี `tx_hash`, `amount` และ `explorer_tx_url`) ทั้งคู่จะเป็น `nil` / `[]` สำหรับใบแจ้งหนี้ทดสอบ

## Webhooks

ส่งเนื้อหา request ดิบเข้าไปที่ `verify_webhook` อย่าแปลง JSON แล้วเข้ารหัสใหม่ก่อนการตรวจสอบ

ตัวอย่าง Rack นี้จะคืนค่าเป็น `[status, headers, body]` ใน Rails ให้ใช้ `request.raw_post` และ `request.get_header("HTTP_INVOQ_SIGNATURE")` ส่วนใน Sinatra หรือเฟรมเวิร์ก Ruby อื่น ให้ใช้เนื้อหา request ดิบของเฟรมเวิร์กนั้น และเฮดเดอร์ `invoq-signature` หรือ `HTTP_INVOQ_SIGNATURE` ที่เฟรมเวิร์กเปิดให้เข้าถึง

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

    # จัดการคำสั่งซื้อของ fulfillment_key อย่างปลอดภัยเมื่อรับซ้ำ (idempotent)
  end

  [
    200,
    { "content-type" => "application/json" },
    ['{"received":true}']
  ]
end
```

ใช้ webhook `invoice.paid` ในการจัดการคำสั่งซื้อบนเซิร์ฟเวอร์ของคุณ ผลลัพธ์ checkout จากเบราว์เซอร์มีไว้สำหรับอัปเดตประสบการณ์ของลูกค้าเท่านั้น อย่าจัดการคำสั่งซื้อโดยอิงผลจากเบราว์เซอร์

เมื่อ `Invoq.invoice_paid?(event)` เป็น true แปลว่าใบแจ้งหนี้พร้อมให้จัดการอัตโนมัติแล้ว ให้ใช้ `reference_id` ของใบแจ้งหนี้ หรือ `id` ของใบแจ้งหนี้ที่เก็บไว้ ไปค้นหาและจัดการคำสั่งซื้อของคุณ ใบแจ้งหนี้สถานะ `review_required` จะยังไม่ส่ง webhook `invoice.paid` หาก checkout ส่งผลลัพธ์เป็น `review_required` ให้แสดงสถานะรอตรวจสอบ และรอ webhook `invoice.paid` ที่จะตามมาหลังการตรวจสอบผ่าน

สำคัญ:

- ส่งสตริงเนื้อหา request ดิบตรงตามที่เฟรมเวิร์ก Ruby ของคุณได้รับมาเป๊ะ ๆ
- ส่งเฮดเดอร์ `invoq-signature` มาด้วย
- `verify_webhook` ไม่จำเป็นต้องใช้ `Invoq.new(...)` หรือคีย์ลับ API ของ invoq
- ใช้ซีเคร็ต webhook ของคุณ (`whsec_...`) ไม่ใช่ `INVOQ_SECRET_KEY`
- จัดการคำสั่งซื้อให้ปลอดภัยเมื่อรับซ้ำ (idempotent) เพราะการส่ง webhook ซ้ำอาจส่งเหตุการณ์เดียวกันมามากกว่าหนึ่งครั้ง
- ตอบกลับด้วย 2xx ให้เร็ว สถานะอื่นใดถือว่าส่งไม่สำเร็จ ความล้มเหลวชั่วคราวอย่าง timeout, `429` และ `5xx` จะถูกส่งซ้ำ ส่วน `4xx` อื่นจะไม่ส่งซ้ำ

`Invoq.invoice_paid?` จะรับเฉพาะเหตุการณ์ `invoice.paid` ที่จัดการคำสั่งซื้อได้ ซึ่งใบแจ้งหนี้มีสถานะเป็น `paid`, `settling` หรือ `settled` และจะปฏิเสธ `review_required`

การตรวจสอบ webhook ที่ล้มเหลวจะโยน `Invoq::SignatureVerificationError` โดย SDK ยอมให้ timestamp คลาดเคลื่อนได้ไม่เกิน 5 นาที รูปแบบของเฮดเดอร์ลายเซ็นคือ:

```txt
invoq-signature: t=<unix seconds>,v1=<hex HMAC-SHA256 of "<t>.<raw body>">
```

## ข้อผิดพลาด

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

การตอบกลับ API ที่ไม่ใช่ 2xx จะโยน `Invoq::ApiError` ซึ่งมี `status`, `code`, `fields`, `meta` และ `payload` ดิบ

การเชื่อมต่อล้มเหลว, การหมดเวลารอ, อินพุตไม่ถูกต้อง และการแปลงข้อมูลการตอบกลับล้มเหลว จะโยน `Invoq::Error` การสร้างใบแจ้งหนี้ที่หมดเวลารอสามารถลองใหม่ด้วย `reference_id` เดิมได้อย่างปลอดภัย

การตรวจสอบ webhook ที่ล้มเหลวจะโยน `Invoq::SignatureVerificationError` พร้อมโค้ดอย่างใดอย่างหนึ่งต่อไปนี้:

```txt
missing_signature
invalid_signature_header
timestamp_outside_tolerance
signature_mismatch
invalid_payload
```

## การพัฒนา

```sh
bundle exec rake test
```

## สัญญาอนุญาต

อยู่ภายใต้สัญญาอนุญาต MIT
