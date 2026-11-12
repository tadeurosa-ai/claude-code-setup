#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Claude Code Restore — by Tadeu Rosa
# Versão: 1.3.0
# Licença: MIT — veja o arquivo LICENSE
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

# ── Detecta OS ────────────────────────────────────────────────────────────────
OS="$(uname -s)"
IS_MAC=false; IS_WIN=false
case "$OS" in
  Darwin) IS_MAC=true ;;
  Linux)  ;;
  MINGW*|MSYS*|CYGWIN*) IS_WIN=true ;;
  *) error "Sistema não suportado: $OS" ;;
esac

# Permissão atual — sempre a do DESTINO quando o caminho é atalho (stat -L): a do próprio
# atalho é 777 no Linux e 755 no Mac, e usá-la deixaria o "só fecha" abrir a pasta
modo_atual() { if $IS_MAC; then stat -L -f %Lp "$1"; else stat -L -c %a "$1"; fi; }

# ── Banner ────────────────────────────────────────────────────────────────────
clear 2>/dev/null || true   # TERM=dumb e afins: limpar a tela não é essencial
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
# { … || true }: com pipefail, o head fechando o pipe mata o GNU tar (SIGPIPE, 141) e derrubava o restore
SNAP_CONTENTS="$({ tar -tzf "$SNAPSHOT" 2>/dev/null || true; } | head -5 | sed 's/^/    /')"
ok "Snapshot válido (${SNAP_SIZE})"
echo -e "${BLUE}  Conteúdo (primeiros itens):${RESET}"
echo "$SNAP_CONTENTS"
echo "    ..."

# ── Detecta conflito com setup existente ──────────────────────────────────────
section "Verificando destino"

# Snapshot novo (backup.sh 1.2.0+) traz a lista do que ficou de fora de propósito
TEM_REGRAS=false
if { LC_ALL=C tar -tzf "$SNAPSHOT" 2>/dev/null || true; } | grep -qx 'claude-code-backup-excluidos.txt'; then
  TEM_REGRAS=true
fi

HAS_EXISTING=false
[[ -d "$HOME/.claude" ]] && HAS_EXISTING=true
[[ -d "$HOME/claude"  ]] && HAS_EXISTING=true

if $HAS_EXISTING; then
  warn "Setup existente detectado em $HOME"
  echo ""
  echo -e "  O que deseja fazer com os arquivos atuais?"
  echo -e "  [1] Guardar os atuais numa pasta .anterior e substituir pelo snapshot  ${GREEN}(recomendado)${RESET}"
  if $TEM_REGRAS; then
    echo -e "      O que o backup deixou de fora de propósito (login, histórico, senhas) volta da .anterior;"
    echo -e "      o resto fica guardado nela."
  else
    echo -e "      (backup antigo: tudo o que está na pasta atual e não está no backup volta da .anterior)"
  fi
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

# ── Restauração ───────────────────────────────────────────────────────────────
section "Restaurando"

TMP_EXTRACT="$(mktemp -d)"
TMP_PROPRIO="$(mktemp -d)"   # registros do próprio restore (nunca dentro do que veio do snapshot)
trap 'rm -rf "$TMP_EXTRACT" "$TMP_PROPRIO"' EXIT
COLOCADOS="$TMP_PROPRIO/colocados"; : > "$COLOCADOS"   # atalhos cujo destino ESTE restore preencheu

# Extrai ANTES de mexer em qualquer pasta: snapshot com defeito para aqui.
info "Extraindo snapshot..."
LC_ALL=C tar -xzf "$SNAPSHOT" -C "$TMP_EXTRACT" 2>/dev/null || \
  error "Falha ao extrair snapshot. Nada foi alterado nas suas pastas."

# Informação gravada pelo backup.sh
INFO="$TMP_EXTRACT/claude-code-backup-info.txt"
SNAP_DESTINO=""; SNAP_SEGREDOS=""
if [[ -f "$INFO" ]]; then
  SNAP_DESTINO="$(sed -n 's/^destino=//p' "$INFO" | head -1)"
  SNAP_SEGREDOS="$(sed -n 's/^segredos=//p' "$INFO" | head -1)"
