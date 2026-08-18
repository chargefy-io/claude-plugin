---
name: testar-pagamentos
description: Cartões determinísticos do sandbox da Chargefy para simular aprovação, recusa, captura pendente, processamento assíncrono e reúso de cartão salvo em test mode (chave ch_test_). Use ao testar checkout, cobrança, decline codes, insufficient_funds, authentication_required, retentativa ou webhook de falha.
---

<!-- Gerado por `pnpm claude-plugin:build` a partir de sandbox-card-scenarios.js e payment-decline-codes.ts. Não edite à mão. -->

# Testar pagamentos no sandbox da Chargefy

O sandbox é a produção com dinheiro de mentira: mesmos endpoints, mesmos
objetos, mesmos webhooks. O que separa os dois mundos é a chave usada na
chamada — `ch_test_` cria e consulta dados de teste (`livemode: false`),
`ch_live_` cria e consulta dados de produção.

Os números desta página escolhem o desfecho do pagamento **somente em test
mode**. Em live mode são tratados como cartões comuns.

## Como usar

- Use qualquer CVC de três dígitos e uma validade futura.
- Cartão desconhecido em test mode **aprova** por padrão.
- Funciona no checkout hospedado, no Chargefy.js, na página de pagamento de
  fatura e nos formulários de atualização de cartão.
- Uma recusa encerra a tentativa, não o intent: o Payment Intent volta a
  `requires_payment_method` com o motivo em `last_payment_error`, e o mesmo
  intent aceita nova confirmação. É assim que se testa recusa seguida de
  retentativa.
- Em `processing` e `pending` ainda não há desfecho. Não trate ausência de
  erro como aprovação: espere o webhook.

O código estável fica em `payment_error.code`, com a orientação em
`payment_error.advice_code`. A coluna **Retentável** abaixo diz se repetir a
mesma cobrança tem chance de mudar o resultado — recusa não retentável exige
outro meio de pagamento.

## Sucesso e status

| Cartão             | Cenário            | Status resultante  |
| ------------------ | ------------------ | ------------------ |
| `4242424242424242` | `succeeded`        | `succeeded`        |
| `4000000000003220` | `requires_capture` | `requires_capture` |
| `4000009000000425` | `processing`       | `processing`       |
| `4000009000000433` | `pending`          | `pending`          |

## Cartões salvos e reúso

Estes aprovam a primeira cobrança; o comportamento especial só aparece quando o
mesmo cartão é cobrado de novo como cartão salvo — por exemplo, numa oferta
posterior de um funil.

- `4000009000000623` — Aprova a primeira cobrança e pode ser salvo. Ao cobrar o cartão salvo de novo, volta a `requires_payment_method` com `payment_error.code` igual a `single_use_card`.
- `4000009000000631` — Aprova a primeira cobrança e pode ser salvo. Ao cobrar o cartão salvo de novo, fica em `processing`: aguarde o webhook e não inicie outra tentativa.

## Falhas simuladas

Cada cartão devolve `requires_payment_method` com o `payment_error` da linha.
Alguns códigos nascem, em produção, em etapas como captura, tokenização ou
reembolso; no sandbox o cartão serve para exercitar o contrato público e a
mensagem, não a etapa operacional que originou o erro.

### Recusa do emissor (`issuer_declined`)

| Cartão             | `payment_error.code`        | Retentável | Mensagem                                                       |
| ------------------ | --------------------------- | ---------- | -------------------------------------------------------------- |
| `4000000000009995` | `insufficient_funds`        | sim        | The card has insufficient funds to complete the purchase.      |
| `4000009000000011` | `do_not_honor`              | sim        | The issuer declined the transaction without a specific reason. |
| `4000000000000002` | `generic_decline`           | não        | The card was declined.                                         |
| `4000009000000029` | `call_issuer`               | sim        | The card was declined. The cardholder must contact the issuer. |
| `4000009000000037` | `card_velocity_exceeded`    | sim        | The card exceeded its balance, credit, or transaction limit.   |
| `4000009000000045` | `invalid_amount`            | não        | The transaction amount is not allowed for this card.           |
| `4000009000000052` | `invalid_account`           | sim        | The account linked to the card is invalid or does not exist.   |
| `4000009000000060` | `transaction_not_permitted` | não        | This type of transaction is not permitted for the cardholder.  |
| `4000009000000078` | `service_not_allowed`       | sim        | This transaction is not permitted for the card.                |
| `4000009000000086` | `card_not_supported`        | não        | The card does not support this type of purchase.               |
| `4000009000000094` | `currency_not_supported`    | sim        | The card does not support the transaction currency.            |
| `4000009000000102` | `card_not_activated`        | sim        | The card has not been activated.                               |
| `4000009000000110` | `authentication_required`   | não        | The transaction requires cardholder authentication.            |
| `4000009000000128` | `reenter_transaction`       | sim        | The issuer could not process the transaction. Try again.       |
| `4000009000000136` | `approve_with_id`           | sim        | The payment could not be authorized.                           |
| `4000009000000144` | `not_permitted`             | sim        | The requested operation is not supported by the card.          |
| `4000009000000409` | `testmode_decline`          | sim        | A test card triggered a decline.                               |
| `4000009000000417` | `payment_failed`            | sim        | Payment failed.                                                |

### Erro de processamento (`processing_error`)

