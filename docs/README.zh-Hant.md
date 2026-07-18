# invoq Ruby SDK

[English](../README.md) · [Bahasa Indonesia](./README.id.md) · [Español](./README.es-419.md) · [Français](./README.fr.md) · [Português](./README.pt-BR.md) · [Tiếng Việt](./README.vi.md) · [Türkçe](./README.tr.md) · [ไทย](./README.th.md) · [简体中文](./README.zh-Hans.md) · **繁體中文**

> 本文是英文版 README 的繁體中文翻譯；若表述有出入，以[英文版](../README.md)為準。

在你的 Ruby 伺服器端程式碼裡，用 invoq 接收穩定幣付款。這個 SDK 封裝了 invoq 的伺服器 API，並會驗證帶簽章的 webhook。

這個 gem 只能用在你自己的伺服器上。它會處理私密金鑰，不應被打包進瀏覽器端程式碼。

## 伺服器端 SDK

用下面任一種語言，都能從你的後端建立帳單、驗證 webhook——REST API 和 webhook 簽章完全一致。本倉庫是 Ruby SDK。

| 語言    | 倉庫                                                                          |
| ------- | ----------------------------------------------------------------------------- |
| Node.js | [github.com/invoqmoney/sdk-js](https://github.com/invoqmoney/sdk-js)（`@invoq/server`） |
| Python  | [github.com/invoqmoney/sdk-python](https://github.com/invoqmoney/sdk-python)   |
| PHP     | [github.com/invoqmoney/sdk-php](https://github.com/invoqmoney/sdk-php)         |
| Go      | [github.com/invoqmoney/sdk-go](https://github.com/invoqmoney/sdk-go)           |
| Rust    | [github.com/invoqmoney/sdk-rust](https://github.com/invoqmoney/sdk-rust)       |
| Ruby    | **本倉庫**                                                                     |

無論後端選哪種語言，瀏覽器這一側都一樣：**`@invoq/checkout`**（JavaScript，位於 [github.com/invoqmoney/sdk-js](https://github.com/invoqmoney/sdk-js)）會為任意前端打開嵌在頁面裡的結帳彈窗。

## 安裝

安裝這個 gem：

```sh
gem install invoq
```

或加進 Gemfile：

```ruby
gem "invoq"
```

需要 Ruby 2.6 以上版本。

## 取得金鑰

1. 登入 [invoq 商家後台](https://app.invoq.money)，建立一個專案。
2. 在 **API keys** 頁面建立一組私密金鑰（secret key）。測試金鑰以 `sk_test_` 開頭，正式金鑰以 `sk_live_` 開頭；用哪種金鑰，決定開出的帳單是測試單還是正式單。
3. 在專案的 **webhooks** 設定裡儲存你的 webhook URL。對應模式的 webhook 簽章金鑰（`whsec_...`）只在首次啟用 webhook 時顯示一次——記得馬上存好。webhook URL 必須是可公開存取的 HTTPS 網址。

把兩者都加進伺服器的環境變數：

```sh
INVOQ_SECRET_KEY=sk_test_...
INVOQ_WEBHOOK_SECRET=whsec_...
```

先用測試金鑰跑通，上線時再換成正式金鑰和正式 webhook 簽章金鑰。

## 建立用戶端

```ruby
require "invoq"

invoq = Invoq.new(ENV.fetch("INVOQ_SECRET_KEY"))
```

預設的正式環境 API 位址：

```txt
https://api.invoq.money
```

在開發時，可覆寫 API 位址與請求逾時：

```ruby
invoq = Invoq.new(
  ENV.fetch("INVOQ_SECRET_KEY"),
  api_origin: "http://localhost:8787",
  timeout_ms: 10_000
)
```

`api_origin` 必須是完整的 `http` 或 `https` origin，且不含路徑、查詢字串、hash、使用者名稱或密碼。SDK 會在其後接上 `/v1/...` 資源路徑。

請求預設在 10 秒後逾時。傳入 `timeout_ms` 可調整逾時時間。`timeout_ms` 必須是正整數，單位為毫秒。

## 帳單

建立一張帳單：

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

說明：

- 金額要由伺服器端決定，不要相信用戶端傳來的金額。
- `amount` 是 `"0.01"` 到 `"1000000.00"` 之間的十進位美元字串，最多兩位小數，例如 `"129"` 或 `"129.99"`。
- `currency` 是選填，預設為 `"USD"`。
- 用一個穩定、非空的 `reference_id`，把 `invoice.paid` webhook 對應回你的訂單。用相同的 `reference_id` 和相同的帳單條件再建立一次，回傳的是既有帳單；條件不同則會回 `409 reference_id_conflict` API 錯誤。
- 如果你是用帳單 ID 而不是 `reference_id` 來履約，建立帳單時就把 `invoice_id` 和你的訂單一起存起來。
- 省略 `return_url` 就會使用專案的預設 return URL。傳入 `nil` 會送出 JSON `null`，建立一張沒有 return URL 的帳單。在以 `reference_id` 重試時，若你需要確保是某個特定值，請明確傳入 `return_url`。
- `description` 和 `reference_id` 若有提供，必須是字串。

查詢一張帳單：

```ruby
invoice = invoq.invoices.get("inv_123")
```

`invoices.get` 回傳託管結帳頁使用的公開帳單結構。它包含 `amount_paid`、`amount_due`、`amount_overpaid`、`payment_status`、`project`、`deposit_address`、`monitoring_ends_at`、`monitoring_status`、`transfers` 和 `direct_onchain_rails` 等欄位，但不包含 `reference_id`。如果需要你的商家端 `reference_id`，請使用建立帳單的回應或 `invoice.paid` webhook。

建立一筆測試付款：

```ruby
paid_invoice = invoq.invoices.create_test_payment(
  "inv_123",
  amount: "129",
  reference_id: "test_payment_001"
)
```

測試帳單收不了真錢，改從你的伺服器端模擬付款。

`create_test_payment` 只對用 `sk_test_` 金鑰建立的帳單有效。可以只付部分金額，帳單會變成 `partially_paid`；當累計付款達到帳單金額時，invoq 會向你的測試 webhook URL 送出一條帶簽章的 `invoice.paid` webhook。

`reference_id` 對測試付款而言是選填。沒有值時就直接省略，不要傳入 `nil`。

要在本機收 webhook，用 ngrok、cloudflared 之類的 HTTPS 隧道把本地伺服器公開出去，再把隧道網址存成商家後台裡的測試 webhook URL。後台也能送出一條帶簽章的 `webhook.ping`，幫你確認連線。

每個 invoice 方法都會直接把回應的 `data` 物件以 Ruby hash 的形式回傳。

## 託管結帳頁

每張帳單也都有一個託管結帳頁：

```txt
https://pay.invoq.money/<invoice id>
```

當頁內結帳彈窗不適合時，把連結分享出去，或直接導向過去就行。

## 輸入與回應

在送出請求前，SDK 會檢查 `amount` 的值與 `invoice_id` 參數是否為非空字串。invoq API 則會驗證金額的格式、範圍與幣別。

沒有要設定的選填欄位，就別放進請求的 hash 裡。當你要帶入 `description` 或 `reference_id` 時，請傳入字串。`return_url` 可以是字串或 `nil`。

回應裡的金額一律格式化為 4 位小數：用 `"129"` 建立，帳單會回傳 `amount: "129.0000"`。比較金額請按數值比，不要按字串比。`amount_due` 依 `max(amount - amount_paid, 0)` 衍生，使用和 `amount_paid` 相同的 18 位小數 scale；`amount_overpaid` 與它互為鏡像，即 `max(amount_paid - amount, 0)`，所以你不必自己做減法。`monitoring_status` 取值 `"active"` 或 `"ended"`——一旦變為 `"ended"`，收款位址就不再被監控——而 `transfers` 是已確認的鏈上收款紀錄（每一項都含 `tx_hash`、`amount` 和 `explorer_tx_url`）。測試帳單裡兩者分別為 `nil` / `[]`。

## Webhook

把原始請求內容傳給 `verify_webhook`。不要在驗證前先把 JSON 解析掉、再重新編碼。

這個 Rack 範例回傳 `[status, headers, body]`。在 Rails 裡，請用 `request.raw_post` 和 `request.get_header("HTTP_INVOQ_SIGNATURE")`；在 Sinatra 或其他 Ruby 框架裡，請用該框架的原始請求內容，以及它提供的 `invoq-signature` 或 `HTTP_INVOQ_SIGNATURE` 標頭。

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

    # 以冪等方式履約 fulfillment_key 對應的訂單。
  end

  [
    200,
    { "content-type" => "application/json" },
    ['{"received":true}']
  ]
end
```

在你的伺服器上，用 `invoice.paid` webhook 來履約訂單。瀏覽器端的結帳結果只是用來更新顧客的使用體驗；不要憑瀏覽器結果履約訂單。

當 `Invoq.invoice_paid?(event)` 為 true 時，表示帳單已可自動履約；用帳單的 `reference_id` 或你存下來的帳單 `id`，找到並履約對應的訂單。`review_required` 帳單暫時還不會發出 `invoice.paid` webhook。如果結帳回報 `review_required`，請顯示待審核狀態，並等審核通過後、稍後送達的 `invoice.paid` webhook 再處理。

重要事項：

- 傳入你的 Ruby 框架所收到、原封不動的原始請求內容字串。
- 傳入 `invoq-signature` 標頭。
- `verify_webhook` 不需要 `Invoq.new(...)`，也不需要你的 invoq API 私密金鑰。
- 請使用你的 webhook 簽章金鑰（`whsec_...`），而不是 `INVOQ_SECRET_KEY`。
- 履約要做到冪等。webhook 重送時，同一個事件可能會送達不止一次。
- 盡快回 2xx。任何其他狀態碼都算投遞失敗：逾時、`429`、`5xx` 這類暫時性失敗會重試，其他 `4xx` 則不會。

`Invoq.invoice_paid?` 接受可履約的 `invoice.paid` 事件——帳單狀態為 `paid`、`settling` 或 `settled`；並拒絕 `review_required`。

webhook 驗證失敗時會擲出 `Invoq::SignatureVerificationError`。SDK 允許時間戳有 5 分鐘的容差。簽章標頭格式為：

```txt
invoq-signature: t=<unix seconds>,v1=<hex HMAC-SHA256 of "<t>.<raw body>">
```

## 錯誤處理

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

非 2xx 的 API 回應會擲出 `Invoq::ApiError`，並帶有 `status`、`code`、`fields`、`meta` 和原始的 `payload`。

連線失敗、逾時、輸入不合法，以及回應解析失敗，都會擲出 `Invoq::Error`。建立帳單若逾時，用同一個 `reference_id` 重試是安全的。

webhook 驗證失敗會擲出 `Invoq::SignatureVerificationError`，並帶有下列其中一種錯誤代碼：

```txt
missing_signature
invalid_signature_header
timestamp_outside_tolerance
signature_mismatch
invalid_payload
```

## 開發

```sh
bundle exec rake test
```

## 授權條款

採用 MIT 授權條款。