fi
REGRAS="$TMP_EXTRACT/claude-code-backup-excluidos.txt"
# Cada settings é decidido por ele mesmo: veio do snapshot se o snapshot o traz
# e (substituir, ou ele não existia aqui antes)
EXISTIA_SETTINGS=false;       [[ -e "$HOME/.claude/settings.json" ]] && EXISTIA_SETTINGS=true
EXISTIA_SETTINGS_LOCAL=false; [[ -e "$HOME/.claude/settings.local.json" ]] && EXISTIA_SETTINGS_LOCAL=true

RESTORE_TS="$(date +%Y%m%d-%H%M%S)"
ANT_PONTO_CLAUDE=""
# Pastas com permissão registrada que já existiam antes (no modo mesclar não são tocadas)
MODOS_EXISTIAM="$TMP_PROPRIO/modos-existiam"; : > "$MODOS_EXISTIAM"
if [[ -f "$INFO" ]]; then
  while IFS= read -r linha; do
    rel="${linha%%|*}"
    [[ -e "$HOME/$rel" ]] && printf '%s\n' "$rel" >> "$MODOS_EXISTIAM"
  done < <(sed -n 's/^modo=//p' "$INFO")
fi
RESTORED=0
# Pastas mexidas nesta execução (para desfazer se algo falhar)
FEITOS_DEST=()
FEITOS_ANT=()
ANTERIORES_MSG=""

