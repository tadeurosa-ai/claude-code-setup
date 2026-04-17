#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Claude Code Backup — by Tadeu Rosa
# Versão: 1.0.0
# Licença: CC BY-NC-ND 4.0 — uso pessoal permitido, redistribuição proibida
# ─────────────────────────────────────────────────────────────────────────────
# O QUE ESTE SCRIPT FAZ:
#   Faz backup APENAS dos arquivos do Claude Code (~/.claude/ e ~/claude/).
#   Documentos, fotos, vídeos e demais arquivos NÃO são incluídos.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Cores ─────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; RESET='\033[0m'
CYAN='\033[0;36m'

info()    { echo -e "${BLUE}▸${RESET} $*"; }
ok()      { echo -e "${GREEN}✓${RESET} $*"; }
warn()    { echo -e "${YELLOW}⚠${RESET} $*"; }
error()   { echo -e "${RED}✗${RESET} $*" >&2; exit 1; }
section() { echo -e "\n${BOLD}── $* ──────────────────────────────────────────${RESET}"; }

# ── Detecta OS ────────────────────────────────────────────────────────────────
OS="$(uname -s)"
IS_MAC=false; IS_WIN=false; IS_LINUX=false
case "$OS" in
  Darwin) IS_MAC=true ;;
  Linux)  IS_LINUX=true ;;
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
         CODE BACKUP — by Tadeu Rosa
BANNER
echo -e "${RESET}"

# ── Aviso de escopo ───────────────────────────────────────────────────────────
echo -e "${BOLD}${YELLOW}"
cat << 'SCOPE'
╔══════════════════════════════════════════════════════════════╗
║  ⚠  ATENÇÃO — O QUE ESTE BACKUP INCLUI                      ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  ✓  Configurações do Claude Code  (~/.claude/)               ║
║  ✓  Skills, memória, hooks e automações                      ║
║  ✓  Projetos e chats              (~/claude/)                ║
║                                                              ║
║  ✗  Documentos, fotos e vídeos    → NÃO incluídos           ║
║  ✗  Aplicativos instalados        → NÃO incluídos           ║
║  ✗  Demais arquivos do usuário    → NÃO incluídos           ║
║                                                              ║
║  Para backup completo da máquina use:                        ║
║    • Mac:     Time Machine                                   ║
║    • Windows: Backup e Restauração (Painel de Controle)     ║
║    • Nuvem:   iCloud / Google Drive / OneDrive              ║
╚══════════════════════════════════════════════════════════════╝
SCOPE
echo -e "${RESET}"

echo -e "${BOLD}Você já fez backup dos seus documentos e arquivos pessoais?${RESET}"
echo -e "  [s] Sim, pode continuar"
echo -e "  [n] Não — prefiro sair e fazer backup completo primeiro"
echo ""
read -rp "  Escolha [s/n]: " SCOPE_CONFIRM
echo ""

case "$(echo "$SCOPE_CONFIRM" | tr '[:upper:]' '[:lower:]')" in
  s|sim|y|yes) ok "Confirmado. Iniciando backup do Claude Code..." ;;
  *)
    warn "Saindo. Faça o backup completo antes de continuar."
    echo ""
    if $IS_MAC; then
      info "Mac: Preferências do Sistema → Time Machine"
      info "iCloud: Preferências do Sistema → ID Apple → iCloud Drive"
    else
      info "Windows: Painel de Controle → Backup e Restauração"
      info "OneDrive / Google Drive: verifique o app na bandeja do sistema"
    fi
    echo ""
    exit 0
    ;;
esac

# ── Limpeza automática silenciosa ─────────────────────────────────────────────
section "Limpeza"

CLEANED=0

# Checkpoints de instalação
if [[ -f "$HOME/.claude-install-checkpoint" ]]; then
  rm -f "$HOME/.claude-install-checkpoint"
  (( CLEANED++ )) || true
fi

# Backups .tar.gz corrompidos do próprio script
for old in "$HOME"/.claude-backup-*.tar.gz "$HOME"/.claude-snapshot-*.tar.gz; do
  [[ -f "$old" ]] || continue
  if ! tar -tzf "$old" &>/dev/null; then
    rm -f "$old"
    (( CLEANED++ )) || true
  fi
done

# Arquivos .tmp e .example gerados pelo install.sh
while IFS= read -r -d '' f; do
  rm -f "$f"
  (( CLEANED++ )) || true
done < <(find "$HOME/.claude" -name "*.tmp" -o -name "*.XXXXXX" 2>/dev/null -print0 || true)

[[ $CLEANED -gt 0 ]] && ok "$CLEANED arquivo(s) temporário(s) removido(s)" || ok "Nada para limpar"

# ── Limpeza opcional de histórico ─────────────────────────────────────────────
EXCLUDE_CHATS=false

