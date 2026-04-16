#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Claude Code Setup — repair.sh
# Diagnóstico e recuperação após falha de instalação (queda de luz, Ctrl+C...)
# by Tadeu Rosa · CC BY-NC-ND 4.0
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; RESET='\033[0m'
CYAN='\033[0;36m'

ok()      { echo -e "  ${GREEN}✓${RESET} $*"; }
warn()    { echo -e "  ${YELLOW}⚠${RESET} $*"; }
bad()     { echo -e "  ${RED}✗${RESET} $*"; }
info()    { echo -e "  ${BLUE}▸${RESET} $*"; }
section() { echo -e "\n${BOLD}${CYAN}▌ $*${RESET}"; }
hr()      { echo -e "${BLUE}────────────────────────────────────────────────${RESET}"; }

is_valid_json() {
  python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$1" 2>/dev/null
}

CHECKPOINT_FILE="$HOME/.claude-install-checkpoint"
ISSUES=0
BACKUPS_VALID=()
BACKUPS_CORRUPT=()

clear
echo -e "${BOLD}"
cat << 'BANNER'
  ██████╗██╗      █████╗ ██╗   ██╗██████╗ ███████╗
 ██╔════╝██║     ██╔══██╗██║   ██║██╔══██╗██╔════╝
 ██║     ██║     ███████║██║   ██║██║  ██║█████╗
 ██║     ██║     ██╔══██║██║   ██║██║  ██║██╔══╝
 ╚██████╗███████╗██║  ██║╚██████╔╝██████╔╝███████╗
  ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝
         REPAIR MODE — by Tadeu Rosa
BANNER
echo -e "${RESET}"

# ── 1. CHECKPOINT ─────────────────────────────────────────────────────────────
section "Verificando instalação anterior"

if [[ -f "$CHECKPOINT_FILE" ]]; then
  LAST_STAGE="$(cat "$CHECKPOINT_FILE" 2>/dev/null || echo 'desconhecido')"
  bad "Instalação INTERROMPIDA detectada"
  warn "Última etapa registrada: ${BOLD}$LAST_STAGE${RESET}"
  warn "Causa provável: queda de luz, Ctrl+C ou crash durante a instalação."
  ISSUES=$(( ISSUES + 1 ))
else
  ok "Nenhuma instalação interrompida detectada"
fi

# ── 2. BACKUPS ────────────────────────────────────────────────────────────────
section "Verificando backups"

shopt -s nullglob
all_backups=("$HOME"/.claude-backup-*.tar.gz)
shopt -u nullglob