| Cartão             | `payment_error.code`              | Retentável | Mensagem                                                     |
| ------------------ | --------------------------------- | ---------- | ------------------------------------------------------------ |
| `4000009000000441` | `authentication_not_available`    | não        | Cardholder authentication is not available for this payment. |
| `4000009000000342` | `issuer_unavailable`              | sim        | The card issuer could not be reached. Try again.             |
| `4000009000000359` | `routing_error`                   | sim        | The transaction could not be routed to the issuer.           |
| `4000009000000367` | `duplicate_transaction`           | sim        | A duplicate transaction was detected.                        |
| `4000009000000375` | `try_again_later`                 | sim        | The payment could not be processed. Try again later.         |
| `4000009000000383` | `connection_error`                | sim        | Could not reach the payment provider. Please try again.      |
| `4000009000000391` | `customer_unavailable`            | sim        | Customer could not be identified for the charge.             |
| `4000000000000119` | `processing_error`                | sim        | An error occurred while processing the payment. Try again.   |
| `4000009000000532` | `merchant_not_approved`           | não        | The merchant account is not available for this payment.      |
| `4000009000000540` | `authorization_expired`           | não        | The authorization expired before capture.                    |
| `4000009000000557` | `capture_method_not_supported`    | não        | The selected capture method is not supported.                |
| `4000009000000565` | `charge_already_captured`         | não        | The payment was already captured.                            |
| `4000009000000573` | `charge_already_refunded`         | não        | The payment was already refunded.                            |
| `4000009000000581` | `partial_refund_not_supported`    | não        | This payment does not support partial refunds.               |
| `4000009000000599` | `payment_intent_unexpected_state` | não        | The operation is not allowed in the payment's current state. |
| `4000009000000607` | `refund_period_expired`           | não        | The refund window for this payment has expired.              |
| `4000009000000615` | `refund_state_mismatch`           | não        | The refund state could not be reconciled.                    |

### Dados inválidos (`invalid`)

| Cartão             | `payment_error.code`                | Retentável | Mensagem                                                 |
| ------------------ | ----------------------------------- | ---------- | -------------------------------------------------------- |
| `4000009000000458` | `new_account_information_available` | sim        | Updated card or account information is required.         |
| `4000000000000069` | `expired_card`                      | não        | The card has expired.                                    |
| `4000000000000127` | `incorrect_cvc`                     | não        | The card security code (CVC) is incorrect.               |
| `4000009000000151` | `incorrect_number`                  | não        | The card number is incorrect.                            |
| `4000009000000169` | `invalid_number`                    | não        | The card number is invalid or the issuer does not exist. |
| `4000009000000177` | `incorrect_pin`                     | sim        | The card PIN is incorrect.                               |
| `4000009000000185` | `invalid_pin`                       | sim        | The card PIN is invalid.                                 |
| `4000009000000193` | `pin_try_exceeded`                  | sim        | The allowable number of PIN tries was exceeded.          |
| `4000009000000201` | `invalid_transaction`               | sim        | The transaction is invalid.                              |
| `4000009000000219` | `no_payment_method`                 | sim        | No payment method available to charge.                   |
| `4000009000000227` | `card_unusable`                     | sim        | The saved card could not be used.                        |
| `4000009000000235` | `payment_method_mismatch`           | sim        | The payment method does not belong to this customer.     |
| `4000009000000466` | `invalid_cvc`                       | sim        | The card security code has an invalid format.            |
| `4000009000000474` | `invalid_expiry_month`              | sim        | The card expiration month has an invalid format.         |
| `4000009000000482` | `invalid_expiry_year`               | sim        | The card expiration year has an invalid format.          |
| `4000009000000490` | `invalid_name`                      | sim        | The cardholder name is invalid.                          |
| `4000009000000508` | `invalid_request`                   | sim        | The payment request contains invalid data.               |
| `4000009000000516` | `invalid_token`                     | sim        | The card token is invalid or expired.                    |

### Bloqueio e prevenção (`blocked`)

| Cartão             | `payment_error.code`               | Retentável | Mensagem                                               |
| ------------------ | ---------------------------------- | ---------- | ------------------------------------------------------ |
| `4000009000000243` | `lost_card`                        | não        | The card was reported lost.                            |
| `4000009000000250` | `stolen_card`                      | não        | The card was reported stolen.                          |
| `4000009000000268` | `pickup_card`                      | não        | The card cannot be used (retain card).                 |
| `4000009000000276` | `restricted_card`                  | não        | The card is restricted.                                |
| `4000009000000284` | `fraudulent`                       | não        | The transaction was flagged as suspected fraud.        |
| `4000009000000292` | `security_violation`               | sim        | The transaction was declined for a security violation. |
| `4000009000000300` | `stop_payment_order`               | sim        | A stop payment order applies to this card.             |
| `4000009000000318` | `revocation_of_authorization`      | não        | Authorization for this card has been revoked.          |
| `4000009000000326` | `revocation_of_all_authorizations` | não        | All authorizations for this card have been revoked.    |
| `4000009000000334` | `transaction_not_allowed`          | não        | The transaction is not allowed.                        |
| `4000009000000524` | `single_use_card`                  | não        | This card cannot be reused for this payment.           |

## Quando o cenário não está aqui

Peça ao MCP da Chargefy: `search_chargefy_documentation` encontra a página
[Sandbox](https://docs.chargefy.io/api-reference/sandbox), que cobre e-mails
determinísticos, ativação da conta e o que muda antes da aprovação do cadastro.
