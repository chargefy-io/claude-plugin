---
name: setup
description: Preparar o projeto local para integrar a Chargefy — criar chave de teste, escolher os nomes das variáveis de ambiente, garantir que o segredo fique fora do versionamento e validar a conexão com uma chamada real. Use ao começar a integração, ao configurar um ambiente novo, quando a API responde 401 ou quando a dúvida é onde guardar a chave.
---

# Preparar o ambiente local

Objetivo: chegar numa chamada `200` com chave de **teste**, sem nenhum segredo
versionado. Cinco passos, nessa ordem.

## 1. Crie a chave de teste

No dashboard: **Desenvolvedores → Chaves de API → Nova chave**, ambiente
`test`. O token começa com `ch_test_` e funciona mesmo com a conta ainda em
análise — o sandbox roda de ponta a ponta antes da ativação.

Use o menor escopo que resolve: `read` para explorar, `write` só quando a
integração for criar ou alterar recursos.

## 2. Guarde fora do código

Nomes que o restante deste plugin assume:

| Variável                   | Conteúdo                                                       |
| -------------------------- | -------------------------------------------------------------- |
| `CHARGEFY_API_KEY`         | chave secreta do ambiente (`ch_test_...`)                      |
| `CHARGEFY_WEBHOOK_SECRET`  | secret do endpoint de webhook (`whsec_...`)                    |
| `CHARGEFY_PUBLISHABLE_KEY` | chave publicável (`pk_...`), só se houver checkout white-label |

Antes de escrever qualquer uma delas em arquivo, confirme que o arquivo está no
`.gitignore`. Se o projeto já tem `.env.example`, acrescente as chaves lá **com
valor vazio** — é o arquivo que entra no commit.

Chave secreta nunca vai para o frontend, para o app mobile, para o repositório
nem para um ticket. Se uma vazar, revogue no dashboard antes de qualquer outra
coisa: rotacionar é barato, investigar uso indevido não é.

## 3. Valide a conexão

```bash
curl -sS "https://api.chargefy.io/v1/customers?limit=1" \
  -H "Authorization: Bearer $CHARGEFY_API_KEY"
```

Resposta esperada, mesmo sem nenhum cliente cadastrado:

```json
{ "object": "list", "data": [], "has_more": false, "url": "/v1/customers" }
```

| Resposta                      | Causa provável                                                |
| ----------------------------- | ------------------------------------------------------------- |
| `401 authentication_failed`   | Chave ausente, com espaço extra, revogada ou expirada         |
| `403 permission_denied`       | Escopo insuficiente para o que foi chamado                    |
| `404 resource_missing` num id | O id existe no outro ambiente — confira `ch_test_`/`ch_live_` |

## 4. Confirme o ambiente

Todo recurso traz `livemode`. Em teste ele é `false`; se vier `true`, você está
usando a chave de produção sem perceber. O prefixo da chave é a única coisa que
decide o ambiente — não existe parâmetro para alternar.

## 5. Conecte o MCP (opcional, recomendado)

Com o MCP autorizado, dá para consultar a conta em vez de adivinhar: abra
`/mcp`, selecione **chargefy** e escolha **Authenticate**. A conexão é por
organização, e teste e produção são autorizados separadamente — o ambiente ao
vivo vem desabilitado até um administrador liberar.

Depois disso, `get_chargefy_account_info` mostra organização, ambientes e nível
de acesso da conexão; `chargefy_api_details` devolve o schema exato de qualquer
operação antes de você escrever o cliente HTTP.

## Próximo passo

- Decidir o fluxo de pagamento → skill `escolher-checkout`
- Receber eventos → skill `webhooks`
- Simular aprovação e recusa → skill `testar-pagamentos`
