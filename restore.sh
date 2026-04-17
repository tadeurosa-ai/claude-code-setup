#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Claude Code Restore — by Tadeu Rosa
# Versão: 1.0.0
# Licença: CC BY-NC-ND 4.0 — uso pessoal permitido, redistribuição proibida
# ─────────────────────────────────────────────────────────────────────────────
# COMO USAR:
#   bash restore.sh                          # busca snapshot automaticamente
#   bash restore.sh caminho/snapshot.tar.gz  # usa arquivo específico
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Cores ─────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${BLUE}▸${RESET} $*"; }
ok()      { echo -e "${GREEN}✓${RESET} $*"; }
warn()    { echo -e "${YELLOW}⚠${RESET} $*"; }
error()   { echo -e "${RED}✗${RESET} $*" >&2; exit 1; }
section() { echo -e "\n${BOLD}── $* ──────────────────────────────────────────${RESET}"; }

# Escrita atômica — nunca deixa arquivo parcial
write_atomic() {
  local target="$1"; local tmp
  tmp="$(mktemp "${target}.XXXXXX")"
  cat > "$tmp"
  mv "$tmp" "$target"
}

# ── Detecta OS ────────────────────────────────────────────────────────────────
OS="$(uname -s)"
IS_MAC=false; IS_WIN=false
case "$OS" in
  Darwin) IS_MAC=true ;;
  Linux)  ;;
  MINGW*|MSYS*|CYGWIN*) IS_WIN=true ;;
  *) error "Sistema não suportado: $OS" ;;
esac

# ── Banner ────────────────────────────────────────────────────────────────────
clear
echo -e "${BOLD}"
cat << 'BANNER'
  ██████╗██╗      █████╗ ██╗   ██╗██████╗ ███████╗
 ██╔════╝██║     ██╔══██╗██║   ██║██╔══██╗██╔════╝
 ██║     ██║     ███████║██║   ██║██║  ██║█████╗
 ██║     ██║     ██╔══██║██║   ██║██║  ██║██╔══╝
 ╚██████╗███████╗██║  ██║╚██████╔╝██████╔╝███████╗
  ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝
         CODE RESTORE — by Tadeu Rosa
BANNER
echo -e "${RESET}"
echo -e "  Restaurando seu ambiente Claude Code a partir de um backup...\n"

# ── Verifica pré-requisitos ───────────────────────────────────────────────────
section "Verificando sistema"

if ! command -v claude &>/dev/null; then
  warn "Claude Code não encontrado."
  echo ""
  echo -e "  O restore pode continuar, mas você precisará instalar o Claude Code depois."
  echo -e "  → ${BLUE}https://claude.ai/code${RESET}"
  echo ""
  read -rp "  Continuar mesmo assim? [s/N]: " PRE_CONFIRM
  PRE_LOWER="$(echo "$PRE_CONFIRM" | tr '[:upper:]' '[:lower:]')"
  [[ "$PRE_LOWER" =~ ^(s|sim|y|yes)$ ]] || { info "Instale o Claude Code e rode novamente."; exit 0; }
else
  CLAUDE_VERSION="$(claude --version 2>/dev/null | head -1 || echo 'versão desconhecida')"
  ok "Claude Code: $CLAUDE_VERSION"
fi

# ── Localiza o snapshot ───────────────────────────────────────────────────────
section "Localizando snapshot"

SNAPSHOT=""