if [[ ${#all_backups[@]} -eq 0 ]]; then
  warn "Nenhum backup encontrado em $HOME"
else
  for backup in "${all_backups[@]}"; do
    name="$(basename "$backup")"
    size="$(du -sh "$backup" 2>/dev/null | cut -f1 || echo '?')"
    if tar -tzf "$backup" &>/dev/null 2>&1; then
      ok "Backup VÁLIDO   : $name (${size})"
      BACKUPS_VALID+=("$backup")
    else
      bad "Backup CORROMPIDO: $name (${size}) — provavelmente queda de luz durante backup"
      BACKUPS_CORRUPT+=("$backup")
      ISSUES=$(( ISSUES + 1 ))
    fi
  done
fi

# ── 3. ESTRUTURA DE DIRETÓRIOS ────────────────────────────────────────────────
section "Verificando estrutura de diretórios"

EXPECTED_DIRS=(
  "$HOME/.claude"
  "$HOME/.claude/skills"
  "$HOME/.claude/hooks"
  "$HOME/.claude/projects"
  "$HOME/claude"
  "$HOME/claude/projetos"
  "$HOME/claude/chats"
)

for dir in "${EXPECTED_DIRS[@]}"; do
  short="${dir/$HOME/\~}"
  if [[ -d "$dir" ]]; then
    ok "$short"
  elif [[ -e "$dir" ]]; then
    bad "$short existe como ARQUIVO (esperava diretório)"
    ISSUES=$(( ISSUES + 1 ))
  else
    warn "$short não existe"
    ISSUES=$(( ISSUES + 1 ))
  fi
done

# ── 4. ARQUIVOS CRÍTICOS ──────────────────────────────────────────────────────
section "Verificando arquivos críticos"

CLAUDE_MD="$HOME/.claude/CLAUDE.md"
if [[ -f "$CLAUDE_MD" ]] && [[ -s "$CLAUDE_MD" ]]; then
  ok "CLAUDE.md  — presente e não vazio ($(wc -l < "$CLAUDE_MD") linhas)"
elif [[ -f "$CLAUDE_MD" ]] && [[ ! -s "$CLAUDE_MD" ]]; then
  bad "CLAUDE.md  — arquivo VAZIO (corrompido por queda de luz)"
  ISSUES=$(( ISSUES + 1 ))
else
  warn "CLAUDE.md  — não existe (instalação nova ou não concluída)"
fi

SETTINGS="$HOME/.claude/settings.json"
if [[ -f "$SETTINGS" ]]; then
  if is_valid_json "$SETTINGS"; then
    ok "settings.json — JSON válido"
  else
    bad "settings.json — JSON INVÁLIDO/CORROMPIDO (provável queda de luz)"
    warn "Conteúdo atual:"
    cat "$SETTINGS" | head -5 | sed 's/^/      /'
    ISSUES=$(( ISSUES + 1 ))
  fi
elif [[ -d "$SETTINGS" ]]; then
  bad "settings.json — existe como DIRETÓRIO"
  ISSUES=$(( ISSUES + 1 ))
else
  warn "settings.json — não existe"
fi

# ── 5. SKILLS ─────────────────────────────────────────────────────────────────
section "Verificando skills instaladas"

shopt -s nullglob
skill_dirs=("$HOME/.claude/skills"/*/)
shopt -u nullglob

if [[ ${#skill_dirs[@]} -eq 0 ]]; then
  warn "Nenhuma skill instalada"
else
  for skill_dir in "${skill_dirs[@]}"; do
    skill_name="$(basename "$skill_dir")"
    skill_md="$skill_dir/skill.md"
    if [[ -f "$skill_md" ]] && [[ -s "$skill_md" ]]; then
      ok "Skill '$skill_name' — ok ($(wc -l < "$skill_md") linhas)"
    elif [[ -f "$skill_md" ]] && [[ ! -s "$skill_md" ]]; then
      bad "Skill '$skill_name' — skill.md VAZIO (corrompido)"
      ISSUES=$(( ISSUES + 1 ))
    else
      warn "Skill '$skill_name' — sem skill.md"
    fi
  done
fi

# ── RESUMO ────────────────────────────────────────────────────────────────────
echo ""
hr

if [[ $ISSUES -eq 0 ]]; then
  echo -e "\n${GREEN}${BOLD}✓ Sistema saudável — nenhum problema encontrado${RESET}\n"
  exit 0
fi

echo -e "\n${RED}${BOLD}✗ $ISSUES problema(s) encontrado(s)${RESET}\n"

# ── AÇÕES DE RECUPERAÇÃO ──────────────────────────────────────────────────────
section "O que deseja fazer?"

OPTIONS=()

if [[ ${#BACKUPS_VALID[@]} -gt 0 ]]; then
  echo -e "  ${BOLD}[R]${RESET} Restaurar a partir do backup mais recente"
  OPTIONS+=("R")
fi

echo -e "  ${BOLD}[I]${RESET} Re-executar instalação (corrige arquivos corrompidos)"
OPTIONS+=("I")

if [[ ${#BACKUPS_CORRUPT[@]} -gt 0 ]]; then
  echo -e "  ${BOLD}[L]${RESET} Limpar backups corrompidos (${#BACKUPS_CORRUPT[@]} arquivo(s))"
  OPTIONS+=("L")
fi

if [[ -f "$CHECKPOINT_FILE" ]]; then
  echo -e "  ${BOLD}[C]${RESET} Limpar checkpoint (marca a instalação como limpa)"
  OPTIONS+=("C")
fi

echo -e "  ${BOLD}[S]${RESET} Sair sem fazer nada"
OPTIONS+=("S")

echo ""
read -rp "  Escolha: " choice || choice="S"
choice="$(echo "$choice" | tr '[:lower:]' '[:upper:]')"

case "$choice" in
  R)
    if [[ ${#BACKUPS_VALID[@]} -eq 0 ]]; then
      bad "Nenhum backup válido disponível."; exit 1
    fi
    # Pega o mais recente
    LATEST=""
    for b in "${BACKUPS_VALID[@]}"; do
      [[ -z "$LATEST" || "$b" > "$LATEST" ]] && LATEST="$b"
    done
    echo ""
    warn "Isso irá SUBSTITUIR ~/.claude/ pelo conteúdo de:"
    info "$(basename "$LATEST")"
    echo ""
    read -rp "  Confirma restauração? [s/N]: " confirm || confirm="N"
    confirm="$(echo "$confirm" | tr '[:upper:]' '[:lower:]')"
    [[ "$confirm" == "s" ]] || { info "Cancelado."; exit 0; }

    echo ""
    info "Restaurando backup..."
    # Atômico: restaura em tmpdir, depois mv
    TMP_RESTORE="$(mktemp -d)"
    trap 'rm -rf "$TMP_RESTORE"' EXIT
    tar -xzf "$LATEST" -C "$TMP_RESTORE"
    # Renomeia atual para .broken (preserva evidência)
    if [[ -d "$HOME/.claude" ]]; then
      mv "$HOME/.claude" "$HOME/.claude.broken-$(date +%Y%m%d-%H%M%S)"
      warn "~/.claude atual movido para .claude.broken-* (pode deletar depois)"
    fi
    mv "$TMP_RESTORE/.claude" "$HOME/.claude"
    rm -f "$CHECKPOINT_FILE"
    ok "Restauração concluída!"
    info "Execute ${BOLD}claude${RESET} para verificar."
    ;;
  I)
    echo ""
    info "Iniciando reinstalação..."
    rm -f "$CHECKPOINT_FILE"
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    exec bash "$SCRIPT_DIR/install.sh"
    ;;
  L)
    echo ""
    for b in "${BACKUPS_CORRUPT[@]}"; do
      rm -f "$b"
      ok "Removido: $(basename "$b")"
    done
    ok "Backups corrompidos removidos."
    ;;
  C)
    rm -f "$CHECKPOINT_FILE"
    ok "Checkpoint removido."
    ;;
  S)
    info "Nenhuma ação tomada."
    ;;
  *)
    warn "Opção inválida."
    ;;
esac

echo ""
