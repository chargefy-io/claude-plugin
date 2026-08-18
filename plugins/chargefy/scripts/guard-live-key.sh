#!/usr/bin/env bash
# Avisa quando uma chave secreta de produção da Chargefy (`ch_live_...`) é
# escrita em um arquivo versionável.
#
# Roda em PostToolUse (Write|Edit): a escrita já aconteceu, então o hook não
# bloqueia nada — ele sai com 2 para que o aviso chegue ao Claude, que remove a
# chave no mesmo turno.
#
# Silencioso de propósito quando o arquivo é ignorado pelo git: `.env` local com
# chave real é o uso pretendido, não vazamento.
#
# A chave nunca é ecoada inteira; o aviso mostra só o prefixo mascarado.

set -uo pipefail

input=$(cat)

if command -v jq >/dev/null 2>&1; then
  file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')
else
  file_path=$(printf '%s' "$input" |
    sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' |
    head -n 1)
fi

[ -n "$file_path" ] || exit 0
[ -f "$file_path" ] || exit 0

# Arquivo fora do versionamento: chave real ali é intencional.
if git -C "$(dirname "$file_path")" check-ignore -q "$file_path" 2>/dev/null; then
  exit 0
fi

matches=$(grep -nE 'ch_live_[A-Za-z0-9]{6,}' "$file_path" 2>/dev/null | head -n 3) || true
[ -n "$matches" ] || exit 0

{
  echo "Chave secreta de produção da Chargefy encontrada em ${file_path}:"
  printf '%s\n' "$matches" |
    sed -E 's/(ch_live_[A-Za-z0-9]{4})[A-Za-z0-9]+/\1…/g' |
    sed -E 's/^([0-9]+):[[:space:]]*/  linha \1: /'
  echo
  echo "Remova a chave do arquivo e leia-a de uma variável de ambiente"
  echo "(ex.: CHARGEFY_API_KEY). Chave que entra em commit deve ser revogada"
  echo "no dashboard, em Desenvolvedores → Chaves de API."
} >&2

exit 2
