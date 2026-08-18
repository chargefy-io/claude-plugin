---
name: convencoes-da-api
description: Convenções da API pública da Chargefy — autenticação com chave ch_live_/ch_test_, escopos, formato de erro e error.code, quais status podem ser repetidos, header Idempotency-Key, paginação por cursor (limit/starting_after/ending_before), valores em centavos e datas com fuso obrigatório. Use ao escrever ou revisar qualquer cliente HTTP da Chargefy, tratar erro, montar retry, paginar listagem ou converter valores monetários.
---

# Convenções da API da Chargefy

Base: `https://api.chargefy.io/v1`. Tudo abaixo vale para qualquer recurso.

## Autenticar

```bash
curl "https://api.chargefy.io/v1/customers?limit=1" \
  -H "Authorization: Bearer $CHARGEFY_API_KEY"
```

`X-Chargefy-Api-Key` é a alternativa quando um proxy já reserva o
`Authorization` (se os dois forem enviados, ele tem prioridade).

| Prefixo    | O que é                   | Onde pode aparecer |
| ---------- | ------------------------- | ------------------ |
| `ch_live_` | Chave secreta de produção | só no backend      |
| `ch_test_` | Chave secreta de teste    | só no backend      |
| `pk_`      | Chave publicável          | navegador          |

Chave secreta no navegador ou no app é vazamento — para os fluxos de browser
suportados existe a publicável. Escopos são hierárquicos: `read` ⊂ `write` ⊂
`admin`; use o menor que resolve.

## Erros

```json
{
  "error": {
    "code": "parameter_missing",
    "doc_url": "https://docs.chargefy.io/api-reference/errors",
    "message": "Missing required param: amount.",
    "param": "amount",
    "type": "invalid_request_error"
  }
}
```

Faça lógica com `error.code`; `error.message` é inglês e pode mudar, serve para
log e suporte. `error.type` separa as famílias: `invalid_request_error`,
`authentication_error`, `card_error`, `rate_limit_error`, `api_error`.

Toda resposta traz `X-Request-Id` — registre junto do status e do `code`, é o
que o suporte pede.

### O que pode ser repetido

| Status                            | Retry?                                                         |
| --------------------------------- | -------------------------------------------------------------- |
| `400`, `401`, `403`, `404`, `422` | Não. Corrija a request, a credencial ou os dados.              |
| `402`                             | Não sem ação do comprador (cartão recusado).                   |
| `409`                             | Depende do `code`; em geral resolva o estado antes.            |
| `429`, `500`                      | Sim, com backoff exponencial e jitter.                         |
| `502 payment_result_unconfirmed`  | **Não repita o write.** Consulte o recurso e espere o webhook. |

Esse último é o que separa integração boa de integração que cobra duas vezes: a
tentativa pode ter chegado ao processamento sem a resposta ter voltado.

## Idempotência

Envie `Idempotency-Key` em qualquer `POST` ou `DELETE` que muda estado. O header
é sempre opcional e não existe equivalente no corpo.

- Primeira chamada executa e guarda a resposta.
- Repetição com **mesma chave e mesmo corpo** devolve a resposta guardada com
  `Idempotent-Replayed: true`.
- Chave é única por organização **e por ambiente** — a mesma string em test e em
  live são chaves diferentes.
- Expira 24 horas depois de a operação concluir. Até 255 caracteres.
- Mesma chave com corpo diferente → `400 idempotency_key_reused`. Requisição
  anterior ainda em andamento → `409 idempotency_key_in_progress`.
- `5xx`, `409`, `425` e `429` não viram resultado final: a chave continua
  utilizável e o retry executa de novo.

Use um valor único por operação lógica. Numa importação, a melhor chave é o id
do registro no sistema de origem — reimportar nunca duplica.

## Paginação

Cursor, nunca número de página. Envelope idêntico em toda listagem:

```json
{ "object": "list", "data": [], "has_more": false, "url": "/v1/customers" }
```

`limit` aceita de 1 a 100 (padrão 10). Avance com `starting_after` = id do
**último** item; volte com `ending_before` = id do **primeiro**. Só um cursor por
request. Pare quando `has_more` for `false`, e preserve os mesmos filtros em
todas as páginas — muda só o cursor.

## Dinheiro

Valores são inteiros na menor unidade da moeda. Em `brl`, centavos: `19990` é
R$ 199,90. Campos com sufixo `_amount` seguem essa regra; campos com sufixo
`_rate` são percentuais em pontos-base, então `fee_amount: 399` é R$ 3,99
enquanto `fee_rate: 399` é 3,99%.

Converta uma vez, na entrada, e mantenha inteiro daí em diante — float em valor
monetário sempre acaba em diferença de centavo. O código da moeda segue ISO 4217
em minúsculas.

## Datas

Instantes exigem fuso explícito: `2026-08-10T12:00:00Z` ou com offset
(`-03:00`). Sem fuso a API responde `400`. Uma data pura (`2026-08-10`) não é um
instante — para vencimento, prefira `days_until_due` ou fixe meio-dia UTC, que
deixa ~12 horas de folga para qualquer fuso.

O fuso configurado no Dashboard **não** participa de cobrança: ele muda como
datas são exibidas, não quando o ciclo vira.

## Ids e referências

Todo id público tem prefixo (`cus_`, `price_`, `sub_`, `inv_`, `pi_`, `ch_`,
`evt_`, `cs_`, `pm_`, `seti_`, `re_`, `dp_`). Cuidado com `ch_`: ele é o
prefixo do **charge**, e também o começo das chaves secretas `ch_live_` /
`ch_test_` — um id de cobrança nunca traz `live_` ou `test_` depois do prefixo.

Nos objetos de resposta, uma referência aparece com o nome puro do recurso —
`"customer": "cus_..."`, `"price": "price_..."` — sem sufixo `_id`. Em requests, alguns campos têm nome próprio (por exemplo
`price_id` dentro de `line_items`): confirme no endpoint em vez de deduzir.

Regra de negócio não vive em `metadata`. Use `metadata` para correlacionar com o
seu sistema, não para guardar estado que decide comportamento.

## Confirmar antes de escrever código

`chargefy_api_search` acha a operação, `chargefy_api_details` devolve o schema
exato de entrada e saída. É mais rápido que procurar na documentação e não
inventa campo.
