#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Claude Code Backup — by Tadeu Rosa
# Versão: 1.1.0
# Licença: CC BY-NC-ND 4.0 — uso pessoal permitido, redistribuição proibida
# ─────────────────────────────────────────────────────────────────────────────
# O QUE ESTE SCRIPT FAZ:
#   Faz backup APENAS dos arquivos do Claude Code (~/.claude/ e ~/claude/).
#   Documentos, fotos, vídeos e demais arquivos NÃO são incluídos.
#
#   Destino na NUVEM (iCloud, Google Drive, OneDrive, Dropbox):
#     • de ~/.claude/ só vão as configurações (lista fixa abaixo);
#     • login, histórico e textos das conversas, .env e chaves ficam na máquina;
#     • o settings.json vai com os valores do bloco "env" apagados.
#   Destino LOCAL (pendrive, disco externo, pasta local):
#     • vai tudo; pergunta se inclui login, senhas (.env) e chaves.
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
║  Na nuvem, login, histórico, .env e chaves NÃO vão.          ║
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
done < <(find "$HOME/.claude" \( -name "*.tmp" -o -name "*.XXXXXX" \) -print0 2>/dev/null || true)

if [[ $CLEANED -gt 0 ]]; then
  ok "$CLEANED arquivo(s) temporário(s) removido(s)"
else
  ok "Nada para limpar"
fi

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
    read -rp "  Caminho de destino (ex: /Volumes/USB): " DEST_PATH
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

# ── O destino é nuvem? ────────────────────────────────────────────────────────
# Caminho real, sem atalhos (symlinks)
caminho_real() { ( cd "$1" 2>/dev/null && pwd -P ) || echo "$1"; }

# Mac: Mesa e Documentos sincronizados com o iCloud
icloud_mesa_docs() {
  $IS_MAC || return 1
  [[ "$(defaults read com.apple.finder FXICloudDriveDesktop 2>/dev/null || true)" == "1" ]] && return 0
  [[ "$(defaults read com.apple.finder FXICloudDriveDocuments 2>/dev/null || true)" == "1" ]] && return 0
  [[ -d "$HOME/Library/Mobile Documents/com~apple~CloudDocs/Desktop" ]] && return 0
  [[ -d "$HOME/Library/Mobile Documents/com~apple~CloudDocs/Documents" ]] && return 0
  return 1
}

eh_nuvem() {
  local p home_real d
  p="$(caminho_real "$1")"
  home_real="$(caminho_real "$HOME")"
  for base in "$HOME" "$home_real"; do
    case "$p" in
      "$base/Library/Mobile Documents"|"$base/Library/Mobile Documents/"*) return 0 ;;
      "$base/Library/CloudStorage"|"$base/Library/CloudStorage/"*) return 0 ;;
    esac
  done
  case "$p" in
    *iCloudDrive*|*"iCloud Drive"*|*OneDrive*|*"Google Drive"*|*GoogleDrive*|*Dropbox*) return 0 ;;
  esac
  if icloud_mesa_docs; then
    for d in "$HOME/Desktop" "$HOME/Documents"; do
      [[ -d "$d" ]] || continue
      d="$(caminho_real "$d")"
      case "$p" in "$d"|"$d/"*) return 0 ;; esac
    done
  fi
  return 1
}

DEST_IS_CLOUD=false
if [[ "$DEST_TYPE" == "icloud" || "$DEST_TYPE" == "gdrive" ]] || eh_nuvem "$DEST_PATH"; then
  DEST_IS_CLOUD=true
fi

# ── O que entra ───────────────────────────────────────────────────────────────
EXCLUDE_CHATS=false
INCLUDE_SECRETS=false

if $DEST_IS_CLOUD; then
  warn "Destino na nuvem. Vão só as configurações do Claude Code e os seus projetos."
  warn "Ficam na máquina: login, histórico e textos das conversas, senhas (.env) e chaves."
  EXCLUDE_CHATS=true
else
  ok "Destino local (pendrive, disco ou pasta que não sincroniza)."

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

  echo ""
  echo -e "${BOLD}Login do Claude Code, senhas de projetos (.env) e chaves (.pem, .key).${RESET}"
  echo -e "  Inclua só se o destino for um pendrive ou disco que só você usa."
  echo ""
  read -rp "  Incluir login, senhas (.env) e chaves? [s/N]: " SECRETS_CONFIRM
  case "$(echo "$SECRETS_CONFIRM" | tr '[:upper:]' '[:lower:]')" in
    s|sim|y|yes) INCLUDE_SECRETS=true; warn "Login, senhas e chaves INCLUÍDOS — guarde o arquivo em local seguro" ;;
    *) info "Login, senhas e chaves ficam fora" ;;
  esac
fi

# ── Calcula tamanho estimado ───────────────────────────────────────────────────
section "Estimativa"

