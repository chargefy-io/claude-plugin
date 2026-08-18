---
name: escolher-checkout
description: Escolher e implementar o fluxo de pagamento da Chargefy — link de pagamento, checkout hospedado (Checkout Session), checkout white-label com Chargefy.js ou Payment Intents direto. Use ao começar uma integração de pagamento, ao decidir entre página pronta e interface própria, ao criar uma Checkout Session, tokenizar cartão no navegador ou cobrar server-to-server.
---

# Escolher o fluxo de pagamento

Quatro caminhos, do menos ao mais trabalhoso. **Na dúvida, comece pelo checkout
hospedado**: ele coordena itens, comprador, métodos, parcelamento, expiração e
webhooks, e seu backend só decide o que vender e quando liberar o pedido.

| Caminho                  | Quando é a escolha certa                                                           | Esforço |
| ------------------------ | ---------------------------------------------------------------------------------- | ------- |
| **Link de pagamento**    | Mesma oferta reutilizável, sem backend por compra. Uma URL que você compartilha.   | baixo   |
| **Checkout hospedado**   | Um pedido por vez, página pronta da Chargefy. **Padrão recomendado.**              | médio   |
| **Checkout white-label** | O pagamento precisa acontecer dentro do seu produto, com sua marca e seus estados. | alto    |
| **Payment Intents**      | Sua aplicação já resolveu o checkout e você quer controlar só a cobrança.          | alto    |

Duas perguntas resolvem a maioria dos casos: _a oferta muda a cada compra?_ (não
→ link) e _a tela de pagamento precisa ser sua?_ (não → hospedado).

## Checkout hospedado

O menor request válido envia só `line_items`:

```bash
curl -X POST "https://api.chargefy.io/v1/checkout-sessions" \
  -H "Authorization: Bearer $CHARGEFY_API_KEY" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: pedido-8f4c2a" \
  -d '{ "line_items": [{ "price_id": "price_w9A2hszZXxVwxRaG", "quantity": 1 }] }'
```

Cada item traz **exatamente um** entre `price_id` (preço do catálogo) e
`price_data` (preço ad-hoc, que vive só nessa sessão).

Da resposta importam:

| Campo            | Uso                                                             |
| ---------------- | --------------------------------------------------------------- |
| `url`            | Redirecione o navegador para cá                                 |
| `id` (`cs_...`)  | Consultas do backend                                            |
| `expires_at`     | Prazo fixo de 24 horas; depois disso crie outra sessão          |
| `status`         | Nasce `open`                                                    |
| `payment_status` | Nasce `unpaid` (ou `no_payment_required` quando nada é devido)  |
| `client_secret`  | Só para runtime próprio no navegador; desnecessário no redirect |

`mode`, totais, `expires_at`, `client_secret` e `url` são calculados pela
Chargefy — não os envie no request. Use uma `Idempotency-Key` estável por
pedido: retry por timeout devolve a mesma sessão em vez de criar duas.

Para trazer o comprador de volta, use `success_url` e `cancel_url` absolutas;
`{CHECKOUT_SESSION_ID}` na URL é substituído pelo id da sessão.

## Checkout white-label

A regra de segurança define o desenho: número do cartão e CVC são tratados
**no navegador**, pelo [Chargefy.js](https://docs.chargefy.io/api/chargefy-js).
Seu servidor nunca vê o PAN.

A sequência do pagamento imediato:

1. Backend cria ou reutiliza o `customer` (`cus_...`).
2. Backend abre o cadastro do cartão (`setup_intent`, `seti_...`) e entrega o
   `client_secret` ao frontend.
3. Navegador carrega `https://api.chargefy.io/v1/chargefy.js`, coleta o cartão
   com a **chave publicável** (`pk_...`) e devolve um `payment_method` (`pm_...`)
   reutilizável. O token de uso único (`tok_...`) fica interno.
4. Backend cobra com o `payment_method` salvo.

Nunca envie chave secreta (`ch_...`) para o navegador — só `pk_...`. E carregue
o script sempre da origem oficial, sem cópia local, para receber correção de
segurança automaticamente.

## Payment Intents direto

Use quando sua aplicação já mantém carrinho, itens e apresentação, e precisa
apenas da tentativa financeira: você envia valor final, moeda e método, e mantém
os estados, o retry e a tradução para o comprador. Cartão e Pix nascem na
criação direta; boleto nasce em checkout hospedado ou invoice.

## Armadilhas comuns

- **O redirect não é a confirmação.** Trate o webhook como fonte da verdade;
  `success_url` só significa que o navegador voltou. Veja a skill `webhooks`.
- **Pix e boleto são assíncronos.** Cartão costuma concluir na confirmação; os
  outros continuam pendentes até a compensação, e é o evento que fecha o pedido.
- **Sessão expira em 24 horas.** Não guarde a `url` para reaproveitar depois.
- **Métodos disponíveis vêm da configuração da organização**, não do request.

## Aprofundar

- `search_chargefy_documentation` para a página do fluxo escolhido.
- `chargefy_implementation_planner` monta o plano de integração sem executar
  nada, quando o caminho ainda não está decidido.
- Para testar cada estado (aprovado, recusado, `processing`), use a skill
  `testar-pagamentos`.