# Devolve tudo ao estado de antes: apaga o que foi copiado e põe a .anterior no lugar
desfazer() {
  local i dest ant onde=""
  [[ ${#FEITOS_DEST[@]} -gt 0 ]] || return 0
  trap '' INT TERM     # um 2º Ctrl+C não pode interromper a volta
  warn "Desfazendo, aguarde: devolvendo as pastas originais ao lugar (não feche o terminal)..."
  for (( i=${#FEITOS_DEST[@]}-1; i>=0; i-- )); do
    dest="${FEITOS_DEST[$i]}"; ant="${FEITOS_ANT[$i]}"
    if [[ -n "$ant" ]]; then
      # .anterior não existe: a troca nem chegou a acontecer, e o destino ainda é o original
      if [[ ! -e "$ant" && ! -L "$ant" ]]; then
        onde="${onde}\n  • ${dest} — continua no lugar (não chegou a ser trocada)"
        continue
      fi
      rm -rf "$dest"
      if mv "$ant" "$dest"; then
        ok "Voltou para o lugar: $dest"
        onde="${onde}\n  • ${dest} — de volta no lugar"
      else
        warn "Não consegui devolver. Sua pasta original está em: $ant"
        onde="${onde}\n  • ${dest} — NÃO voltou: a original está em ${ant}"
      fi
    else
      rm -rf "$dest"
      onde="${onde}\n  • ${dest} — retirada (não existia antes do restore)"
    fi
  done
  FEITOS_DEST=(); FEITOS_ANT=()
  echo -e "${BOLD}Onde ficou cada pasta:${RESET}${onde}"
}

# Ctrl+C ou kill durante a troca: desfaz e diz onde está cada coisa
interrompido() {
  trap '' INT TERM
  echo ""
  warn "Restore interrompido."
  desfazer
  echo -e "${YELLOW}  Nada foi perdido: confira acima onde ficou cada pasta.${RESET}" >&2
  exit 130
}
trap interrompido INT TERM

# Nome livre para guardar o que está no lugar: o próprio, ou com -2, -3… se já existir
# (assim, ver a .anterior depois significa que a troca aconteceu de verdade)
livre() {
  local c="$1" n=2
  while [[ -e "$c" || -L "$c" ]]; do c="$1-$n"; n=$((n+1)); done
  printf '%s' "$c"
}

# Caminho seguro vindo do snapshot: relativo, dentro de .claude/ ou claude/, sem ".."
caminho_ok() {
  case "$1" in
    /*|..|../*|*/..|*/../*) return 1 ;;
    .claude/*|claude/*) return 0 ;;
    *) return 1 ;;
  esac
}

# Nenhum pedaço do caminho é atalho — a não ser atalho cujo destino este restore preencheu
# (o registro é do próprio restore, nunca do snapshot)
sem_atalho_alheio() {  # sem_atalho_alheio <rel> <base> [arquivo-de-colocados]
  local resto="$1" pre="" parte
  while [[ -n "$resto" ]]; do
    parte="${resto%%/*}"
    if [[ "$resto" == */* ]]; then resto="${resto#*/}"; else resto=""; fi
    pre="${pre:+$pre/}$parte"
    if [[ -L "$2/$pre" ]]; then
      [[ -n "${3:-}" ]] && grep -qxF -- "$pre" "$3" && continue
      return 1
    fi
  done
  return 0
}

# Destino de atalho vindo do snapshot: relativo à pasta pessoal, sem ".." e sem "/" no início
destino_ok() {
  case "$1" in
    ""|/*|.|..|../*|*/..|*/../*|./*|*/./*|*/.) return 1 ;;
    *) return 0 ;;
  esac
}

# Backup antigo (sem regras): copia da .anterior tudo o que NÃO veio no snapshot
TRAZIDOS=0
trazer_de_volta() {
  local ant="$1" dest="$2" file rel target
  TRAZIDOS=0
  while IFS= read -r -d '' file; do
    rel="${file#"$ant"/}"
    target="$dest/$rel"
    [[ -e "$target" || -L "$target" ]] && continue
    if ! mkdir -p "${target%/*}" 2>/dev/null; then
      warn "Não trouxe de volta (conflito de nome com o snapshot): $rel"
      continue
    fi
    cp -Rp "$file" "$target" || return 1
    (( TRAZIDOS++ )) || true
  done < <(find -H "$ant" \( -type f -o -type l \) -print0 2>/dev/null)
  return 0
}

# Backup novo: traz da .anterior só o que o backup deixou de fora de propósito
#   pasta   <caminho>  pasta que ficou inteira de fora → volta inteira
#   resto   <caminho>  pasta que entrou em parte → volta o que o snapshot não trouxe
#   arquivo <caminho>  arquivo que ficou de fora → volta
trazer_por_regras() {
  local raiz="$1" ant="$2" dest="$3" registro tipo cam rel base item r lista
  TRAZIDOS=0
  lista="$TMP_PROPRIO/trazer-$raiz"
  : > "$lista"
  while IFS= read -r -d '' registro; do
    tipo="${registro%%$'\t'*}"; cam="${registro#*$'\t'}"
    if ! caminho_ok "$cam"; then
      warn "Regra ignorada (caminho inválido no snapshot): $cam"
      continue
    fi
    case "$cam" in "$raiz"/*) ;; *) continue ;; esac
    rel="${cam#"$raiz"/}"
    base="$ant/$rel"
    [[ -e "$base" || -L "$base" ]] || continue
    case "$tipo" in
      arquivo)
        if [[ ! -e "$dest/$rel" && ! -L "$dest/$rel" ]]; then
          printf '%s\0' "$rel" >> "$lista"; (( TRAZIDOS++ )) || true
        fi ;;
      pasta|resto)
        while IFS= read -r -d '' item; do
          r="${item#"$ant"/}"
          if [[ ! -e "$dest/$r" && ! -L "$dest/$r" ]]; then
            printf '%s\0' "$r" >> "$lista"; (( TRAZIDOS++ )) || true
          fi
        done < <(find -P "$base" -print0 2>/dev/null)
        ;;
      *) warn "Regra desconhecida ignorada: $tipo" ;;
    esac
  done < "$REGRAS"
  [[ -s "$lista" ]] || return 0
  ( cd "$ant" && LC_ALL=C tar --no-recursion -cf - --null -T "$lista" ) | \
    ( cd "$dest" && LC_ALL=C tar -xpf - )
}

restore_dir() {
  local src_name="$1"   # .claude ou claude
  local src="$TMP_EXTRACT/$src_name"
  local dest="$HOME/$src_name"
  local ant=""

  # Pasta que não está no snapshot não é tocada
  [[ -d "$src" ]] || return 0

  if [[ "$RESTORE_MODE" == "replace" ]]; then
    # 1. Tira a pasta atual do lugar (nunca apaga)
    [[ -e "$dest" || -L "$dest" ]] && ant="$(livre "$dest.anterior-$RESTORE_TS")"
    [[ "$src_name" == .claude ]] && ANT_PONTO_CLAUDE="$ant"
    FEITOS_DEST+=("$dest"); FEITOS_ANT+=("$ant")   # registrado antes da troca (Ctrl+C no meio)
    if [[ -n "$ant" ]] && ! mv "$dest" "$ant"; then
      desfazer
      error "Não consegui mover ~/$src_name para $(basename "$ant"). Nada foi alterado."
    fi

    # 2. Copia o snapshot
    if ! cp -Rp "$src" "$dest"; then
      desfazer
      error "A cópia de ~/$src_name falhou. Suas pastas originais voltaram para o lugar."
    fi

    # 3. Traz de volta o que o snapshot não trouxe
    if [[ -n "$ant" ]]; then
      if [[ -f "$REGRAS" ]]; then
        trazer_por_regras "$src_name" "$ant" "$dest" || {
          desfazer
          error "Falha ao trazer arquivos de $(basename "$ant"). Suas pastas originais voltaram para o lugar."
        }
        ok "Restaurado: ~/$src_name ($TRAZIDOS item(ns) que o backup deixou de fora vieram da pasta anterior)"
      else
        trazer_de_volta "$ant" "$dest" || {
          desfazer
          error "Falha ao trazer arquivos de $(basename "$ant"). Suas pastas originais voltaram para o lugar."
        }
        ok "Restaurado: ~/$src_name ($TRAZIDOS arquivo(s) que não estavam no snapshot vieram da pasta anterior)"
      fi
      ANTERIORES_MSG="${ANTERIORES_MSG}\n  • ${ant}"
    else
      ok "Restaurado: ~/$src_name"
    fi
    (( RESTORED++ )) || true

  else
    # Merge: copia apenas arquivos ausentes no destino
    mkdir -p "$dest"
    local count=0
    while IFS= read -r -d '' file; do
      rel="${file#"$src"/}"
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

# Permissões registradas: a pasta já nasce fechada (grupo/outros) — aplicadas na extração,
# antes de copiar; o dono continua podendo gravar até o fim (o modo completo vem no final)
if [[ -f "$INFO" ]] && grep -q '^modo=' "$INFO"; then
  while IFS= read -r linha; do
    rel="${linha%%|*}"; m="${linha#*|}"
    [[ "$rel" == .claude || "$rel" == claude ]] || caminho_ok "$rel" || continue
    [[ "$m" =~ ^[0-7]{3,4}$ && -d "$TMP_EXTRACT/$rel" ]] || continue
    sem_atalho_alheio "$rel" "$TMP_EXTRACT" || continue
    cur="$(modo_atual "$TMP_EXTRACT/$rel" 2>/dev/null)" || continue
    [[ "$cur" =~ ^[0-7]{3,4}$ ]] || continue
    chmod "$(printf '%o' $(( (8#$cur & 8#700) | (8#$m & 8#$cur & 8#077) )))" "$TMP_EXTRACT/$rel" 2>/dev/null || true
  done < <(sed -n 's/^modo=//p' "$INFO")
fi

restore_dir ".claude"
restore_dir "claude"

[[ $RESTORED -eq 0 ]] && error "Nenhum diretório do Claude Code encontrado no snapshot"

# ── Atalhos de ~/.claude (ex.: skills -> ~/claude/skills) ────────────────────
ANT_ALVO_SETTINGS=""; ANT_ALVO_SETTINGS_LOCAL=""
if [[ -f "$INFO" ]] && grep -q '^atalho=' "$INFO"; then
  section "Atalhos"
  while IFS= read -r linha <&4; do
    item="${linha%%|*}"; alvo_rel="${linha#*|}"
    nome_item="${item#.claude/}"
    if [[ "$item" == "$linha" || "$nome_item" == "$item" || "$nome_item" == */* || -z "$nome_item" ]] \
       || ! destino_ok "$alvo_rel" ; then
      warn "Atalho ignorado (informação inválida no snapshot): $linha"
      continue
    fi
    link="$HOME/$item"; alvo="$HOME/$alvo_rel"
    if [[ -e "$TMP_EXTRACT/$item" && ! -L "$TMP_EXTRACT/$item" && "$RESTORE_MODE" == "replace" && -e "$link" && ! -L "$link" ]]; then
      # O conteúdo veio no snapshot: vai para o destino do atalho, e o atalho é recriado.
      # Destino que já existe fora de ~/.claude e ~/claude só é substituído com "s".
      case "$alvo_rel" in .claude|.claude/*|claude|claude/*) fora_das_pastas=false ;; *) fora_das_pastas=true ;; esac
      if $fora_das_pastas && [[ -e "$alvo" || -L "$alvo" ]]; then
        echo ""
        warn "O backup quer pôr o conteúdo de ~/$item em ~/$alvo_rel, que já existe e fica fora de ~/.claude e ~/claude."
        warn "Se responder não, ~/$item volta como cópia comum (sem atalho): o que você editar depois não chega a ~/$alvo_rel."
        RESP=""
        read -rp "  Substituir ~/$alvo_rel? (o que está lá fica guardado numa pasta .anterior) [s/N]: " RESP || RESP=""
        if [[ ! "$(echo "$RESP" | tr '[:upper:]' '[:lower:]')" =~ ^(s|sim|y|yes)$ ]]; then
          warn "~/$alvo_rel não foi tocado. O conteúdo do backup ficou em ~/$item (cópia comum, sem atalho)."
          continue
        fi
      fi
      ant_alvo=""
      [[ -e "$alvo" || -L "$alvo" ]] && ant_alvo="$(livre "$alvo.anterior-$RESTORE_TS")"
      FEITOS_DEST+=("$alvo"); FEITOS_ANT+=("$ant_alvo")   # registrado antes da troca (Ctrl+C no meio)
      if [[ -n "$ant_alvo" ]]; then
        mv "$alvo" "$ant_alvo" || { desfazer; error "Não consegui guardar $alvo. Suas pastas originais voltaram para o lugar."; }
      fi
      mkdir -p "$(dirname "$alvo")" && mv "$link" "$alvo" && ln -s "$alvo" "$link" || {
        desfazer
        error "Falha ao recriar o atalho ~/$item. Suas pastas originais voltaram para o lugar."
      }
      printf '%s\n' "$item" >> "$COLOCADOS"
      case "$nome_item" in
        settings.json)       ANT_ALVO_SETTINGS="$ant_alvo" ;;
        settings.local.json) ANT_ALVO_SETTINGS_LOCAL="$ant_alvo" ;;
      esac
      if [[ -n "$ant_alvo" ]]; then
        ok "~/$item → ~/$alvo_rel (conteúdo do backup; o que estava lá ficou em ${ant_alvo})"
      else
        ok "~/$item → ~/$alvo_rel (conteúdo do backup)"
      fi
      [[ -n "$ant_alvo" ]] && ANTERIORES_MSG="${ANTERIORES_MSG}\n  • ${ant_alvo}"
    elif [[ ! -e "$link" && ! -L "$link" ]]; then
      ln -s "$alvo" "$link"
      ok "~/$item → ~/$alvo_rel (atalho recriado)"
      [[ -e "$alvo" ]] || warn "O destino ~/$alvo_rel não existe nesta máquina: o atalho fica quebrado até ele existir."
    fi
  done 4< <(sed -n 's/^atalho=//p' "$INFO")
fi

# Atalhos que apontavam para fora da pasta pessoal (ex.: outro disco): o backup levou
# o conteúdo, sem o caminho; aqui eles voltam como pasta comum
if [[ -f "$INFO" ]] && grep -q '^atalho_fora=' "$INFO"; then
  while IFS= read -r item; do
    nome_item="${item#.claude/}"
    [[ "$nome_item" != "$item" && -n "$nome_item" && "$nome_item" != */* && "$nome_item" != .. ]] || continue
    warn "~/$item era atalho para fora da pasta pessoal: voltou como pasta comum (cópia). Se quiser o atalho de volta, recrie-o."
  done < <(sed -n 's/^atalho_fora=//p' "$INFO")