# Argumento direto: bash restore.sh caminho/arquivo.tar.gz
if [[ $# -ge 1 && -f "$1" ]]; then
  SNAPSHOT="$1"
  info "Snapshot informado: $SNAPSHOT"
fi

# Busca automática em locais comuns
if [[ -z "$SNAPSHOT" ]]; then
  info "Buscando snapshot automaticamente..."

  SEARCH_DIRS=()

  # iCloud
  if $IS_MAC; then
    ICLOUD="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Claude Code Backups"
    [[ -d "$ICLOUD" ]] && SEARCH_DIRS+=("$ICLOUD")
  fi
  if $IS_WIN; then
    WIN_ICLOUD="${USERPROFILE:-$HOME}/iCloudDrive/Claude Code Backups"
    [[ -d "$WIN_ICLOUD" ]] && SEARCH_DIRS+=("$WIN_ICLOUD")
  fi

  # Google Drive
  if $IS_MAC; then
    for gd in "$HOME/Library/CloudStorage"/GoogleDrive-*/My\ Drive/Claude\ Code\ Backups \
               "$HOME/Google Drive/My Drive/Claude Code Backups" \
               "$HOME/Google Drive/Claude Code Backups"; do
      [[ -d "$gd" ]] && { SEARCH_DIRS+=("$gd"); break; }
    done
  fi
  if $IS_WIN; then
    for gd in "${USERPROFILE:-$HOME}/Google Drive/My Drive/Claude Code Backups" \
               "${USERPROFILE:-$HOME}/Google Drive/Claude Code Backups"; do
      [[ -d "$gd" ]] && { SEARCH_DIRS+=("$gd"); break; }
    done
  fi

  # Desktop e pasta atual
  SEARCH_DIRS+=("$HOME/Desktop" "$HOME/Downloads" "$(pwd)")

  # Procura o snapshot mais recente em cada pasta
  FOUND_SNAPSHOTS=()
  for dir in "${SEARCH_DIRS[@]}"; do
    [[ -d "$dir" ]] || continue
    while IFS= read -r -d '' f; do
      FOUND_SNAPSHOTS+=("$f")
    done < <(find "$dir" -maxdepth 1 -name "claude-code-snapshot-*.tar.gz" -print0 2>/dev/null || true)
  done

  if [[ ${#FOUND_SNAPSHOTS[@]} -eq 1 ]]; then
    SNAPSHOT="${FOUND_SNAPSHOTS[0]}"
    ok "Snapshot encontrado: $(basename "$SNAPSHOT")"

  elif [[ ${#FOUND_SNAPSHOTS[@]} -gt 1 ]]; then
    echo ""
    echo -e "${BOLD}Múltiplos snapshots encontrados:${RESET}"
    for i in "${!FOUND_SNAPSHOTS[@]}"; do
      SIZE="$(du -sh "${FOUND_SNAPSHOTS[$i]}" 2>/dev/null | cut -f1 || echo '?')"
      DATE_STR="$(basename "${FOUND_SNAPSHOTS[$i]}" | grep -oE '[0-9]{8}-[0-9]{6}' || echo '')"
      echo -e "  [$((i+1))] $(basename "${FOUND_SNAPSHOTS[$i]}")  ${YELLOW}(${SIZE})${RESET}  ${DATE_STR}"
    done
    echo ""
    read -rp "  Qual usar? [1-${#FOUND_SNAPSHOTS[@]}]: " SNAP_CHOICE
    IDX=$(( SNAP_CHOICE - 1 ))
    [[ $IDX -ge 0 && $IDX -lt ${#FOUND_SNAPSHOTS[@]} ]] || error "Opção inválida"
    SNAPSHOT="${FOUND_SNAPSHOTS[$IDX]}"
  fi
fi

# Nenhum snapshot encontrado — pede caminho manualmente
if [[ -z "$SNAPSHOT" ]]; then
  warn "Nenhum snapshot encontrado automaticamente."
  echo ""
  echo -e "  Informe o caminho completo do arquivo de backup:"
  echo -e "  ${BLUE}(ex: /Volumes/USB/claude-code-snapshot-20260416-120000.tar.gz)${RESET}"
  echo ""
  read -rp "  Caminho: " MANUAL_PATH
  MANUAL_PATH="${MANUAL_PATH/#\~/$HOME}"
  [[ -f "$MANUAL_PATH" ]] || error "Arquivo não encontrado: $MANUAL_PATH"
  SNAPSHOT="$MANUAL_PATH"
fi

# ── Verifica integridade do snapshot ─────────────────────────────────────────
section "Verificando snapshot"

info "Verificando integridade do arquivo..."
if ! tar -tzf "$SNAPSHOT" &>/dev/null; then
  error "Arquivo corrompido ou inválido: $SNAPSHOT\n  Verifique se o sync da nuvem foi concluído antes de restaurar."
fi

SNAP_SIZE="$(du -sh "$SNAPSHOT" 2>/dev/null | cut -f1 || echo '?')"
SNAP_CONTENTS="$(tar -tzf "$SNAPSHOT" 2>/dev/null | head -5 | sed 's/^/    /')"
ok "Snapshot válido (${SNAP_SIZE})"
echo -e "${BLUE}  Conteúdo (primeiros itens):${RESET}"
echo "$SNAP_CONTENTS"
echo "    ..."

# ── Detecta conflito com setup existente ──────────────────────────────────────
section "Verificando destino"

HAS_EXISTING=false
[[ -d "$HOME/.claude" ]] && HAS_EXISTING=true
[[ -d "$HOME/claude"  ]] && HAS_EXISTING=true

if $HAS_EXISTING; then
  warn "Setup existente detectado em $HOME"
  echo ""
  echo -e "  O que deseja fazer com os arquivos atuais?"
  echo -e "  [1] Fazer backup dos atuais e substituir pelo snapshot  ${GREEN}(recomendado)${RESET}"
  echo -e "  [2] Mesclar — snapshot preenche apenas o que está faltando"
  echo -e "  [3] Cancelar"
  echo ""
  read -rp "  Escolha [1-3]: " CONFLICT_CHOICE

  case "$CONFLICT_CHOICE" in
    1) RESTORE_MODE="replace" ;;
    2) RESTORE_MODE="merge"   ;;
    *) info "Cancelado."; exit 0 ;;
  esac
else
  RESTORE_MODE="replace"
  info "Nenhum setup anterior — restauração limpa."
fi

# ── Backup de segurança do setup atual (modo replace) ─────────────────────────
if [[ "$RESTORE_MODE" == "replace" ]] && $HAS_EXISTING; then
  section "Backup de segurança"
  SAFETY_BACKUP="$HOME/.claude-pre-restore-$(date +%Y%m%d-%H%M%S).tar.gz"
  info "Salvando setup atual antes de substituir..."

  SAFETY_SOURCES=()
  [[ -d "$HOME/.claude" ]] && SAFETY_SOURCES+=(".claude")
  [[ -d "$HOME/claude"  ]] && SAFETY_SOURCES+=("claude")

  if tar -czf "$SAFETY_BACKUP" -C "$HOME" "${SAFETY_SOURCES[@]}" 2>/dev/null \
     && tar -tzf "$SAFETY_BACKUP" &>/dev/null; then
    ok "Backup de segurança: $(basename "$SAFETY_BACKUP")"
  else
    rm -f "$SAFETY_BACKUP"
    warn "Não foi possível criar backup de segurança — continuando assim mesmo."
  fi
fi

# ── Restauração ───────────────────────────────────────────────────────────────
section "Restaurando"

TMP_EXTRACT="$(mktemp -d)"
trap 'rm -rf "$TMP_EXTRACT"' EXIT

info "Extraindo snapshot..."
tar -xzf "$SNAPSHOT" -C "$TMP_EXTRACT" 2>/dev/null || error "Falha ao extrair snapshot"

RESTORED=0

restore_dir() {
  local src_name="$1"   # .claude ou claude
  local src="$TMP_EXTRACT/$src_name"
  local dest="$HOME/$src_name"

  [[ -d "$src" ]] || return 0

  if [[ "$RESTORE_MODE" == "replace" ]]; then
    rm -rf "$dest"
    cp -r "$src" "$dest"
    ok "Restaurado: ~/$src_name"
    (( RESTORED++ )) || true

  else
    # Merge: copia apenas arquivos ausentes no destino
    mkdir -p "$dest"
    local count=0
    while IFS= read -r -d '' file; do
      rel="${file#$src/}"
      target="$dest/$rel"
      if [[ ! -e "$target" ]]; then
        mkdir -p "$(dirname "$target")"
        cp "$file" "$target"
        (( count++ )) || true
      fi
    done < <(find "$src" -type f -print0 2>/dev/null)
    ok "Mesclado: ~/$src_name ($count arquivo(s) restaurado(s))"
    (( RESTORED++ )) || true
  fi
}

restore_dir ".claude"
restore_dir "claude"

[[ $RESTORED -eq 0 ]] && error "Nenhum diretório do Claude Code encontrado no snapshot"

# ── Validação pós-restore ─────────────────────────────────────────────────────
section "Validação"

WARNINGS=0

check_exists() {
  local path="$1" label="$2"
  if [[ -e "$HOME/$path" ]]; then
    ok "$label"
  else
    warn "$label — não encontrado (pode ser normal se não estava no backup)"
    (( WARNINGS++ )) || true
  fi
}

check_exists ".claude/CLAUDE.md"        "CLAUDE.md"
check_exists ".claude/settings.json"    "settings.json"
check_exists ".claude/skills"           "Skills"
check_exists ".claude/hooks"            "Hooks"
check_exists "claude/projetos"          "Projetos"

# ── Resumo final ──────────────────────────────────────────────────────────────
section "Concluído"

WARN_MSG=""
[[ $WARNINGS -gt 0 ]] && WARN_MSG="\n${YELLOW}  ⚠ $WARNINGS aviso(s) acima — verifique se é esperado${RESET}\n"

SAFETY_MSG=""
[[ -n "${SAFETY_BACKUP:-}" && -f "${SAFETY_BACKUP:-}" ]] && \
  SAFETY_MSG="\n  • Backup de segurança do setup anterior: $(basename "$SAFETY_BACKUP")\n"

echo -e "
${GREEN}${BOLD}✓ Restore concluído com sucesso!${RESET}
${WARN_MSG}
${BOLD}O que foi restaurado:${RESET}
  • ~/.claude/  — configurações, skills, hooks, memória
  • ~/claude/   — projetos e chats
${SAFETY_MSG}
${BOLD}Próximos passos:${RESET}
  1. Abra o Claude Code: ${BLUE}claude${RESET}
  2. Teste com: ${BLUE}/help${RESET}
  3. Se algo parecer errado: ${BLUE}bash repair.sh${RESET}

${BOLD}by Tadeu Rosa — CC BY-NC-ND 4.0${RESET}
"
