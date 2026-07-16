# invoq Ruby SDK

[English](../README.md) · [Bahasa Indonesia](./README.id.md) · [Español](./README.es-419.md) · [Français](./README.fr.md) · [Português](./README.pt-BR.md) · **Tiếng Việt** · [Türkçe](./README.tr.md) · [ไทย](./README.th.md) · [简体中文](./README.zh-Hans.md) · [繁體中文](./README.zh-Hant.md)

> Tài liệu này được dịch từ README tiếng Anh; nếu có chỗ khác nhau, [bản tiếng Anh](../README.md) là bản chuẩn.

Nhận thanh toán stablecoin bằng invoq từ mã máy chủ Ruby. SDK này bọc các API máy chủ của invoq và xác minh các webhook có chữ ký.

Chỉ dùng gem này trên máy chủ của bạn. Nó xử lý các khóa bí mật và không nên bị đóng gói vào mã trình duyệt.

## SDK server

Tạo hóa đơn và xác minh webhook từ backend của bạn bằng bất kỳ ngôn ngữ nào dưới đây — cùng REST API, cùng chữ ký webhook. Repo này là SDK Ruby.

| Ngôn ngữ | Repo |
| --- | --- |
| Node.js | [github.com/invoqmoney/sdk-js](https://github.com/invoqmoney/sdk-js) (`@invoq/server`) |
| Python | [github.com/invoqmoney/sdk-python](https://github.com/invoqmoney/sdk-python) |
| PHP | [github.com/invoqmoney/sdk-php](https://github.com/invoqmoney/sdk-php) |
| Go | [github.com/invoqmoney/sdk-go](https://github.com/invoqmoney/sdk-go) |
| Rust | [github.com/invoqmoney/sdk-rust](https://github.com/invoqmoney/sdk-rust) |
| Ruby | **repo này** |

Dù bạn chọn backend nào, phía trình duyệt vẫn như nhau: **`@invoq/checkout`** (JavaScript, trong [github.com/invoqmoney/sdk-js](https://github.com/invoqmoney/sdk-js)) mở cửa sổ thanh toán nhúng trong trang cho mọi frontend.

## Cài đặt

Cài đặt gem:

```sh
gem install invoq
```

Hoặc thêm vào Gemfile:

```ruby
gem "invoq"
```

Yêu cầu Ruby 2.6 trở lên.

## Lấy khóa API

1. Đăng nhập [bảng điều khiển invoq](https://app.invoq.money) và tạo một dự án.
2. Ở trang **API keys**, tạo một khóa bí mật. Khóa thử nghiệm bắt đầu bằng `sk_test_`, khóa thật bằng `sk_live_`. Loại khóa quyết định hóa đơn tạo ra là thử nghiệm hay thật.
3. Trong phần cài đặt **webhooks** của dự án, lưu URL webhook của bạn. Mã bí mật của webhook (`whsec_...`) cho chế độ đó chỉ hiện đúng một lần, lúc bạn bật webhook lần đầu — hãy lưu lại ngay. URL webhook phải là URL HTTPS truy cập công khai được.

Thêm cả hai vào biến môi trường của máy chủ:

```sh
INVOQ_SECRET_KEY=sk_test_...
INVOQ_WEBHOOK_SECRET=whsec_...
```

Bắt đầu bằng khóa thử nghiệm. Khi chạy thật thì đổi sang khóa thật và mã bí mật webhook cho môi trường thật.

## Tạo một client

```ruby
require "invoq"

invoq = Invoq.new(ENV.fetch("INVOQ_SECRET_KEY"))
```

Origin API mặc định khi chạy thật:

```txt
https://api.invoq.money
```

Ghi đè origin API và thời gian chờ request khi phát triển:

```ruby
invoq = Invoq.new(
  ENV.fetch("INVOQ_SECRET_KEY"),
  api_origin: "http://localhost:8787",
  timeout_ms: 10_000
)
```

`api_origin` phải là một origin `http` hoặc `https` tuyệt đối, không có path, query, hash, username hay password. SDK sẽ nối thêm các đường dẫn tài nguyên `/v1/...`.

Mặc định request sẽ hết thời gian chờ sau 10 giây. Truyền `timeout_ms` để thay đổi thời gian chờ. `timeout_ms` phải là số nguyên dương tính bằng mili-giây.

## Hóa đơn

Tạo một hóa đơn:

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

Lưu ý:

- Số tiền phải do máy chủ quyết định. Đừng tin số tiền phía client gửi lên.
- `amount` là chuỗi thập phân USD từ `"0.01"` đến `"999.99"`, tối đa 2 chữ số lẻ, ví dụ `"129"` hoặc `"129.99"`.
- `currency` là tùy chọn và mặc định là `"USD"`.
- Dùng một `reference_id` ổn định, không rỗng để nối các webhook `invoice.paid` về đúng đơn hàng của bạn. Tạo lại với cùng `reference_id` và cùng nội dung hóa đơn sẽ trả về hóa đơn đã có; nếu nội dung khác nhau, API sẽ báo lỗi `409 reference_id_conflict`.
- Nếu bạn xử lý đơn hàng theo invoice ID thay vì `reference_id`, hãy lưu `invoice_id` cùng đơn hàng khi tạo hóa đơn.
- Bỏ qua `return_url` để dùng return URL mặc định của dự án. Truyền `nil` để gửi JSON `null` và tạo hóa đơn không có return URL. Khi thử lại theo `reference_id`, hãy truyền `return_url` một cách tường minh khi bạn cần khẳng định một giá trị cụ thể.
- `description` và `reference_id` phải là chuỗi khi được cung cấp.

Lấy một hóa đơn:

```ruby
invoice = invoq.invoices.get("inv_123")
```

`invoices.get` trả về dạng hóa đơn công khai mà trang checkout được host sử dụng. Nó bao gồm các trường như `amount_paid`, `amount_due`, `amount_overpaid`, `payment_status`, `project`, `deposit_address`, `monitoring_ends_at`, `monitoring_status`, `transfers` và `direct_onchain_rails`, nhưng không bao gồm `reference_id`. Hãy dùng phản hồi tạo hóa đơn hoặc webhook `invoice.paid` khi bạn cần `reference_id` phía merchant.

Tạo một thanh toán thử nghiệm:

```ruby
paid_invoice = invoq.invoices.create_test_payment(
  "inv_123",
  amount: "129",
  reference_id: "test_payment_001"
)
```

Hóa đơn thử nghiệm không nhận được tiền thật. Hãy mô phỏng thanh toán từ máy chủ của bạn.

`create_test_payment` chỉ dùng được với hóa đơn tạo bằng khóa `sk_test_`. Có thể trả từng phần và hóa đơn sẽ thành `partially_paid`; khi số tiền thanh toán đạt đủ giá trị hóa đơn, invoq gửi một webhook `invoice.paid` có chữ ký đến URL webhook thử nghiệm của bạn.

`reference_id` là tùy chọn với các thanh toán thử nghiệm. Hãy bỏ qua khi không đặt; đừng truyền `nil`.

Để nhận webhook trên máy của mình, hãy mở máy chủ local ra ngoài bằng một tunnel HTTPS như ngrok hay cloudflared, rồi lưu URL tunnel làm URL webhook thử nghiệm trong bảng điều khiển. Bảng điều khiển cũng gửi được một `webhook.ping` có chữ ký để kiểm tra kết nối.

Mỗi phương thức hóa đơn trả về trực tiếp đối tượng `data` của phản hồi dưới dạng một hash Ruby.

## Trang thanh toán được lưu trữ sẵn

Mỗi hóa đơn còn có một trang thanh toán được lưu trữ sẵn tại:

```txt
https://pay.invoq.money/<invoice id>
```

Hãy gửi link hoặc chuyển hướng sang đó khi cửa sổ thanh toán nhúng trong trang không phù hợp.

## Đầu vào và phản hồi

SDK kiểm tra rằng các giá trị `amount` và các tham số `invoice_id` là chuỗi không rỗng trước khi gửi request. API của invoq xác thực định dạng, khoảng giá trị và loại tiền tệ của số tiền.

Đừng đưa các trường tùy chọn không dùng đến vào hash request. Nếu bạn đưa vào `description` hoặc `reference_id`, hãy truyền một chuỗi. `return_url` có thể là một chuỗi hoặc `nil`.

Số tiền trong phản hồi được chuẩn hóa về 4 chữ số lẻ: tạo với `"129"` thì hóa đơn trả về `amount: "129.0000"`. So sánh số tiền theo giá trị số, đừng so sánh chuỗi. `amount_due` được tính là `max(amount - amount_paid, 0)` và dùng cùng thang 18 chữ số thập phân như `amount_paid`; `amount_overpaid` là bản đối xứng của nó, `max(amount_paid - amount, 0)`, nên bạn không bao giờ phải tự trừ tiền. `monitoring_status` là `"active"` hoặc `"ended"` — khi đã là `"ended"`, địa chỉ nạp tiền không còn được theo dõi nữa — còn `transfers` là danh sách biên nhận trên chuỗi đã xác nhận (mỗi mục có `tx_hash`, `amount` và `explorer_tx_url`). Cả hai đều là `nil` / `[]` với hóa đơn thử nghiệm.

## Webhook

Truyền nội dung request gốc cho `verify_webhook`. Đừng phân tích JSON rồi mã hóa lại trước khi xác minh.

Ví dụ Rack này trả về `[status, headers, body]`. Trong Rails, dùng `request.raw_post` và `request.get_header("HTTP_INVOQ_SIGNATURE")`; trong Sinatra hoặc framework Ruby khác, dùng nội dung request gốc của framework và header `invoq-signature` hoặc `HTTP_INVOQ_SIGNATURE` mà nó cung cấp.

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

    # Xử lý đơn hàng cho fulfillment_key một cách an toàn khi lặp lại.
  end

  [
    200,
    { "content-type" => "application/json" },
    ['{"received":true}']
  ]
end
```

Hãy dùng webhook `invoice.paid` để xử lý đơn hàng trên máy chủ của bạn. Kết quả checkout trên trình duyệt chỉ dùng để cập nhật trải nghiệm khách hàng; đừng xử lý đơn hàng dựa trên kết quả từ trình duyệt.

Khi `Invoq.invoice_paid?(event)` là true, hóa đơn đã sẵn sàng để xử lý tự động; dùng `reference_id` của hóa đơn hoặc `id` hóa đơn đã lưu để tìm và xử lý đúng đơn. Hóa đơn ở trạng thái `review_required` hiện chưa gửi webhook `invoice.paid`. Nếu checkout trả về `review_required`, hãy hiển thị trạng thái chờ duyệt và đợi webhook `invoice.paid` sau khi được duyệt.

Quan trọng:

- Truyền đúng chuỗi nội dung request gốc mà framework Ruby của bạn nhận được.
- Truyền header `invoq-signature`.
- `verify_webhook` không cần `Invoq.new(...)` hay khóa bí mật API invoq của bạn.
- Dùng mã bí mật webhook (`whsec_...`) của bạn, không phải `INVOQ_SECRET_KEY`.
- Hãy làm cho việc xử lý đơn an toàn khi lặp lại. Các lần gửi lại webhook có thể gửi cùng một sự kiện nhiều lần.
- Trả về 2xx thật nhanh. Mọi mã trạng thái khác đều bị tính là giao thất bại. Các lỗi tạm thời như timeout, `429` và `5xx` sẽ được gửi lại; các phản hồi `4xx` khác thì không.

`Invoq.invoice_paid?` chấp nhận các sự kiện `invoice.paid` có thể xử lý mà trạng thái hóa đơn là `paid`, `settling` hoặc `settled`, và từ chối `review_required`.

Việc xác minh webhook thất bại sẽ ném `Invoq::SignatureVerificationError`. SDK cho phép timestamp lệch tối đa 5 phút. Header chữ ký có dạng:

```txt
invoq-signature: t=<unix seconds>,v1=<hex HMAC-SHA256 of "<t>.<raw body>">
```

## Lỗi

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

Các phản hồi API không phải 2xx sẽ ném `Invoq::ApiError` kèm `status`, `code`, `fields`, `meta` và `payload` gốc.

Lỗi kết nối, hết thời gian chờ, đầu vào không hợp lệ và lỗi phân tích phản hồi sẽ ném `Invoq::Error`. Việc tạo hóa đơn bị hết thời gian chờ có thể thử lại an toàn với cùng `reference_id`.

Việc xác minh webhook thất bại sẽ ném `Invoq::SignatureVerificationError` với một trong các mã sau:

```txt
missing_signature
invalid_signature_header
timestamp_outside_tolerance
signature_mismatch
invalid_payload
```

## Phát triển

```sh
bundle exec rake test
```

## Giấy phép

Được cấp phép theo giấy phép MIT.
