# invoq Ruby SDK

[English](../README.md) · [Bahasa Indonesia](./README.id.md) · [Español](./README.es-419.md) · [Français](./README.fr.md) · [Português](./README.pt-BR.md) · [Tiếng Việt](./README.vi.md) · [Türkçe](./README.tr.md) · [ไทย](./README.th.md) · **简体中文** · [繁體中文](./README.zh-Hant.md)

> 本文是英文版 README 的简体中文翻译；若表述有出入，以[英文版](../README.md)为准。

用 Ruby 服务端代码，通过 invoq 接收稳定币付款。本 SDK 封装了 invoq 的服务端 API，并负责验证带签名的 webhook。

这个 gem 只应在你的服务端使用。它会处理密钥（secret key），不应被打包进浏览器代码。

## 服务端 SDK

用下面任意一种语言，都能从你的后端创建账单、验证 webhook——REST API 和 webhook 签名完全一致。本仓库是 Ruby SDK。

| 语言 | 仓库 |
| --- | --- |
| Node.js | [github.com/invoqmoney/sdk-js](https://github.com/invoqmoney/sdk-js)（`@invoq/server`） |
| Python | [github.com/invoqmoney/sdk-python](https://github.com/invoqmoney/sdk-python) |
| PHP | [github.com/invoqmoney/sdk-php](https://github.com/invoqmoney/sdk-php) |
| Go | [github.com/invoqmoney/sdk-go](https://github.com/invoqmoney/sdk-go) |
| Rust | [github.com/invoqmoney/sdk-rust](https://github.com/invoqmoney/sdk-rust) |
| Ruby | **本仓库** |

无论后端选哪种语言，浏览器这一侧都一样：**`@invoq/checkout`**（JavaScript，在 [github.com/invoqmoney/sdk-js](https://github.com/invoqmoney/sdk-js) 中）为任意前端打开嵌在页面里的收银台弹窗。

## 安装

安装这个 gem：

```sh
gem install invoq
```

或者把它加进 Gemfile：

```ruby
gem "invoq"
```

要求 Ruby 2.6 及以上版本。

## 获取密钥

1. 登录 [invoq 商户后台](https://app.invoq.money)，创建一个项目。
2. 在 **API keys** 页面创建一把密钥（secret key）。测试密钥以 `sk_test_` 开头，正式密钥以 `sk_live_` 开头；用哪种密钥，决定开出的账单是测试单还是正式单。
3. 在项目的 **webhooks** 设置里保存你的 webhook URL。对应模式的 webhook 签名密钥（`whsec_...`）只在首次启用 webhook 时展示一次——记得马上存好。webhook URL 必须是公网可访问的 HTTPS 地址。

把两者都加进服务端环境变量：

```sh
INVOQ_SECRET_KEY=sk_test_...
INVOQ_WEBHOOK_SECRET=whsec_...
```

先用测试密钥跑通，上线时再换成正式密钥和正式 webhook 签名密钥。

## 创建客户端

```ruby
require "invoq"

invoq = Invoq.new(ENV.fetch("INVOQ_SECRET_KEY"))
```

生产环境默认的 API 地址：

```txt
https://api.invoq.money
```

开发时可以覆盖 API 地址和请求超时：

```ruby
invoq = Invoq.new(
  ENV.fetch("INVOQ_SECRET_KEY"),
  api_origin: "http://localhost:8787",
  timeout_ms: 10_000
)
```

`api_origin` 必须是完整的 `http` 或 `https` origin，不能带路径、查询参数、hash、用户名或密码。SDK 会在其后拼接 `/v1/...` 资源路径。

请求默认 10 秒后超时。传入 `timeout_ms` 可以修改超时时间。`timeout_ms` 必须是以毫秒为单位的正整数。

## 账单

创建账单：

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

说明：

- 金额要由服务端决定，不要相信客户端传来的金额。
- `amount` 是 `"0.01"` 到 `"999.99"` 之间的十进制美元字符串，最多两位小数，比如 `"129"` 或 `"129.99"`。
- `currency` 可选，默认为 `"USD"`。
- 用一个稳定、非空的 `reference_id`，把 `invoice.paid` webhook 对应回你的订单。用相同的 `reference_id` 和相同的账单条款再次创建，返回的是已有账单；条款不同则会报 `409 reference_id_conflict` API 错误。
- 如果你是按账单 ID（而不是 `reference_id`）来履约的，请在创建账单时把 `invoice_id` 和订单一起存下来。
- 省略 `return_url` 时，会使用项目的默认回跳地址。传入 `nil` 会发送 JSON `null`，创建一张没有回跳地址的账单。用 `reference_id` 重试时，如果需要确保某个具体的值，请显式传入 `return_url`。
- `description` 和 `reference_id` 如果传了，必须是字符串。

查询账单：

```ruby
invoice = invoq.invoices.get("inv_123")
```

`invoices.get` 返回托管收银页使用的公开账单结构。它包含 `amount_paid`、`amount_due`、`amount_overpaid`、`payment_status`、`project`、`deposit_address`、`monitoring_ends_at`、`monitoring_status`、`transfers` 和 `direct_onchain_rails` 等字段，但不包含 `reference_id`。如果需要商户侧的 `reference_id`，请使用创建账单的响应或 `invoice.paid` webhook。

创建一笔测试付款：

```ruby
paid_invoice = invoq.invoices.create_test_payment(
  "inv_123",
  amount: "129",
  reference_id: "test_payment_001"
)
```

测试账单收不了真钱，改用服务端模拟付款。

`create_test_payment` 只对用 `sk_test_` 密钥创建的账单有效。可以只付部分金额，账单会变成 `partially_paid`；当累计付款达到账单金额时，invoq 会向你的测试 webhook URL 发送一条带签名的 `invoice.paid` webhook。

测试付款的 `reference_id` 是可选的。不需要时就省略，不要传 `nil`。

要在本机接收 webhook，用 ngrok、cloudflared 之类的 HTTPS 隧道把本地服务暴露出去，再把隧道地址保存为商户后台里的测试 webhook URL。后台还能发送一条带签名的 `webhook.ping`，帮你确认连通性。

每个账单方法都会直接把响应中的 `data` 对象作为 Ruby 哈希（hash）返回。

## 托管收银页

每张账单还自带一个托管收银页：

```txt
https://pay.invoq.money/<invoice id>
```

当页内收银台弹窗不合适时，把链接分享出去或直接跳转过去即可。

## 入参与响应

SDK 在发送请求前，会检查 `amount` 值和 `invoice_id` 参数是不是非空字符串。金额的格式、范围和币种由 invoq API 负责校验。

不需要的可选字段就别放进请求的哈希里。如果要带上 `description` 或 `reference_id`，请传字符串。`return_url` 可以是字符串或 `nil`。

响应里的金额统一格式化为 4 位小数：用 `"129"` 创建，账单返回 `amount: "129.0000"`。比较金额请按数值比较，不要按字符串比较。`amount_due` 按 `max(amount - amount_paid, 0)` 派生，使用和 `amount_paid` 相同的 18 位小数 scale；`amount_overpaid` 与它互为镜像，即 `max(amount_paid - amount, 0)`，所以你不必自己做减法。`monitoring_status` 取值 `"active"` 或 `"ended"`——一旦变为 `"ended"`，收款地址就不再被监控——而 `transfers` 是已确认的链上收款记录（每一项都含 `tx_hash`、`amount` 和 `explorer_tx_url`）。测试账单里两者分别为 `nil` / `[]`。

## Webhook

把原始请求体传给 `verify_webhook`。验签之前，不要先解析 JSON 再重新编码。

下面这个 Rack 示例返回 `[status, headers, body]`。在 Rails 里，用 `request.raw_post` 和 `request.get_header("HTTP_INVOQ_SIGNATURE")`；在 Sinatra 或其他 Ruby 框架里，使用该框架提供的原始请求体，以及它暴露的 `invoq-signature` 或 `HTTP_INVOQ_SIGNATURE` 头。

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

    # 幂等地履约 fulfillment_key 对应的订单。
  end

  [
    200,
    { "content-type" => "application/json" },
    ['{"received":true}']
  ]
end
```

在服务端用 `invoice.paid` webhook 来履约订单。浏览器端的收银结果只用于更新面向用户的体验；不要凭浏览器结果履约订单。

当 `Invoq.invoice_paid?(event)` 为 true 时，账单就可以自动履约了；用账单的 `reference_id` 或你存下来的账单 `id` 找到并履约对应的订单。`review_required` 账单暂时还不会发送 `invoice.paid` webhook。如果收银台返回 `review_required`，请展示待审核状态，并等审核通过后的 `invoice.paid` webhook 再履约。

重要：

- 传入你的 Ruby 框架收到的、原封不动的原始请求体字符串。
- 传入 `invoq-signature` 头。
- `verify_webhook` 不需要 `Invoq.new(...)`，也不需要你的 invoq API 密钥。
- 用你的 webhook 签名密钥（`whsec_...`），不是 `INVOQ_SECRET_KEY`。
- 履约要做到幂等。webhook 投递会重试，同一事件可能送达不止一次。
- 尽快返回 2xx。任何其他状态码都算投递失败。超时、`429`、`5xx` 这类临时性失败会重试；其他 `4xx` 则不会。

`Invoq.invoice_paid?` 接受可履约的 `invoice.paid` 事件——账单状态为 `paid`、`settling` 或 `settled`；它会拒绝 `review_required`。

webhook 验签失败时会抛出 `Invoq::SignatureVerificationError`。SDK 允许 5 分钟的时间戳容差。签名头格式是：

```txt
invoq-signature: t=<unix seconds>,v1=<hex HMAC-SHA256 of "<t>.<raw body>">
```

## 错误

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

非 2xx 的 API 响应会抛出 `Invoq::ApiError`，带有 `status`、`code`、`fields`、`meta` 和原始的 `payload`。

连接失败、超时、入参不合法，以及响应解析失败，都会抛出 `Invoq::Error`。创建账单超时后，用同一个 `reference_id` 重试是安全的。

webhook 验签失败会抛出 `Invoq::SignatureVerificationError`，带有下列 code 之一：

```txt
missing_signature
invalid_signature_header
timestamp_outside_tolerance
signature_mismatch
invalid_payload
```

## 开发

```sh
bundle exec rake test
```

## 许可证

采用 MIT 许可证授权。
