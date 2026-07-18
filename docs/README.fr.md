# SDK Ruby invoq

[English](../README.md) · [Bahasa Indonesia](./README.id.md) · [Español](./README.es-419.md) · **Français** · [Português](./README.pt-BR.md) · [Tiếng Việt](./README.vi.md) · [Türkçe](./README.tr.md) · [ไทย](./README.th.md) · [简体中文](./README.zh-Hans.md) · [繁體中文](./README.zh-Hant.md)

> Ce document est une traduction du README anglais ; en cas de divergence, la [version anglaise](../README.md) fait foi.

Acceptez des paiements en stablecoins avec invoq depuis du code serveur Ruby. Ce SDK encapsule les API serveur d’invoq et vérifie les webhooks signés.

N’utilisez cette gem que sur votre serveur. Elle gère des clés secrètes et ne doit pas être incluse dans le code du navigateur.

## SDK serveur

Créez des factures et vérifiez les webhooks depuis votre backend dans l’un de ces langages — même REST API, même signature de webhook. Ce dépôt est le SDK Ruby.

| Langage | Dépôt |
| --- | --- |
| Node.js | [github.com/invoqmoney/sdk-js](https://github.com/invoqmoney/sdk-js) (`@invoq/server`) |
| Python | [github.com/invoqmoney/sdk-python](https://github.com/invoqmoney/sdk-python) |
| PHP | [github.com/invoqmoney/sdk-php](https://github.com/invoqmoney/sdk-php) |
| Go | [github.com/invoqmoney/sdk-go](https://github.com/invoqmoney/sdk-go) |
| Rust | [github.com/invoqmoney/sdk-rust](https://github.com/invoqmoney/sdk-rust) |
| Ruby | **ce dépôt** |

Quel que soit le backend, le côté navigateur reste le même : **`@invoq/checkout`** (en JavaScript, dans [github.com/invoqmoney/sdk-js](https://github.com/invoqmoney/sdk-js)) ouvre la fenêtre de paiement intégrée à la page pour n’importe quel frontend.

## Installation

Installez la gem :

```sh
gem install invoq
```

Ou ajoutez-la à un Gemfile :

```ruby
gem "invoq"
```

Nécessite Ruby 2.6 ou plus récent.

## Récupérez vos clés

1. Connectez-vous au [tableau de bord invoq](https://app.invoq.money) et créez un projet.
2. Sur la page **API keys**, créez une clé secrète. Les clés de test commencent par `sk_test_`, les clés de production par `sk_live_`. Le mode de la clé détermine si les factures sont de test ou de production.
3. Dans les réglages **webhooks** de votre projet, enregistrez votre URL de webhook. Le secret du webhook (`whsec_...`) pour ce mode ne s’affiche qu’une seule fois, à la première activation du webhook — notez-le tout de suite. L’URL du webhook doit être une URL HTTPS publique.

Ajoutez les deux à l’environnement de votre serveur :

```sh
INVOQ_SECRET_KEY=sk_test_...
INVOQ_WEBHOOK_SECRET=whsec_...
```

Commencez avec les clés de test. Passez à la clé de production et au secret de webhook de production au moment de la mise en production.

## Créez un client

```ruby
require "invoq"

invoq = Invoq.new(ENV.fetch("INVOQ_SECRET_KEY"))
```

Origine par défaut de l’API en production :

```txt
https://api.invoq.money
```

Surchargez l’origine de l’API et le délai des requêtes en développement :

```ruby
invoq = Invoq.new(
  ENV.fetch("INVOQ_SECRET_KEY"),
  api_origin: "http://localhost:8787",
  timeout_ms: 10_000
)
```

`api_origin` doit être une origine `http` ou `https` absolue, sans chemin, paramètres de requête, fragment, nom d’utilisateur ni mot de passe. Le SDK y ajoute les chemins de ressources `/v1/...`.

Les requêtes expirent au bout de 10 secondes par défaut. Passez `timeout_ms` pour modifier ce délai. `timeout_ms` doit être un entier positif en millisecondes.

## Factures

Créez une facture :

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

Notes :

- Utilisez un montant défini côté serveur. Ne faites pas confiance aux montants envoyés par le client.
- `amount` est une chaîne décimale en USD de `"0.01"` à `"1000000.00"`, avec au plus 2 décimales, comme `"129"` ou `"129.99"`.
- `currency` est optionnel et vaut `"USD"` par défaut.
- Utilisez un `reference_id` stable et non vide pour relier les webhooks `invoice.paid` à votre commande. Recréer avec le même `reference_id` et les mêmes conditions de facture renvoie la facture existante ; des conditions différentes échouent avec une erreur d’API `409 reference_id_conflict`.
- Si vous traitez la commande par ID de facture plutôt que par `reference_id`, enregistrez `invoice_id` avec votre commande au moment de créer la facture.
- Omettez `return_url` pour utiliser l’URL de retour par défaut du projet. Passez `nil` pour envoyer `null` en JSON et créer la facture sans URL de retour. Lors des relances avec le même `reference_id`, passez `return_url` explicitement quand vous devez garantir une valeur spécifique.
- `description` et `reference_id` doivent être des chaînes lorsqu’ils sont présents.

Récupérez une facture :

```ruby
invoice = invoq.invoices.get("inv_123")
```

`invoices.get` renvoie la forme de facture publique utilisée par la page de checkout hébergée. Elle inclut des champs tels que `amount_paid`, `amount_due`, `amount_overpaid`, `payment_status`, `project`, `deposit_address`, `monitoring_ends_at`, `monitoring_status`, `transfers` et `direct_onchain_rails`, mais n’inclut pas `reference_id`. Utilisez la réponse de création ou le webhook `invoice.paid` quand vous avez besoin de votre `reference_id` marchand.

Créez un paiement de test :

```ruby
paid_invoice = invoq.invoices.create_test_payment(
  "inv_123",
  amount: "129",
  reference_id: "test_payment_001"
)
```

Les factures de test ne peuvent pas recevoir de vrais fonds. Simulez plutôt les paiements depuis votre serveur.

`create_test_payment` ne fonctionne que sur les factures créées avec une clé `sk_test_`. Les montants partiels sont autorisés et produisent `partially_paid` ; quand les paiements atteignent le montant de la facture, invoq envoie un webhook `invoice.paid` signé à votre URL de webhook de test.

`reference_id` est optionnel pour les paiements de test. Omettez-le quand il n’est pas défini ; ne passez pas `nil`.

Pour recevoir des webhooks sur votre machine, exposez votre serveur local via un tunnel HTTPS comme ngrok ou cloudflared, et enregistrez l’URL du tunnel comme URL de webhook de test dans le tableau de bord. Le tableau de bord peut aussi envoyer un `webhook.ping` signé pour vérifier la connectivité.

Chaque méthode de facture renvoie directement l’objet `data` de la réponse sous forme de hash Ruby.

## Page de paiement hébergée

Chaque facture dispose aussi d’une page de paiement hébergée à l’adresse :

```txt
https://pay.invoq.money/<invoice id>
```

Partagez le lien ou redirigez-y quand une fenêtre de paiement intégrée à la page ne convient pas.

## Entrées et réponses

Le SDK vérifie que les valeurs `amount` et les arguments `invoice_id` sont des chaînes non vides avant d’envoyer les requêtes. L’API invoq valide le format, la plage et la devise du montant.

Laissez les champs optionnels non définis en dehors du hash de requête. Quand vous incluez `description` ou `reference_id`, passez une chaîne. `return_url` peut être une chaîne ou `nil`.

Les montants des réponses sont normalisés à 4 décimales : créez avec `"129"` et la facture renvoie `amount: "129.0000"`. Comparez les montants numériquement, pas comme des chaînes. `amount_due` est dérivé sous la forme `max(amount - amount_paid, 0)` et utilise la même échelle à 18 décimales que `amount_paid` ; `amount_overpaid` en est le miroir, `max(amount_paid - amount, 0)`, si bien que vous n’avez jamais à soustraire d’argent vous-même. `monitoring_status` vaut `"active"` ou `"ended"` — une fois à `"ended"`, l’adresse de dépôt n’est plus surveillée — et `transfers` est le journal confirmé des encaissements on-chain (chaque entrée a `tx_hash`, `amount` et `explorer_tx_url`). Les deux valent `nil` / `[]` pour les factures de test.

## Webhooks

Passez le corps brut de la requête à `verify_webhook`. N’analysez pas le JSON pour le ré-encoder avant la vérification.

Cet exemple Rack renvoie `[status, headers, body]`. Sous Rails, utilisez `request.raw_post` et `request.get_header("HTTP_INVOQ_SIGNATURE")` ; sous Sinatra ou un autre framework Ruby, utilisez le corps brut de la requête fourni par le framework et l’en-tête `invoq-signature` ou `HTTP_INVOQ_SIGNATURE` qu’il expose.

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

    # Traitez la commande pour fulfillment_key de façon idempotente.
  end

  [
    200,
    { "content-type" => "application/json" },
    ['{"received":true}']
  ]
end
```

Utilisez les webhooks `invoice.paid` pour traiter les commandes sur votre serveur. Les résultats du checkout dans le navigateur ne servent qu’à mettre à jour l’expérience client ; ne traitez pas les commandes à partir des résultats du navigateur.

Quand `Invoq.invoice_paid?(event)` est vrai, la facture peut être traitée automatiquement ; utilisez le `reference_id` de la facture ou un `id` de facture enregistré pour retrouver et traiter votre commande. Une facture `review_required` n’émet pas encore de webhook `invoice.paid`. Si le checkout renvoie `review_required`, affichez un état en attente de vérification et attendez un webhook `invoice.paid` ultérieur après validation.

Important :

- Passez exactement la chaîne du corps brut de la requête reçue par votre framework Ruby.
- Passez l’en-tête `invoq-signature`.
- `verify_webhook` ne nécessite ni `Invoq.new(...)` ni votre clé secrète d’API invoq.
- Utilisez votre secret de webhook (`whsec_...`), pas `INVOQ_SECRET_KEY`.
- Rendez le traitement idempotent. Les livraisons de webhook retentées peuvent envoyer le même événement plusieurs fois.
- Répondez rapidement avec un 2xx. Tout autre statut compte comme une livraison échouée. Les échecs transitoires comme les délais dépassés, `429` et les réponses `5xx` sont retentés ; les autres réponses `4xx` ne le sont pas.

`Invoq.invoice_paid?` accepte les événements `invoice.paid` traitables dont le statut de facture est `paid`, `settling` ou `settled` ; il rejette `review_required`.

Les échecs de vérification de webhook lèvent `Invoq::SignatureVerificationError`. Le SDK tolère un décalage d’horodatage de 5 minutes. L’en-tête de signature est :

```txt
invoq-signature: t=<unix seconds>,v1=<hex HMAC-SHA256 of "<t>.<raw body>">
```

## Erreurs

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

Les réponses d’API non 2xx lèvent `Invoq::ApiError` avec `status`, `code`, `fields`, `meta` et le `payload` brut.

Les échecs de connexion, les délais d’attente dépassés, les entrées invalides et les échecs d’analyse de la réponse lèvent `Invoq::Error`. Une création de facture expirée peut être réessayée sans risque avec le même `reference_id`.

Les échecs de vérification de webhook lèvent `Invoq::SignatureVerificationError` avec l’un de ces codes :

```txt
missing_signature
invalid_signature_header
timestamp_outside_tolerance
signature_mismatch
invalid_payload
```

## Développement

```sh
bundle exec rake test
```

## Licence

Distribué sous licence MIT.
