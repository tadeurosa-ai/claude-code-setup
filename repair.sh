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
  command -v python3 &>/dev/null || return 0  # sem python3: assume válido, preserva arquivo
  python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$1" 2>/dev/null
}

CHECKPOINT_FILE="$HOME/.claude-install-checkpoint"
ISSUES=0
BACKUPS_VALID=()
BACKUPS_CORRUPT=()

clear 2>/dev/null || true   # TERM=dumb e afins: limpar a tela não é essencial
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

# Nomes reais (como estão gravados no disco) dos arquivos de skill da pasta: SKILL.md
# e/ou o skill.md antigo. Em ordem fixa, que não depende do idioma do sistema.
nomes_skill() {
  local f
  for f in "$1"/*; do
    [[ -f "$f" ]] || continue
    case "$(basename "$f" | LC_ALL=C tr '[:upper:]' '[:lower:]')" in
      skill.md) basename "$f" ;;
    esac
  done | LC_ALL=C sort
}

# O arquivo que vale: SKILL.md com esse nome exato, se existir; senão o antigo
arquivo_skill() {
  local n
  n="$(nomes_skill "$1")"
  [[ -n "$n" ]] || return 1
  if printf '%s\n' "$n" | grep -qx 'SKILL.md'; then
    printf '%s/SKILL.md' "$1"
  else
    printf '%s/%s' "$1" "$(printf '%s\n' "$n" | head -1)"
  fi
}

# O OUTRO nome, quando a pasta tem os dois (só acontece em disco que diferencia maiúscula)
nome_sobrando() {
  local n
  n="$(nomes_skill "$1")"
  printf '%s\n' "$n" | grep -qx 'SKILL.md' || return 1
  n="$(printf '%s\n' "$n" | grep -vx 'SKILL.md' | grep -v '^$' | head -1)"
  [[ -n "$n" ]] || return 1
  printf '%s' "$n"
}

# Skill instalada por este pacote: marca no frontmatter, ou o rodapé das versões antigas
# — e o rodapé só conta quando é a ÚLTIMA linha do arquivo (PRO; a Lite, 1º release, só
# pelo texto exato). Rodapé citado no meio do texto não marca nada.
do_pacote() {
  local ult
  grep -q '^  origem: claude-code-setup$' "$1" 2>/dev/null && return 0
  ult="$(tail -n 1 "$1" 2>/dev/null)" || return 1
  case "$ult" in *'Claude Code Setup PRO — by Tadeu Rosa'*) return 0 ;; esac
  [[ "$ult" == '*Claude Code Setup Lite — by Tadeu Rosa · CC BY-NC-ND 4.0*' ]]
}

# Pasta com skill.md e SKILL.md juntos (só em disco que diferencia maiúscula).
# Nunca mexe em arquivo do usuário:
#  • skill.md do pacote + SKILL.md com conteúdo → guardar o skill.md;
#  • skill.md do pacote com conteúdo + SKILL.md vazio, numa das 11 pastas do pacote →
#    renomear (o vazio é guardado e o skill.md vira SKILL.md: o que estava nele continua em uso);
#  • qualquer outro caso → manter (nada muda).
acao_dois_nomes() {  # acao_dois_nomes <pasta> <pasta do pacote: sim|nao> <outro nome>
  if do_pacote "$1/$3"; then
    if [[ -s "$1/SKILL.md" ]]; then echo guardar; return 0; fi
    if [[ "$2" == sim && -s "$1/$3" ]]; then echo renomear; return 0; fi
  fi
  echo manter
}

REPAIR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ${#skill_dirs[@]} -eq 0 ]]; then
  warn "Nenhuma skill instalada"
else
  for skill_dir in "${skill_dirs[@]}"; do
    skill_name="$(basename "$skill_dir")"
    # mesmos casos que o install.sh trata (ele resolve; aqui só o diagnóstico)
    if [[ -f "${skill_dir%/}/.SKILL.md.renomeando" ]]; then
      warn "Skill '$skill_name' — renomeação interrompida (.SKILL.md.renomeando): rode o install.sh de novo"
    fi
    if outro="$(nome_sobrando "${skill_dir%/}")"; then
      if [[ -d "$REPAIR_DIR/skills/$skill_name" ]]; then dentro=sim; else dentro=nao; fi
      # mesma decisão do install.sh: só manda rodar o instalador quando ele resolve
      case "$(acao_dois_nomes "${skill_dir%/}" "$dentro" "$outro")" in
        guardar)  warn "Skill '$skill_name' — sobrou o $outro antigo do pacote (~/.claude/skills/$skill_name/$outro): rode o install.sh de novo para guardá-lo" ;;
        renomear) warn "Skill '$skill_name' — SKILL.md vazio e o $outro do pacote tem conteúdo: rode o install.sh de novo" ;;
        *)        info "Skill '$skill_name' — tem ~/.claude/skills/$skill_name/$outro e SKILL.md; o Claude Code usa o SKILL.md (o instalador não mexe nisso)" ;;
      esac
    fi
    skill_md="$(arquivo_skill "${skill_dir%/}")" || skill_md=""
    if [[ -n "$skill_md" ]] && [[ -s "$skill_md" ]]; then
      ok "Skill '$skill_name' — ok ($(wc -l < "$skill_md") linhas)"
    elif [[ -n "$skill_md" ]]; then
      bad "Skill '$skill_name' — $(basename "$skill_md") VAZIO (corrompido)"
      ISSUES=$(( ISSUES + 1 ))
    else
      warn "Skill '$skill_name' — sem SKILL.md"
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
      warn "$HOME/.claude atual movido para .claude.broken-* (pode deletar depois)"
    fi
    mv "$TMP_RESTORE/.claude" "$HOME/.claude"
    rm -f "$CHECKPOINT_FILE"
    ok "Restauração concluída!"
    info "Execute ${BOLD}claude${RESET} para verificar."
    ;;
  I)
    echo ""
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ ! -f "$SCRIPT_DIR/install.sh" ]]; then
      bad "install.sh não encontrado em $SCRIPT_DIR"
      info "Baixe o pacote completo e rode repair.sh a partir da pasta do pacote."
      exit 1
    fi
    info "Iniciando reinstalação..."
    rm -f "$CHECKPOINT_FILE"
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
