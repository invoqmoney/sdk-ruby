# invoq Ruby SDK

[English](https://github.com/invoqmoney/sdk-ruby/blob/main/README.md) · [Bahasa Indonesia](./README.id.md) · [Español](./README.es-419.md) · [Français](./README.fr.md) · [Português](./README.pt-BR.md) · [Tiếng Việt](./README.vi.md) · [Türkçe](./README.tr.md) · [ไทย](./README.th.md) · **简体中文** · [繁體中文](./README.zh-Hant.md)

> 本文是英文版 README 的简体中文翻译；若表述有出入，以[英文版](https://github.com/invoqmoney/sdk-ruby/blob/main/README.md)为准。

用 Ruby 服务端代码，通过 invoq 接收稳定币付款。本 SDK 封装了 invoq 的服务端 API，并负责验证带签名的 webhook。

这个 gem 只应在你的服务端使用。它会处理密钥（secret key），不应被打包进浏览器代码。

**在用 AI 写代码？把这段贴给它。**

```
用 invoq 给我的项目接入稳定币收款，从测试模式开始。写代码前先读文档 https://invoq.money/llms.txt
```

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
4. 上线前先设置 **Receiving wallet**。测试账单不需要它；没有结算去向的正式账单会以 `409 no_payment_options_available` 失败。

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
  description: "SaaS boilerplate",
  reference_id: "order_1234",
  return_url: "https://merchant.example/thanks"
)

invoice_id = invoice.fetch("id")
checkout_url = "https://pay.invoq.money/#{invoice_id}"
```

说明：

- 金额要由服务端决定，不要相信客户端传来的金额。
- `amount` 是 `"0.01"` 到 `"1000000.00"` 之间的十进制美元字符串，最多两位小数，比如 `"129"` 或 `"129.99"`。币种恒为 USD，测试还是正式由密钥决定——两者都不是请求字段。
- 用一个稳定、非空的 `reference_id`，把 `invoice.paid` webhook 对应回你的订单。用相同的 `reference_id` 和相同的账单条款再次创建，返回的是已有账单；条款不同则会报 `409 reference_id_conflict` API 错误。
- 如果你是按账单 ID（而不是 `reference_id`）来履约的，请在创建账单时把 `invoice_id` 和订单一起存下来。
- 省略 `return_url` 时，会使用项目的默认回跳地址。传入 `nil` 会发送 JSON `null`，创建一张没有回跳地址的账单。用 `reference_id` 重试时，如果需要确保某个具体的值，请显式传入 `return_url`。
- `description` 和 `reference_id` 如果传了，必须是字符串。

查询账单：

```ruby
invoice = invoq.invoices.get("inv_123")
```

`invoices.get` 返回托管收银页使用的公开账单结构：即创建响应的结构，加上 `amount_paid`、`project` 和 `transfers`，去掉 `reference_id`。如果需要商户侧的 `reference_id`，请使用创建账单的响应或 `invoice.paid` webhook。

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

要在本机接收 webhook，用 ngrok、cloudflared 之类的 HTTPS 隧道把本地服务暴露出去，再把隧道地址保存为商户后台里的测试 webhook URL。

每个账单方法都会直接把响应中的 `data` 对象作为 Ruby 哈希（hash）返回。

## 托管收银页

每张账单还自带一个托管收银页：

```txt
https://pay.invoq.money/<invoice id>
```

当页内收银台弹窗不合适时，把链接分享出去或直接跳转过去即可。

## 入参与响应

SDK 在发送请求前，会检查 `amount` 值和 `invoice_id` 参数是不是非空字符串。金额的格式和范围由 invoq API 负责校验。

不需要的可选字段就别放进请求的哈希里。如果要带上 `description` 或 `reference_id`，请传字符串。`return_url` 可以是字符串或 `nil`。哈希里的其他键会被丢掉而不会发出去，因为 API 会拒绝未知的请求体字段。

响应里的金额统一格式化为 4 位小数：用 `"129"` 创建，账单返回 `amount: "129.0000"`。比较金额请按数值比较，不要按字符串比较。`amount_due` 按 `max(amount - amount_paid, 0)` 派生，使用和 `amount_paid` 相同的 18 位小数 scale；`amount_overpaid` 与它互为镜像，即 `max(amount_paid - amount, 0)`，所以你不必自己做减法。

账单有两个状态字段。`status` 是记账状态——`unpaid`、`partially_paid`、`paid`、`settling`、`settled`、`review_required`，其中三个等同于已付款的取值只差在资金离你的钱包还有多远。`checkout_status` 是付款人看到的状态——`open`、`confirming`、`expired`、`paid`、`unavailable`——它从不构成履约依据。`payment_revision` 是一个非负整数，每当已确认的付款集合变化就加一，你可以据此丢掉比手上更旧的快照。

`payment_options` 装的是付款指令，创建时即固定，测试模式下为 `[]`。每一项先按 `status` 分辨，再按 `collection_method` 分辨：只有 `"ready"` 可付，`"evm_deposit"` 带 `deposit_address` 和 `suggested_amount`，`"direct_exact"` 带 `recipient_address` 以及买家必须一位不差转出的 `exact_amount`。`transfers` 是已确认的收款记录——`transaction_id`、`event_index`、`amount`、`explorer_transaction_url`——在有付款确认前一直是 `[]`。完整字段说明见 [REST API 文档](https://github.com/invoqmoney/api)。

请用 `chain_namespace`、`chain_reference` 和 `token_address` 来标识一个付款方式，不要用它在数组里的位置。`monitoring_ends_at` 是付款窗口的结束时间，测试账单里为 `nil`。

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
  elsif Invoq.invoice_payment_reversed?(event)
    invoice = event.fetch("data").fetch("invoice")
    fulfillment_key = invoice["reference_id"] || invoice.fetch("id")

    # 暂停或撤销 fulfillment_key 对应的订单。
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

账单从已付款跌回不足额时，invoq 还会发 `invoice.payment_reversed`——比如链重组把一笔已确认的转账拿掉了。用 `Invoq.invoice_payment_reversed?(event)` 接住它，再按你自己的策略暂停或撤销履约。

重要：

- 传入你的 Ruby 框架收到的、原封不动的原始请求体字符串。
- 传入 `invoq-signature` 头。
- `verify_webhook` 不需要 `Invoq.new(...)`，也不需要你的 invoq API 密钥。
- 用你的 webhook 签名密钥（`whsec_...`），不是 `INVOQ_SECRET_KEY`。
- 履约要做到幂等。webhook 投递会重试，同一事件可能送达不止一次。
- 尽快返回 2xx。任何其他状态码都算投递失败并会重试，重定向和 `4xx` 也在其中，所以一次发版窗口或临时走错的路由会被重试，而不是直接丢弃。间隔依次为 1 分钟、5 分钟、30 分钟、2 小时，总共最多 5 次。
- 送达顺序不保证。请保留 `payment_revision` 最大的那份快照。

`Invoq.invoice_paid?` 接受可履约的 `invoice.paid` 事件——账单状态为 `paid`、`settling` 或 `settled`；它会拒绝 `review_required`。 `Invoq.invoice_payment_reversed?` 接受 `invoice.payment_reversed` 事件，完全不检查状态：漏掉一次撤销，就会让订单继续挂在一笔已经不存在的付款上。本版 SDK 尚未建模的事件类型同样能验签通过，并原样返回。

webhook 验签失败时会抛出 `Invoq::SignatureVerificationError`。SDK 允许 5 分钟的时间戳容差。签名头格式是：

```txt
invoq-signature: t=<unix seconds>,v1=<hex HMAC-SHA256 of "<t>.<raw body>">
```

## 错误

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
