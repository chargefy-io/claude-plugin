---
name: webhooks
description: Receber webhooks da Chargefy com segurança — verificar a assinatura Standard Webhooks (headers webhook-id/webhook-timestamp/webhook-signature, secret whsec_), deduplicar por event.id, escolher os tipos de evento, entender retentativas e rotacionar secret. Use ao criar ou revisar um endpoint de webhook, ao investigar assinatura inválida, evento duplicado, fora de ordem ou entrega que não chegou.
---

# Webhooks da Chargefy

O evento é gravado primeiro e entregue depois, por um worker que drena a fila a
cada minuto. Endpoint lento nunca trava a operação que gerou o evento — mas
também significa que **o webhook é a fonte da verdade do resultado financeiro**,
não o redirect do comprador.

## O contrato

Seu endpoint precisa de três coisas:

1. Aceitar `POST` numa URL **HTTPS**.
2. Verificar a assinatura **antes** de processar o corpo.
3. Responder **2xx** em até **20 segundos**.

Fila, retry, rotação e fan-out são responsabilidade da Chargefy.

| Fato                          | Valor                                                                |
| ----------------------------- | -------------------------------------------------------------------- |
| Assinatura                    | Standard Webhooks (HMAC-SHA-256), secret `whsec_...`                 |
| Timeout por tentativa         | 20 segundos                                                          |
| Tentativas                    | 9 (1 original + 8 reentregas) ao longo de ~3 dias, backoff crescente |
| Garantia de entrega           | _at least once_ — deduplique por `event.id`                          |
| Ordem entre eventos distintos | **não** garantida                                                    |
| Wildcards (`charge.*`, `*`)   | não existem; assine cada tipo exato                                  |

## Verificar a assinatura

Headers de cada entrega:

| Header              | Conteúdo                                                            |
| ------------------- | ------------------------------------------------------------------- |
| `webhook-id`        | ID do evento (`evt_...`), igual ao `id` do corpo                    |
| `webhook-timestamp` | Unix timestamp **em segundos** da assinatura                        |
| `webhook-signature` | `v1,<base64>` — pode trazer várias assinaturas separadas por espaço |

A mensagem assinada é `${webhook-id}.${webhook-timestamp}.${corpo_bruto}`, e a
chave do HMAC são os **bytes decodificados** do base64 do secret (depois do
prefixo `whsec_`). Como o formato do secret também segue o padrão, qualquer
biblioteca Standard Webhooks funciona sem adaptação: passe o secret inteiro,
com prefixo.

**A armadilha número um é o corpo.** Reserialize o JSON e a assinatura quebra.
Leia o corpo cru antes de qualquer parser do framework.

```typescript
// Next.js (App Router)
import { NextRequest, NextResponse } from "next/server";
import { Webhook } from "svix";

const wh = new Webhook(process.env.CHARGEFY_WEBHOOK_SECRET!); // whsec_...

export async function POST(req: NextRequest) {
  const body = await req.text(); // cru — nunca req.json() aqui
  let evt;
  try {
    evt = wh.verify(body, {
      "webhook-id": req.headers.get("webhook-id")!,
      "webhook-timestamp": req.headers.get("webhook-timestamp")!,
      "webhook-signature": req.headers.get("webhook-signature")!,
    });
  } catch {
    return NextResponse.json({ error: "Invalid signature" }, { status: 401 });
  }

  // enfileire e responda rápido; o processamento pesado vem depois
  await enqueue(evt);
  return NextResponse.json({ received: true });
}
```

Em Express, o equivalente é montar a rota com
`express.raw({ type: "application/json" })` antes do `express.json()` global.

## Deduplicar e não confiar na ordem

`event.id` é estável por evento e igual ao header `webhook-id`. Grave-o numa
tabela com restrição de unicidade: se já existe, responda `200` e **não**
reprocesse.

Ordem entre eventos diferentes não é garantida, e `data.object` é um snapshot do
instante do evento — pode chegar desatualizado. Antes de aplicar uma transição
terminal, consulte o recurso pelo ID e não deixe uma falha rebaixar um pagamento
já `succeeded` nem uma sessão já `paid`.

## Escolher os tipos

Assine o **resultado de negócio**, não o caminho: o mesmo
`payment.intent.succeeded` confirma pagamento vindo de checkout, link ou API.

| Quero saber quando…                   | Escute                                     |
| ------------------------------------- | ------------------------------------------ |
| Um pagamento foi confirmado           | `payment.intent.succeeded`                 |
| Uma cobrança foi capturada / recusada | `charge.succeeded`, `charge.failed`        |
| Uma Checkout Session foi concluída    | `checkout.session.completed`               |
| Pagamento assíncrono do checkout caiu | `checkout.session.async.payment.succeeded` |
| Uma fatura foi paga / falhou          | `invoice.paid`, `invoice.payment.failed`   |
| Uma assinatura mudou                  | `subscription.updated`                     |

O `type` segue `namespace.action`, sempre separado por pontos. O catálogo
completo está em `/api-reference/events/types` — busque com o MCP em vez de
adivinhar o nome.

## Responder certo

- **`200` primeiro, processar depois.** Trabalho pesado dentro dos 20 segundos
  vira timeout, que conta como falha e gera reentrega de um evento já recebido.
- **Evento que você ignora também merece `200`.** Tipo que não interessa,
  duplicata, organização desconhecida: reconheça e descarte em silêncio.
  `4xx`/`5xx` são para falha real de processamento.
- Um endpoint fora do ar por horas — até ~3 dias — recupera sozinho quando
  voltar. Depois das 9 tentativas a entrega vira falha permanente e só volta por
  reentrega manual no dashboard.

## Rotacionar o secret sem janela de rejeição

Resetar o secret vale imediatamente e derruba entregas em voo. Para trocar sem
perder nada: cadastre um endpoint temporário com a mesma URL e os mesmos
eventos, aceite os dois secrets no servidor (tenta um, cai para o outro),
confirme `2xx` no novo e só então remova o antigo. Durante a transição o mesmo
evento chega duas vezes — a deduplicação por `event.id` já resolve.

## Testar local

Exponha a porta com um tunnel HTTPS (`ngrok http 3000` ou `lt --port 3000`) e
cadastre a URL gerada como endpoint em test mode. Para produzir eventos de falha
sob demanda, use os cartões da skill `testar-pagamentos`.

## Ao revisar um endpoint, confira

- [ ] Corpo cru na verificação, sem parser antes.
- [ ] Falha de assinatura devolve `401` e não processa.
- [ ] Dedup por `event.id` com unicidade no banco.
- [ ] Resposta `2xx` rápida; processamento assíncrono.
- [ ] Nenhuma lógica dependendo da ordem de chegada.
- [ ] Secret em variável de ambiente, nunca no código.

Detalhes de transporte, agenda de reentrega e fan-out para plataformas estão em
[Entrega de webhooks](https://docs.chargefy.io/integrate/webhooks/delivery) —
use `search_chargefy_documentation` para abrir a seção exata.