fi

# ── settings sem segredos: valores do bloco "env" e tokens com marcador ──────
# Backup para a nuvem ou local sem senhas: o settings vem com o "env" vazio e
# tokens trocados por <<removido-pelo-backup>>. Aqui: repõe da pasta anterior;
# sem valor para repor, tira a chave vazia do env / deixa o marcador e lista.
REPOR=0; [[ "$SNAP_DESTINO" == "nuvem" || "$SNAP_SEGREDOS" == "nao" ]] && REPOR=1
SECAO_SETTINGS=false
if ! command -v python3 &>/dev/null; then
  [[ $REPOR == 1 ]] && warn "python3 não encontrado: confira o bloco env e os <<removido-pelo-backup>> do ~/.claude/settings.json."
else
    for nome_settings in settings.json settings.local.json; do
      ATUAL="$HOME/.claude/$nome_settings"
      [[ -f "$TMP_EXTRACT/.claude/$nome_settings" && -f "$ATUAL" ]] || continue
      if [[ "$nome_settings" == settings.json ]]; then existia=$EXISTIA_SETTINGS; else existia=$EXISTIA_SETTINGS_LOCAL; fi
      [[ "$RESTORE_MODE" == "replace" ]] || ! $existia || continue   # não veio do snapshot: não mexe
      if [[ $REPOR == 1 ]] && ! $SECAO_SETTINGS; then section "Chaves do settings"; SECAO_SETTINGS=true; fi
      # settings que era atalho: a versão anterior é a que estava no destino do atalho
      ANTERIOR=""; [[ -n "$ANT_PONTO_CLAUDE" ]] && ANTERIOR="$ANT_PONTO_CLAUDE/$nome_settings"
      [[ "$nome_settings" == settings.json && -n "$ANT_ALVO_SETTINGS" ]] && ANTERIOR="$ANT_ALVO_SETTINGS"
      [[ "$nome_settings" == settings.local.json && -n "$ANT_ALVO_SETTINGS_LOCAL" ]] && ANTERIOR="$ANT_ALVO_SETTINGS_LOCAL"
      if SAIDA="$(python3 - "$ATUAL" "$ANTERIOR" "$REPOR" <<'PY'