if $DEST_IS_CLOUD; then
  ok "Na nuvem vai só uma parte das pastas; o tamanho final aparece no fim."
else
  SIZE_CLAUDE=0; SIZE_WORKSPACE=0

  [[ -d "$HOME/.claude" ]] && \
    SIZE_CLAUDE="$(du -sm "$HOME/.claude" 2>/dev/null | cut -f1 || echo 0)"

  if [[ -d "$HOME/claude" ]]; then
    if $EXCLUDE_CHATS && [[ -d "$HOME/claude/chats" ]]; then
      _TOTAL="$(du -sm "$HOME/claude" 2>/dev/null | cut -f1 || echo 0)"
      _CHATS="$(du -sm "$HOME/claude/chats" 2>/dev/null | cut -f1 || echo 0)"
      SIZE_WORKSPACE=$(( _TOTAL - _CHATS ))
    else
      SIZE_WORKSPACE="$(du -sm "$HOME/claude" 2>/dev/null | cut -f1 || echo 0)"
    fi
  fi

  TOTAL_SIZE=$(( SIZE_CLAUDE + SIZE_WORKSPACE ))
  ok "Tamanho estimado: ~${TOTAL_SIZE} MB"
fi

# ── Criação do snapshot ───────────────────────────────────────────────────────
section "Criando snapshot"

[[ -d "$HOME/.claude" || -d "$HOME/claude" ]] || \
  error "Nenhuma pasta do Claude Code encontrada em $HOME"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
SNAPSHOT_NAME="claude-code-snapshot-${TIMESTAMP}.tar.gz"
SNAPSHOT_PATH="$DEST_PATH/$SNAPSHOT_NAME"

# Pasta de trabalho: uma "raiz" com atalhos para as pastas reais. O tar lê
# tudo dela, então o settings.json limpo e o arquivo de informação entram no
# mesmo snapshot sem copiar as pastas grandes.
TMP_WORK="$(mktemp -d)"
trap 'rm -rf "$TMP_WORK"' EXIT
RAIZ="$TMP_WORK/raiz"
LISTA="$TMP_WORK/lista"
TAR_LOG="$TMP_WORK/tar.log"
mkdir -p "$RAIZ"
: > "$LISTA"

# Arquivos que nunca entram (o próprio snapshot, se o destino estiver dentro das pastas)
FILTRO=( ! -name 'claude-code-snapshot-*.tar.gz' )
# Login, senhas e chaves
if $DEST_IS_CLOUD || ! $INCLUDE_SECRETS; then
  FILTRO+=( ! -name '.credentials.json'
            ! -name '.env'
            ! \( -name '.env.*' ! -name '.env.example' \)
            ! -name '*.pem'
            ! -name '*.key' )
fi
# Pastas que não entram
PODA=( -path './__nenhuma__' )
$DEST_IS_CLOUD && PODA+=( -o -path '.claude/skills/.trash' )
$EXCLUDE_CHATS && PODA+=( -o -path 'claude/chats' )

# listar <caminho relativo ao HOME> → acrescenta os arquivos à lista
listar() {
  ( cd "$HOME" && find -H "$1" \( "${PODA[@]}" \) -prune -o \
      \( -type f -o -type l \) "${FILTRO[@]}" -print0 2>/dev/null ) >> "$LISTA" || true
}
na_lista() { printf '%s\0' "$1" >> "$LISTA"; }

SETTINGS_STATUS=""

