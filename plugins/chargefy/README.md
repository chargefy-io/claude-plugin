# Plugin Chargefy para Claude Code

Ensina o Claude a integrar a Chargefy: cartões determinísticos do sandbox,
webhooks, escolha do fluxo de checkout e convenções da API. Instala junto o
MCP oficial (`https://mcp.chargefy.io`), então o mesmo agente que escreve o
código também consulta seus dados de teste.

## Instalar

```bash
claude plugin marketplace add chargefy-io/claude-plugin
```

```bash
claude plugin install chargefy@chargefy
```

Depois de instalar, abra `/mcp`, selecione **chargefy** e escolha
**Authenticate** para autorizar uma organização. As skills funcionam sem essa
autorização; o que depende dela é consultar dados da sua conta.

Se você já tinha adicionado `https://mcp.chargefy.io` manualmente, o Claude
reconhece que é o mesmo servidor e não duplica as tools.

## O que vem dentro

| Skill               | Quando entra                                                                   |
| ------------------- | ------------------------------------------------------------------------------ |
| `setup`             | Preparar chave de teste, variáveis de ambiente e validar a conexão             |
| `escolher-checkout` | Decidir e implementar link, checkout hospedado, white-label ou Payment Intents |
| `webhooks`          | Criar ou revisar endpoint: assinatura, deduplicação, retentativas              |
| `convencoes-da-api` | Autenticação, erros, retry, idempotência, paginação, centavos e datas          |
| `testar-pagamentos` | Simular aprovação, recusa, captura pendente ou processamento no sandbox        |

## Proteção incluída

Um hook avisa quando uma chave secreta de produção (`ch_live_...`) aparece num
arquivo que o git versiona. Arquivo ignorado pelo git — o seu `.env` local — não
gera aviso, e a chave nunca é impressa por inteiro.

## Documentação

- [MCP da Chargefy](https://docs.chargefy.io/mcp/installation)
- [Sandbox](https://docs.chargefy.io/api-reference/sandbox)
- [Referência da API](https://docs.chargefy.io/api-reference/introduction)

Suporte: suporte@chargefy.io