import json, os, re, sys, tempfile
MARCADOR = "<<removido-pelo-backup>>"
atual, anterior, repor_ok = os.path.realpath(sys.argv[1]), sys.argv[2], sys.argv[3] == "1"
with open(atual, encoding="utf-8") as f:
    d = json.load(f)
antigo = {}
if os.path.isfile(anterior):
    try:
        with open(anterior, encoding="utf-8") as f:
            antigo = json.load(f)
    except Exception:
        antigo = {}
mudou = False
repostas, faltam_env, faltam_marc = 0, [], []
# 1. env
env = d.get("env") if isinstance(d, dict) else None
env_ant = antigo.get("env") if isinstance(antigo, dict) else None
if repor_ok and isinstance(env, dict):
    for k in [k for k, v in env.items() if v == ""]:
        if isinstance(env_ant, dict) and k in env_ant:
            if env_ant[k] != "":
                env[k] = env_ant[k]; repostas += 1; mudou = True   # qualquer valor: texto, número, booleano
        else:
            del env[k]; faltam_env.append(k); mudou = True
# 2. marcador: só repõe se a .anterior tiver UM texto igual fora do marcador
textos_ant = []
def coletar(o):
    if isinstance(o, dict):
        for v in o.values(): coletar(v)
    elif isinstance(o, list):
        for v in o: coletar(v)
    elif isinstance(o, str) and MARCADOR not in o:
        textos_ant.append(o)