if [[ -d "$HOME/claude/chats" ]]; then
  CHATS_SIZE="$(du -sh "$HOME/claude/chats" 2>/dev/null | cut -f1 || echo '?')"
  echo ""
  echo -e "${BOLD}Histórico de chats encontrado (${CHATS_SIZE}).${RESET}"
  echo -e "  Incluir no backup? (pode aumentar o tamanho e o tempo de sync)"
  echo -e "  [s] Sim, incluir chats  ${YELLOW}(padrão)${RESET}"
  echo -e "  [n] Não incluir chats agora"
  echo ""
  read -rp "  Escolha [S/n]: " CHATS_CONFIRM
  case "$(echo "$CHATS_CONFIRM" | tr '[:upper:]' '[:lower:]')" in
    n|nao|não|no) EXCLUDE_CHATS=true; info "Chats excluídos do backup" ;;
    *) info "Chats incluídos no backup" ;;
  esac
fi

# ── Calcula tamanho estimado ───────────────────────────────────────────────────
section "Estimativa"

SIZE_CLAUDE=0; SIZE_WORKSPACE=0

[[ -d "$HOME/.claude" ]] && \
  SIZE_CLAUDE="$(du -sm "$HOME/.claude" 2>/dev/null | cut -f1 || echo 0)"

if [[ -d "$HOME/claude" ]]; then
  if $EXCLUDE_CHATS; then
    SIZE_WORKSPACE="$(du -sm --exclude="$HOME/claude/chats" "$HOME/claude" 2>/dev/null | cut -f1 || echo 0)"
  else
    SIZE_WORKSPACE="$(du -sm "$HOME/claude" 2>/dev/null | cut -f1 || echo 0)"
  fi
fi

TOTAL_SIZE=$(( SIZE_CLAUDE + SIZE_WORKSPACE ))
ok "Tamanho estimado: ~${TOTAL_SIZE} MB"

# ── Escolha do destino ────────────────────────────────────────────────────────
section "Destino do backup"

# Detecta pastas disponíveis
ICLOUD_PATH=""
GDRIVE_PATH=""

if $IS_MAC; then
  ICLOUD_CANDIDATE="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
  [[ -d "$ICLOUD_CANDIDATE" ]] && ICLOUD_PATH="$ICLOUD_CANDIDATE"

  # Google Drive — app novo (2021+) e legado
  for gd in "$HOME/Library/CloudStorage"/GoogleDrive-*/My\ Drive \
             "$HOME/Google Drive/My Drive" \
             "$HOME/Google Drive"; do
    [[ -d "$gd" ]] && { GDRIVE_PATH="$gd"; break; }
  done
fi

if $IS_WIN; then
  # iCloud para Windows
  WIN_ICLOUD="${USERPROFILE:-$HOME}/iCloudDrive"
  [[ -d "$WIN_ICLOUD" ]] && ICLOUD_PATH="$WIN_ICLOUD"

  # Google Drive para Windows
  WIN_GDRIVE="${USERPROFILE:-$HOME}/Google Drive/My Drive"
  [[ -d "$WIN_GDRIVE" ]] || WIN_GDRIVE="${USERPROFILE:-$HOME}/Google Drive"
  [[ -d "$WIN_GDRIVE" ]] && GDRIVE_PATH="$WIN_GDRIVE"
fi

echo ""
OPTION_NUM=0
OPT_CUSTOM=0; OPT_ICLOUD=0; OPT_GDRIVE=0

(( OPTION_NUM++ )) || true
OPT_CUSTOM=$OPTION_NUM
echo -e "  [${OPTION_NUM}] Pasta local ou USB (você escolhe o caminho)"

if [[ -n "$ICLOUD_PATH" ]]; then
  (( OPTION_NUM++ )) || true
  OPT_ICLOUD=$OPTION_NUM
  echo -e "  [${OPTION_NUM}] iCloud Drive ${GREEN}(detectado)${RESET}"
else
  echo -e "  ${YELLOW}[–] iCloud Drive — não detectado (app não instalado ou não logado)${RESET}"
fi

if [[ -n "$GDRIVE_PATH" ]]; then
  (( OPTION_NUM++ )) || true
  OPT_GDRIVE=$OPTION_NUM
  echo -e "  [${OPTION_NUM}] Google Drive ${GREEN}(detectado)${RESET}"
else
  echo -e "  ${YELLOW}[–] Google Drive — não detectado (app não instalado ou não logado)${RESET}"
fi

echo ""
read -rp "  Escolha [1-${OPTION_NUM}]: " DEST_CHOICE

DEST_TYPE=""
[[ "$DEST_CHOICE" == "$OPT_CUSTOM" ]] && DEST_TYPE="custom"
[[ $OPT_ICLOUD -gt 0 && "$DEST_CHOICE" == "$OPT_ICLOUD" ]] && DEST_TYPE="icloud"
[[ $OPT_GDRIVE -gt 0 && "$DEST_CHOICE" == "$OPT_GDRIVE" ]] && DEST_TYPE="gdrive"
[[ -z "$DEST_TYPE" ]] && error "Opção inválida: $DEST_CHOICE"

