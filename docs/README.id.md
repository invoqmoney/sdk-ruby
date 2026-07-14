# invoq Ruby SDK

[English](../README.md) · **Bahasa Indonesia** · [Español](./README.es-419.md) · [Français](./README.fr.md) · [Português](./README.pt-BR.md) · [Tiếng Việt](./README.vi.md) · [Türkçe](./README.tr.md) · [ไทย](./README.th.md) · [简体中文](./README.zh-Hans.md) · [繁體中文](./README.zh-Hant.md)

> Dokumen ini terjemahan dari README bahasa Inggris; kalau ada perbedaan, [versi bahasa Inggris](../README.md) yang berlaku.

Terima pembayaran stablecoin dengan invoq dari kode server Ruby. SDK ini membungkus API server invoq dan memverifikasi webhook bertanda tangan.

Gunakan gem ini hanya di server Anda. Gem ini menangani kunci rahasia dan tidak boleh disertakan ke dalam kode browser.

## SDK server

Buat invoice dan verifikasi webhook dari backend Anda dalam bahasa mana pun berikut — REST API dan tanda tangan webhook-nya sama persis. Repo ini adalah SDK Ruby.

| Bahasa | Repositori |
| --- | --- |
| Node.js | [github.com/invoqmoney/sdk-js](https://github.com/invoqmoney/sdk-js) (`@invoq/server`) |
| Python | [github.com/invoqmoney/sdk-python](https://github.com/invoqmoney/sdk-python) |
| PHP | [github.com/invoqmoney/sdk-php](https://github.com/invoqmoney/sdk-php) |
| Go | [github.com/invoqmoney/sdk-go](https://github.com/invoqmoney/sdk-go) |
| Rust | [github.com/invoqmoney/sdk-rust](https://github.com/invoqmoney/sdk-rust) |
| Ruby | **repo ini** |

Sisi browser-nya sama untuk setiap backend: **`@invoq/checkout`** (JavaScript, di [github.com/invoqmoney/sdk-js](https://github.com/invoqmoney/sdk-js)) membuka jendela checkout yang tertanam di halaman untuk frontend apa pun.

## Instalasi

Pasang gem:

```sh
gem install invoq
```

Atau tambahkan ke Gemfile:

```ruby
gem "invoq"
```

Membutuhkan Ruby 2.6 atau lebih baru.

## Siapkan kunci Anda

1. Masuk ke [dashboard invoq](https://app.invoq.money) dan buat sebuah proyek.
2. Di halaman **API keys**, buat kunci rahasia (secret key). Kunci uji coba diawali `sk_test_`, kunci produksi diawali `sk_live_`. Mode kuncinya menentukan apakah invoice bersifat uji coba atau produksi.
3. Di pengaturan **webhooks** proyek Anda, simpan URL webhook Anda. Kunci rahasia webhook (`whsec_...`) untuk mode itu hanya ditampilkan sekali, saat webhook pertama kali diaktifkan — langsung simpan. URL webhook harus berupa URL HTTPS yang bisa diakses publik.

Tambahkan keduanya ke lingkungan server Anda:

```sh
INVOQ_SECRET_KEY=sk_test_...
INVOQ_WEBHOOK_SECRET=whsec_...
```

Mulailah dengan kunci uji coba. Ganti ke kunci produksi dan kunci rahasia webhook produksi saat masuk produksi.

## Buat klien

```ruby
require "invoq"

invoq = Invoq.new(ENV.fetch("INVOQ_SECRET_KEY"))
```

Origin API produksi bawaan:

```txt
https://api.invoq.money
```

Timpa origin API dan timeout request saat pengembangan:

```ruby
invoq = Invoq.new(
  ENV.fetch("INVOQ_SECRET_KEY"),
  api_origin: "http://localhost:8787",
  timeout_ms: 10_000
)
```

`api_origin` harus berupa origin `http` atau `https` absolut tanpa path, query, hash, username, atau password. SDK menambahkan path resource `/v1/...`.

Request akan timeout setelah 10 detik secara bawaan. Berikan `timeout_ms` untuk mengubah timeout. `timeout_ms` harus berupa bilangan bulat positif dalam milidetik.

## Invoice

Buat invoice:

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

Catatan:

- Gunakan jumlah dari sisi server. Jangan percaya jumlah yang dikirim klien.
- `amount` adalah string desimal USD dari `"0.01"` sampai `"999.99"` dengan maksimal 2 angka di belakang koma, misalnya `"129"` atau `"129.99"`.
- `currency` bersifat opsional dan bawaannya `"USD"`.
- Gunakan `reference_id` yang stabil dan tidak kosong untuk memetakan webhook `invoice.paid` kembali ke pesanan Anda. Membuat lagi dengan `reference_id` dan ketentuan invoice yang sama mengembalikan invoice yang sudah ada; ketentuan yang berbeda gagal dengan error API `409 reference_id_conflict`.
- Jika Anda memproses pesanan berdasarkan ID invoice alih-alih `reference_id`, simpan `invoice_id` bersama pesanan Anda saat membuat invoice.
- Hilangkan `return_url` untuk memakai return URL bawaan proyek. Berikan `nil` untuk mengirim JSON `null` dan membuat invoice tanpa return URL. Saat mengulang dengan `reference_id`, berikan `return_url` secara eksplisit jika Anda perlu memastikan nilai tertentu.
- `description` dan `reference_id` harus berupa string jika disertakan.

Ambil invoice:

```ruby
invoice = invoq.invoices.get("inv_123")
```

`invoices.get` mengembalikan bentuk invoice publik yang dipakai halaman checkout yang dihosting. Ini mencakup field seperti `amount_paid`, `amount_due`, `payment_status`, `project`, `deposit_address`, `monitoring_ends_at`, dan `direct_onchain_rails`, tetapi tidak menyertakan `reference_id`. Gunakan respons pembuatan atau webhook `invoice.paid` saat Anda membutuhkan `reference_id` merchant Anda.

Buat pembayaran uji coba:

```ruby
paid_invoice = invoq.invoices.create_test_payment(
  "inv_123",
  amount: "129",
  reference_id: "test_payment_001"
)
```

Invoice uji coba tidak bisa menerima dana sungguhan. Sebagai gantinya, simulasikan pembayaran dari server Anda.

`create_test_payment` hanya bekerja pada invoice yang dibuat dengan kunci `sk_test_`. Jumlah parsial diperbolehkan dan menghasilkan `partially_paid`; begitu pembayaran mencapai jumlah invoice, invoq mengirim webhook `invoice.paid` bertanda tangan ke URL webhook uji coba Anda.

`reference_id` bersifat opsional untuk pembayaran uji coba. Hilangkan saja saat tidak diisi; jangan berikan `nil`.

Untuk menerima webhook di mesin Anda sendiri, buka server lokal lewat tunnel HTTPS seperti ngrok atau cloudflared, lalu simpan URL tunnel-nya sebagai URL webhook uji coba di dashboard. Dashboard juga bisa mengirim `webhook.ping` bertanda tangan untuk mengecek koneksi.

Setiap metode invoice mengembalikan objek `data` dari respons secara langsung sebagai hash Ruby.

## Halaman checkout yang dihosting

Setiap invoice juga punya halaman checkout yang dihosting di:

```txt
https://pay.invoq.money/<invoice id>
```

Bagikan tautannya atau alihkan ke sana kalau jendela checkout dalam halaman kurang pas.

## Input dan respons

SDK memeriksa bahwa nilai `amount` dan argumen `invoice_id` berupa string yang tidak kosong sebelum mengirim request. API invoq memvalidasi format, rentang, dan mata uang dari jumlah tersebut.

Jangan masukkan field opsional yang tidak diisi ke dalam hash request. Saat Anda menyertakan `description` atau `reference_id`, berikan sebuah string. `return_url` bisa berupa string atau `nil`.

Jumlah di respons dinormalkan ke 4 angka desimal: buat dengan `"129"` dan invoice mengembalikan `amount: "129.0000"`. Bandingkan jumlah secara numerik, bukan sebagai string. `amount_due` diturunkan sebagai `max(amount - amount_paid, 0)` dan memakai skala 18 desimal yang sama dengan `amount_paid`.

## Webhook

Berikan isi request mentah ke `verify_webhook`. Jangan mem-parse JSON lalu meng-encode-nya lagi sebelum verifikasi.

Contoh Rack ini mengembalikan `[status, headers, body]`. Di Rails, gunakan `request.raw_post` dan `request.get_header("HTTP_INVOQ_SIGNATURE")`; di Sinatra atau framework Ruby lain, gunakan isi request mentah dari framework tersebut dan header `invoq-signature` atau `HTTP_INVOQ_SIGNATURE` yang diekspos.

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

    # Proses pesanan untuk fulfillment_key secara idempoten.
  end

  [
    200,
    { "content-type" => "application/json" },
    ['{"received":true}']
  ]
end
```

Gunakan webhook `invoice.paid` untuk memproses pesanan di server Anda. Hasil checkout di browser hanya untuk memperbarui pengalaman pelanggan; jangan memproses pesanan dari hasil browser.

Saat `Invoq.invoice_paid?(event)` bernilai true, invoice siap diproses otomatis; pakai `reference_id` invoice atau `id` invoice yang tersimpan untuk menemukan dan memproses pesanan Anda. Invoice `review_required` belum mengirim webhook `invoice.paid`. Jika checkout melaporkan `review_required`, tampilkan status menunggu peninjauan dan tunggu webhook `invoice.paid` berikutnya setelah peninjauan disetujui.

Penting:

- Berikan string isi request mentah yang persis diterima framework Ruby Anda.
- Berikan header `invoq-signature`.
- `verify_webhook` tidak memerlukan `Invoq.new(...)` atau kunci rahasia API invoq Anda.
- Gunakan kunci rahasia webhook (`whsec_...`) Anda, bukan `INVOQ_SECRET_KEY`.
- Buat pemrosesan pesanan bersifat idempoten. Pengiriman webhook yang diulang bisa mengirim event yang sama lebih dari sekali.
- Balas dengan 2xx secepatnya. Status lain apa pun dihitung sebagai pengiriman gagal. Kegagalan sementara seperti timeout, `429`, dan respons `5xx` akan diulang; respons `4xx` lain tidak.

`Invoq.invoice_paid?` menerima event `invoice.paid` yang bisa diproses dengan status invoice `paid`, `settling`, atau `settled`; fungsi ini menolak `review_required`.

Kegagalan verifikasi webhook melempar `Invoq::SignatureVerificationError`. SDK memberi toleransi timestamp selama 5 menit. Header tanda tangannya adalah:

```txt
invoq-signature: t=<unix seconds>,v1=<hex HMAC-SHA256 of "<t>.<raw body>">
```

## Error

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

Respons API non-2xx melempar `Invoq::ApiError` dengan `status`, `code`, `fields`, `meta`, dan `payload` mentah.

Kegagalan koneksi, timeout, input tidak valid, dan kegagalan mem-parse respons melempar `Invoq::Error`. Pembuatan invoice yang timeout aman diulang dengan `reference_id` yang sama.

Kegagalan verifikasi webhook melempar `Invoq::SignatureVerificationError` dengan salah satu kode berikut:

```txt
missing_signature
invalid_signature_header
timestamp_outside_tolerance
signature_mismatch
invalid_payload
```

## Pengembangan

```sh
bundle exec rake test
```

## Lisensi

Dilisensikan di bawah lisensi MIT.