if repor_ok:
    coletar(antigo)
def repor(o, cam):
    global mudou, repostas
    if isinstance(o, dict):
        return {k: repor(v, f"{cam}.{k}" if cam else k) for k, v in o.items()}
    if isinstance(o, list):
        return [repor(v, f"{cam}[{i}]") for i, v in enumerate(o)]
    if isinstance(o, str) and MARCADOR in o:
        rx = re.compile("(?s)" + "(.+?)".join(re.escape(p) for p in o.split(MARCADOR)) + r"\Z")
        achados = {t for t in textos_ant if rx.match(t)}
        if len(achados) == 1:
            mudou = True; repostas += 1
            return achados.pop()
        faltam_marc.append(cam)
    return o
if repor_ok:
    d = repor(d, "")
# Permissão: nunca mais aberta que a do arquivo de antes; sem arquivo de antes, só o dono (600)
modo = os.stat(atual).st_mode & 0o777
modo &= (os.stat(anterior).st_mode & 0o777) if os.path.isfile(anterior) else 0o600
bytes_antes = None
if os.path.isfile(anterior) and d == antigo:
    with open(anterior, "rb") as a:
        bytes_antes = a.read()
    with open(atual, "rb") as a:
        if a.read() == bytes_antes:
            bytes_antes = None      # já está idêntico
