# Plugin Chargefy para Claude Code

Ensina o Claude a integrar pagamentos, billing e plataformas com a Chargefy.
Inclui o mapa completo da integração pública e trilhas de sandbox, webhooks,
checkout e convenções da API. Instala junto o
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

| Skill                | Quando entra                                        |
| -------------------- | --------------------------------------------------- |
| `chargefy`           | Configuração, conceitos, modelagem e boas práticas. |
| `chargefy-payments`  | Checkout, webhooks e testes no sandbox.             |
| `chargefy-billing`   | Faturas, trial, pró-rata, uso e recuperação.        |
| `chargefy-platforms` | Organizações conectadas, ativação e marca.          |

As fontes públicas ficam em `apps/docs/skill.md` e
`apps/docs/.mintlify/skills/*/SKILL.md`. O plugin usa symlinks para essas fontes;
o publicador materializa todos os arquivos para distribuição independente.
`pnpm claude-plugin:check` verifica essa paridade e a tabela gerada de sandbox.

## Codex, Cursor e outros agentes

O mesmo pacote de quatro skills é distribuído pela documentação, sem depender do plugin:

```bash
npx skills add https://docs.chargefy.io --skill chargefy
```

O comando instala a configuração, conceitos e boas práticas. Troque `chargefy` pelo nome de outra skill da
tabela para instalá-la. Selecione seu agente ou use `--agent codex`, `--agent cursor` ou
`--agent claude-code`. Veja [Codar com agentes de IA](https://docs.chargefy.io/get-started/ai-agents).

## Revisor de integração

O subagente `integration-reviewer` revisa código que integra a Chargefy
procurando o que quebra em produção: webhook sem verificação de assinatura,
cobrança sem idempotência, chave secreta chegando ao navegador, redirect
tratado como confirmação de pagamento, retry em erro não confirmado.

Peça uma revisão antes de subir — "revise essa integração com a Chargefy" — ou
invoque direto com `@chargefy:integration-reviewer`. Ele não escreve nem edita
arquivo: só lê e reporta.

## Proteção incluída

Um hook avisa quando uma chave secreta de produção (`ch_live_...`) aparece num
arquivo que o git versiona. Arquivo ignorado pelo git — o seu `.env` local — não
gera aviso, e a chave nunca é impressa por inteiro.

## Documentação

- [MCP da Chargefy](https://docs.chargefy.io/mcp/installation)
- [Sandbox](https://docs.chargefy.io/api-reference/sandbox)
- [Referência da API](https://docs.chargefy.io/api-reference/introduction)

Suporte: suporte@chargefy.io
