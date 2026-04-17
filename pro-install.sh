#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Claude Code Setup PRO — Launcher
# by Tadeu Rosa · CC BY-NC-ND 4.0
# ─────────────────────────────────────────────────────────────────────────────
# Uso:
#   CLAUDE_SETUP_TOKEN=github_pat_xxx bash <(curl -fsSL URL_DESTE_ARQUIVO)
#   bash <(curl -fsSL URL_DESTE_ARQUIVO)   ← pede token interativamente
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

BLUE='\033[0;34m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; RESET='\033[0m'

PRIVATE_API="https://api.github.com/repos/tadeurosa-ai/claude-code-setup-pro/contents/install.sh"

# ── Token: env var ou prompt ──────────────────────────────────────────────
TOKEN="${CLAUDE_SETUP_TOKEN:-}"

if [[ -z "$TOKEN" ]]; then
  echo -e "\n${BLUE}▸${RESET} Cole o token de acesso que você recebeu por e-mail:"
  echo -e "  ${BLUE}(começa com ghp_ ou github_pat_)${RESET}\n"
  read -rsp "  Token: " TOKEN
  echo ""
fi

[[ -z "$TOKEN" ]] && { echo -e "${RED}✗ Token não informado.${RESET}" >&2; exit 1; }

if ! echo "$TOKEN" | grep -qE '^(ghp_|github_pat_)[A-Za-z0-9_]+$'; then
  echo -e "${RED}✗ Formato de token inválido.${RESET}" >&2
  echo -e "  Verifique o e-mail e tente novamente." >&2
  exit 1
fi

# ── Baixa install.sh do repo privado usando o token ──────────────────────
echo -e "\n${BLUE}▸${RESET} Verificando token de acesso..."

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

HTTP_STATUS="$(curl -fsSL \
  -H "Authorization: token ${TOKEN}" \
  -H "Accept: application/vnd.github.raw" \
  -w "%{http_code}" \
  -o "$TMP" \
  "$PRIVATE_API" 2>/dev/null || echo "000")"

if [[ "$HTTP_STATUS" != "200" ]]; then
  echo -e "${RED}✗ Token inválido ou expirado (HTTP ${HTTP_STATUS}).${RESET}" >&2
  echo ""
  echo -e "  Causas possíveis:"
  echo -e "    • Token expirado — verifique a data de validade no e-mail"
  echo -e "    • Token copiado incorretamente"
  echo -e "    • Sem conexão com a internet"
  echo ""
  echo -e "  Precisa de ajuda? ${BLUE}tadeu.rosa.ai@gmail.com${RESET}"
  exit 1
fi

echo -e "  ✓ Acesso confirmado"

# ── Executa o instalador privado ──────────────────────────────────────────
export CLAUDE_SETUP_TOKEN="$TOKEN"
exec bash "$TMP"