if mudou or bytes_antes is not None:
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(atual), prefix=".settings.", suffix=".tmp")
    os.chmod(tmp, 0o600)
    with os.fdopen(fd, "wb") as f:
        if bytes_antes is not None:
            f.write(bytes_antes)    # ficou igual ao de antes: o arquivo de antes, com a formatação original
        else:
            f.write((json.dumps(d, indent=2, ensure_ascii=False) + "\n").encode("utf-8"))
    with open(tmp, encoding="utf-8") as f:
        json.load(f)
    os.chmod(tmp, modo)
    os.replace(tmp, atual)
else:
    os.chmod(atual, modo)
print("REPOSTAS=" + str(repostas))
print("FALTAM_ENV=" + ",".join(faltam_env))
print("FALTAM_MARC=" + ",".join(faltam_marc))
PY
)"; then
        N_REPOSTAS="$(printf '%s\n' "$SAIDA" | sed -n 's/^REPOSTAS=//p')"
        FALTAM_ENV="$(printf '%s\n' "$SAIDA" | sed -n 's/^FALTAM_ENV=//p')"
        FALTAM_MARC="$(printf '%s\n' "$SAIDA" | sed -n 's/^FALTAM_MARC=//p')"
        [[ -n "$N_REPOSTAS" && "$N_REPOSTAS" != "0" ]] && \
          ok "$nome_settings: $N_REPOSTAS valor(es) repostos a partir da pasta anterior"
        if [[ -n "$FALTAM_ENV" ]]; then
          warn "$nome_settings: estas chaves do bloco env vieram sem valor e foram retiradas:"
          printf '%s\n' "$FALTAM_ENV" | tr ',' '\n' | sed 's/^/      • /'
          warn "Se precisar delas, acrescente de novo com o valor certo."
        fi
        if [[ -n "$FALTAM_MARC" ]]; then
          warn "$nome_settings: preencha o token no lugar de <<removido-pelo-backup>> em:"
          printf '%s\n' "$FALTAM_MARC" | tr ',' '\n' | sed 's/^/      • /'
          warn "Um hook com o marcador não funciona até ser preenchido."
        fi
      else
        warn "Não consegui ajustar o ~/.claude/$nome_settings — confira o bloco env à mão."
      fi
    done