case "$DEST_TYPE" in
  custom)
    echo ""
    read -rp "  Caminho de destino (ex: /Volumes/USB ou ~/Desktop): " DEST_PATH
    DEST_PATH="${DEST_PATH/#\~/$HOME}"
    [[ -d "$DEST_PATH" ]] || error "Pasta não encontrada: $DEST_PATH"
    ;;
  icloud)
    DEST_PATH="$ICLOUD_PATH/Claude Code Backups"
    mkdir -p "$DEST_PATH"
    ;;
  gdrive)
    DEST_PATH="$GDRIVE_PATH/Claude Code Backups"
    mkdir -p "$DEST_PATH"
    ;;
esac

ok "Destino: $DEST_PATH"

# ── Criação do snapshot ───────────────────────────────────────────────────────
section "Criando snapshot"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
SNAPSHOT_NAME="claude-code-snapshot-${TIMESTAMP}.tar.gz"
SNAPSHOT_PATH="$DEST_PATH/$SNAPSHOT_NAME"

# Monta lista de exclusões
EXCLUDES=()
# Paths relativos a -C $HOME — tar ignora path absoluto com -C
$EXCLUDE_CHATS && EXCLUDES+=("--exclude=claude/chats")
EXCLUDES+=(
  "--exclude=.claude-backup-*.tar.gz"
  "--exclude=.claude-snapshot-*.tar.gz"
  "--exclude=.claude-install-checkpoint"
)

info "Comprimindo arquivos..."

SOURCES=()
[[ -d "$HOME/.claude"  ]] && SOURCES+=(".claude")
[[ -d "$HOME/claude"   ]] && SOURCES+=("claude")

if [[ ${#SOURCES[@]} -eq 0 ]]; then
  error "Nenhuma pasta do Claude Code encontrada em $HOME"
fi

if tar -czf "$SNAPSHOT_PATH" "${EXCLUDES[@]}" -C "$HOME" "${SOURCES[@]}" 2>/dev/null; then
  # Verifica integridade imediatamente
  if tar -tzf "$SNAPSHOT_PATH" &>/dev/null; then
    FINAL_SIZE="$(du -sh "$SNAPSHOT_PATH" 2>/dev/null | cut -f1 || echo '?')"
    ok "Snapshot criado e verificado: $SNAPSHOT_NAME (${FINAL_SIZE})"
  else
    rm -f "$SNAPSHOT_PATH"
    error "Snapshot criado mas corrompido — verifique espaço em disco em: $DEST_PATH"
  fi
else
  error "Falha ao criar snapshot — verifique permissões e espaço em: $DEST_PATH"
fi

# ── Aviso final para destinos em nuvem ───────────────────────────────────────
if [[ "$DEST_TYPE" == "icloud" || "$DEST_TYPE" == "gdrive" ]]; then
  echo ""
  echo -e "${BOLD}${YELLOW}"
  cat << SYNC_WARN
╔══════════════════════════════════════════════════════════════╗
║  ⚠  AGUARDE O SYNC ANTES DE FORMATAR A MÁQUINA              ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  O arquivo foi salvo na pasta local do iCloud/Google Drive.  ║
║  O upload para a nuvem acontece em segundo plano.            ║
║                                                              ║
║  NÃO formate a máquina até confirmar o upload:               ║
SYNC_WARN

  if [[ "$DEST_TYPE" == "icloud" ]]; then
    echo -e "║    • Mac: ícone iCloud na barra de menu pare de girar        ║"
    echo -e "║    • Ou: icloud.com → confirme o arquivo lá                  ║"
  else
    echo -e "║    • Ícone Google Drive na barra de menu pare de girar       ║"
    echo -e "║    • Ou: drive.google.com → confirme o arquivo lá            ║"
  fi

  cat << SYNC_WARN2
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
SYNC_WARN2
  echo -e "${RESET}"
fi

# ── Resumo final ──────────────────────────────────────────────────────────────
section "Concluído"

echo -e "
${GREEN}${BOLD}✓ Backup do Claude Code concluído!${RESET}

${BOLD}Arquivo:${RESET}  $SNAPSHOT_PATH
${BOLD}Tamanho:${RESET}  ${FINAL_SIZE}

${BOLD}Próximos passos:${RESET}
  1. $(if [[ "$DEST_TYPE" == "icloud" || "$DEST_TYPE" == "gdrive" ]]; then echo "Confirme o upload na nuvem antes de prosseguir"; else echo "Guarde o arquivo em local seguro"; fi)
  2. Formate a máquina
  3. Instale o Claude Code: ${BLUE}https://claude.ai/code${RESET}
  4. Restaure com: ${BLUE}bash restore.sh${RESET}

${BOLD}by Tadeu Rosa — CC BY-NC-ND 4.0${RESET}
"