if $DEST_IS_CLOUD; then
  # ~/.claude por LISTA DO QUE ENTRA: só configurações
  # (code.claude.com/docs/en/claude-directory, tabela "File reference")
  if [[ -d "$HOME/.claude" ]]; then
    mkdir -p "$RAIZ/.claude"
    for item in skills hooks commands agents rules output-styles workflows agent-memory memory; do
      if [[ -d "$HOME/.claude/$item" ]]; then
        ln -s "$HOME/.claude/$item" "$RAIZ/.claude/$item"
        listar ".claude/$item"
      fi
    done
    for item in CLAUDE.md keybindings.json; do
      if [[ -f "$HOME/.claude/$item" ]]; then
        cp "$HOME/.claude/$item" "$RAIZ/.claude/$item"
        na_lista ".claude/$item"
      fi
    done
    # Memória automática de cada projeto
    for m in "$HOME"/.claude/projects/*/memory; do
      [[ -d "$m" ]] || continue
      rel="${m#"$HOME"/}"
      mkdir -p "$RAIZ/$(dirname "$rel")"
      ln -s "$m" "$RAIZ/$rel"
      listar "$rel"
    done
    # settings.json sem os valores do bloco "env"
    if [[ -f "$HOME/.claude/settings.json" ]]; then
      if command -v python3 &>/dev/null && python3 - "$HOME/.claude/settings.json" "$RAIZ/.claude/settings.json" <<'PY' 2>/dev/null
import json, sys
src, dst = sys.argv[1], sys.argv[2]
with open(src, encoding="utf-8") as f:
    d = json.load(f)
env = d.get("env")
if isinstance(env, dict):
    d["env"] = {k: "" for k in env}
with open(dst, "w", encoding="utf-8") as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
    f.write("\n")
PY
      then
        na_lista ".claude/settings.json"
        SETTINGS_STATUS="limpo"
        ok "settings.json incluído sem os valores do bloco env"
      else
        rm -f "$RAIZ/.claude/settings.json"
        SETTINGS_STATUS="fora"
        warn "settings.json ficou fora (precisa do python3 para tirar as chaves do bloco env)"
      fi
    fi
  fi
  # ~/claude por EXCLUSÃO: sem .env, chaves e chats
  if [[ -d "$HOME/claude" ]]; then
    ln -s "$HOME/claude" "$RAIZ/claude"
    listar "claude"
  fi
else
  [[ -d "$HOME/.claude" ]] && { ln -s "$HOME/.claude" "$RAIZ/.claude"; listar ".claude"; }
  [[ -d "$HOME/claude"  ]] && { ln -s "$HOME/claude"  "$RAIZ/claude";  listar "claude"; }
fi

# Informação usada pelo restore.sh (não é restaurada para as pastas)
if $DEST_IS_CLOUD; then DEST_LABEL="nuvem"; else DEST_LABEL="local"; fi
if $INCLUDE_SECRETS; then SECRETS_LABEL="sim"; else SECRETS_LABEL="nao"; fi
printf 'destino=%s\nsegredos=%s\ndata=%s\n' "$DEST_LABEL" "$SECRETS_LABEL" "$TIMESTAMP" \
  > "$RAIZ/claude-code-backup-info.txt"
na_lista "claude-code-backup-info.txt"

info "Comprimindo arquivos..."

if tar -czf "$SNAPSHOT_PATH" -C "$RAIZ" --null -T "$LISTA" 2>"$TAR_LOG"; then
  # Verifica integridade imediatamente
  if tar -tzf "$SNAPSHOT_PATH" &>/dev/null; then
    FINAL_SIZE="$(du -sh "$SNAPSHOT_PATH" 2>/dev/null | cut -f1 || echo '?')"
    ok "Snapshot criado e verificado: $SNAPSHOT_NAME (${FINAL_SIZE})"
  else
    rm -f "$SNAPSHOT_PATH"
    error "Snapshot criado mas corrompido — verifique espaço em disco em: $DEST_PATH"
  fi
else
  rm -f "$SNAPSHOT_PATH"
  tail -5 "$TAR_LOG" >&2 || true
  error "Falha ao criar snapshot — verifique permissões e espaço em: $DEST_PATH"
fi

# ── Aviso final para destinos em nuvem ───────────────────────────────────────
if $DEST_IS_CLOUD; then
  echo ""
  echo -e "${BOLD}Na nuvem, da pasta de configuração do Claude Code só foram as configurações. Ficaram na sua máquina: login, histórico e textos das conversas, senhas de projetos (.env) e chaves. Pra levar tudo, use pendrive ou pasta local.${RESET}"
  [[ "$SETTINGS_STATUS" == "limpo" ]] && \
    info "O settings.json foi sem os valores do bloco env; o restore.sh lista o que precisar ser preenchido."

  echo ""
  echo -e "${BOLD}${YELLOW}"
  cat << SYNC_WARN
╔══════════════════════════════════════════════════════════════╗
║  ⚠  AGUARDE O SYNC ANTES DE FORMATAR A MÁQUINA              ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  O arquivo foi salvo numa pasta que sincroniza com a nuvem.  ║
║  O upload para a nuvem acontece em segundo plano.            ║
║                                                              ║
║  NÃO formate a máquina até confirmar o upload:               ║
SYNC_WARN

  if [[ "$DEST_TYPE" == "icloud" ]]; then
    echo -e "║    • Mac: ícone iCloud na barra de menu pare de girar        ║"
    echo -e "║    • Ou: icloud.com → confirme o arquivo lá                  ║"
  elif [[ "$DEST_TYPE" == "gdrive" ]]; then
    echo -e "║    • Ícone Google Drive na barra de menu pare de girar       ║"
    echo -e "║    • Ou: drive.google.com → confirme o arquivo lá            ║"
  else
    echo -e "║    • Confira no site ou no app da nuvem que o arquivo subiu  ║"
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
  1. $(if $DEST_IS_CLOUD; then echo "Confirme o upload na nuvem antes de prosseguir"; else echo "Guarde o arquivo em local seguro"; fi)
  2. Formate a máquina
  3. Instale o Claude Code: ${BLUE}https://claude.ai/code${RESET}
  4. Restaure com: ${BLUE}bash restore.sh${RESET}

${BOLD}by Tadeu Rosa — CC BY-NC-ND 4.0${RESET}
"