fi

# Permissões das pastas que o backup registrou (ex.: ~/.claude só para o dono).
# Por último (depois de repor as chaves) e só fechando: nunca abre mais do que está.
# Modo mesclar: só nas pastas que este restore criou.
if [[ -f "$INFO" ]] && grep -q '^modo=' "$INFO"; then
  while IFS= read -r linha; do
    rel="${linha%%|*}"; m="${linha#*|}"
    [[ "$rel" == .claude || "$rel" == claude ]] || caminho_ok "$rel" || continue
    [[ "$m" =~ ^[0-7]{3,4}$ && -d "$HOME/$rel" ]] || continue
    sem_atalho_alheio "$rel" "$HOME" "$COLOCADOS" || continue
    [[ "$RESTORE_MODE" == "merge" ]] && grep -qxF -- "$rel" "$MODOS_EXISTIAM" && continue
    cur="$(modo_atual "$HOME/$rel" 2>/dev/null)" || continue
    [[ "$cur" =~ ^[0-7]{3,4}$ ]] || continue
    chmod "$(printf '%o' $(( 8#$m & 8#$cur & 8#777 )))" "$HOME/$rel" 2>/dev/null || true
  done < <(sed -n 's/^modo=//p' "$INFO")
fi

trap - INT TERM

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
[[ "$SNAP_DESTINO" == "nuvem" ]] || check_exists "claude/projetos" "Projetos"

# ── Resumo final ──────────────────────────────────────────────────────────────
section "Concluído"

WARN_MSG=""
[[ $WARNINGS -gt 0 ]] && WARN_MSG="\n${YELLOW}  ⚠ $WARNINGS aviso(s) acima — verifique se é esperado${RESET}\n"

if [[ "$SNAP_DESTINO" == "nuvem" ]]; then
  RESTAURADO_MSG="\n  • ~/.claude/  — só as configurações (backup feito para a nuvem)\n  • ~/claude/   — não estava no backup; ficou como estava"
elif [[ "$SNAP_SEGREDOS" == "nao" ]]; then
  RESTAURADO_MSG="\n  • ~/.claude/  — configurações, skills, hooks, memória (sem login, senhas e chaves)\n  • ~/claude/   — projetos e chats (sem .env e chaves)"
else
  RESTAURADO_MSG="\n  • ~/.claude/  — configurações, skills, hooks, memória\n  • ~/claude/   — projetos e chats"
fi
[[ -n "$ANTERIORES_MSG" ]] && \
  RESTAURADO_MSG="${RESTAURADO_MSG}\n  O que o backup deixou de fora de propósito voltou da pasta anterior (contagem acima)."

SAFETY_MSG=""
[[ -n "$ANTERIORES_MSG" ]] && \
  SAFETY_MSG="\n${BOLD}Seu setup anterior ficou guardado em:${RESET}${ANTERIORES_MSG}\n  Confira que está tudo certo e apague essa(s) pasta(s) depois, se quiser.\n"

echo -e "
${GREEN}${BOLD}✓ Restore concluído com sucesso!${RESET}
${WARN_MSG}
${BOLD}O que foi restaurado:${RESET}${RESTAURADO_MSG}
${SAFETY_MSG}
${BOLD}Próximos passos:${RESET}
  1. Abra o Claude Code: ${BLUE}claude${RESET}
  2. Teste com: ${BLUE}/help${RESET}
  3. Se algo parecer errado: ${BLUE}bash repair.sh${RESET}

${BOLD}by Tadeu Rosa — MIT (scripts) · CC BY 4.0 (skills e textos)${RESET}
"
