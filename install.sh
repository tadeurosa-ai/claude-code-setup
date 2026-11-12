#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Claude Code Setup — by Tadeu Rosa
# Versão: 2.0.0
# github.com/tadeurosa-ai/claude-code-setup
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

REPO_URL="https://github.com/tadeurosa-ai/claude-code-setup"
CHECKPOINT_FILE=""

# ── Cores ─────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${BLUE}▸${RESET} $*"; }
ok()      { echo -e "${GREEN}✓${RESET} $*"; }
warn()    { echo -e "${YELLOW}⚠${RESET} $*"; }
error()   { echo -e "${RED}✗${RESET} $*" >&2; exit 1; }
section() { echo -e "\n${BOLD}── $* ──────────────────────────────────────────${RESET}"; }

# Caminho real (segue atalhos). Sem python3: o próprio caminho.
real_path() {
  python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$1" 2>/dev/null || printf '%s\n' "$1"
}

# Escrita atômica no caminho REAL: se o arquivo é um atalho, o atalho continua atalho
write_atomic() {
  local target tmp
  target="$(real_path "$1")"
  tmp="$(mktemp "$(dirname "$target")/.$(basename "$target").XXXXXX")"
  cat > "$tmp"
  mv "$tmp" "$target"
}

is_valid_json() {
  command -v python3 &>/dev/null || return 0  # sem python3: assume válido, preserva arquivo
  python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$1" 2>/dev/null
}

# ── Bootstrap: detecta execução via curl | bash ───────────────────────────────
_SELF="${BASH_SOURCE[0]:-}"
if [[ -z "$_SELF" || "$_SELF" == "/dev/stdin" || "$_SELF" == "bash" ]]; then
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  info "Downloading / Baixando repositório..."
  if command -v git &>/dev/null; then
    git clone --depth=1 --quiet "$REPO_URL" "$TMP/repo"
  elif command -v curl &>/dev/null; then
    curl -fsSL "$REPO_URL/archive/refs/heads/main.tar.gz" | tar -xz -C "$TMP"
    mv "$TMP/claude-code-setup-main" "$TMP/repo"
  else
    error "git or curl required. / Precisa de git ou curl instalado."
  fi
  exec bash "$TMP/repo/install.sh"
fi

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
              CODE SETUP — by Tadeu Rosa
BANNER
echo -e "${RESET}"
echo -e "  Setting up your professional Claude Code workspace...\n"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Funções das skills, comuns ao install.sh e ao repair.sh
[[ -f "$SCRIPT_DIR/lib/skills-comum.sh" ]] || \
  error "lib/skills-comum.sh not found next to install.sh ($SCRIPT_DIR). Download the whole repository again and run install.sh from it. Nothing was changed."
# shellcheck source=lib/skills-comum.sh
. "$SCRIPT_DIR/lib/skills-comum.sh"

# ── Detecta OS ────────────────────────────────────────────────────────────────
section "System check"

OS="$(uname -s)"
# Windows: este setup roda no macOS, no Linux e no WSL (que se apresenta como Linux)
[[ "$OS" == "Darwin" || "$OS" == "Linux" ]] || \
  { echo -e "${YELLOW}⚠ Windows detected — this setup runs on macOS, Linux or WSL. Open your WSL terminal (e.g. Ubuntu) and run the install command there.${RESET}"; exit 1; }
ok "OS: $OS"

if ! command -v git &>/dev/null; then
  error "Git not found.\n  Mac: xcode-select --install\n  Linux: sudo apt install git"
fi
ok "Git: $(git --version | head -1)"

_DISK_FREE="$(df -m "$HOME" 2>/dev/null | awk 'NR==2{print $4}' || echo 9999)"
if [[ "$_DISK_FREE" -lt 100 ]] 2>/dev/null; then
  error "Not enough disk space (${_DISK_FREE}MB free). Free at least 100MB and try again."
fi
ok "Disk: ${_DISK_FREE}MB free"

# ~/.local/bin (onde o instalador oficial põe o claude) já estava no caminho? Medido aqui,
# ANTES de o script acrescentar a pasta. Se não estava, o fim da tela diz como pôr.
LOCALBIN_JA_ESTAVA=false
case ":$PATH:" in *":$HOME/.local/bin:"*|*":$HOME/.local/bin/:"*) LOCALBIN_JA_ESTAVA=true ;; esac
PATH_TIP=""

if ! command -v claude &>/dev/null; then
  warn "Claude Code CLI not found — installing automatically..."
  echo ""

  if ! command -v curl &>/dev/null; then
    echo -e "${RED}✗ curl not found — the official Claude Code installer needs it.${RESET}" >&2
    echo -e "  Install curl and run this script again (Ubuntu/Debian: ${BLUE}sudo apt install curl${RESET})."
    exit 1
  fi

  # Instalador oficial (nativo): https://code.claude.com/docs/en/setup
  # Ele põe o claude em ~/.local/bin; com pipefail, falha no download também conta como erro.
  info "Installing with the official installer (it shows no progress while it downloads)..."
  if ! curl -fsSL https://claude.ai/install.sh | bash; then
    echo ""
    echo -e "${RED}✗ Could not install Claude Code automatically.${RESET}" >&2
    echo ""
    echo -e "  Install it with the official command and run this script again:"
    echo -e "  ${BLUE}curl -fsSL https://claude.ai/install.sh | bash${RESET}"
    echo -e "  Help: ${BLUE}https://code.claude.com/docs/en/setup${RESET}"
    exit 1
  fi
  echo ""

  export PATH="$HOME/.local/bin:$PATH"

  if ! command -v claude &>/dev/null; then
    echo -e "${RED}✗ The official installer finished, but claude was not found in ~/.local/bin.${RESET}" >&2
    echo -e "  Help: ${BLUE}https://code.claude.com/docs/en/troubleshoot-install${RESET}"
    exit 1
  fi

  # Instalado em ~/.local/bin, que não estava no caminho: o comando certo para o terminal da pessoa
  # (doc oficial, "Verify your PATH"). O script não mexe nos arquivos do terminal.
  if ! $LOCALBIN_JA_ESTAVA && [[ "$(command -v claude)" == "$HOME/.local/bin/claude" ]]; then
    _rc=""
    case "$(basename "${SHELL:-}")" in
      zsh) _rc="~/.zshrc" ;;
      bash)
        if [[ "$OS" == "Darwin" ]]; then   # Terminal do Mac abre o bash como login: lê o 1º que existir
          if [[ -f "$HOME/.bash_profile" ]]; then _rc="~/.bash_profile"
          elif [[ -f "$HOME/.bash_login" ]]; then _rc="~/.bash_login"
          elif [[ -f "$HOME/.profile" ]]; then _rc="~/.profile"
          else _rc="~/.bash_profile"; fi
        else
          _rc="~/.bashrc"
        fi ;;
    esac
    if [[ -n "$_rc" ]]; then
      PATH_TIP="${BOLD}Before opening Claude Code:${RESET} the folder it was installed in (~/.local/bin) is not in your terminal's PATH. Run this once:
  ${BLUE}echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> $_rc${RESET}
  Then open a new terminal window.
"
    else
      PATH_TIP="${BOLD}Before opening Claude Code:${RESET} the folder it was installed in (~/.local/bin) is not in your terminal's PATH.
  Add it in your shell's configuration (see ${BLUE}https://code.claude.com/docs/en/troubleshoot-install#verify-your-path${RESET}),
  then open a new terminal window.
"
    fi
  fi
fi

# claude achado mas sem responder à versão: para aqui, em vez de seguir até "installed successfully"
if ! _CLAUDE_VER="$(claude --version 2>/dev/null | head -1)" || [[ -z "$_CLAUDE_VER" ]]; then
  echo -e "${RED}✗ Claude Code was found ($(command -v claude)) but 'claude --version' did not answer.${RESET}" >&2
  echo -e "  Help: ${BLUE}https://code.claude.com/docs/en/troubleshoot-install${RESET}"
  exit 1
fi
ok "Claude Code: $_CLAUDE_VER"

CHECKPOINT_FILE="$HOME/.claude-install-checkpoint"

# ── Detecta instalação anterior interrompida ──────────────────────────────────
if [[ -f "$CHECKPOINT_FILE" ]] && [[ "$(cat "$CHECKPOINT_FILE")" != "started" ]]; then
  LAST_STAGE="$(cat "$CHECKPOINT_FILE" 2>/dev/null || echo 'desconhecido')"
  warn "Instalação anterior interrompida detectada (última etapa: ${BOLD}$LAST_STAGE${RESET}${YELLOW})"
  warn "Execute ${BOLD}bash repair.sh${RESET}${YELLOW} para diagnóstico completo."
  echo ""
  info "Continuando instalação do ponto de falha..."
fi

# Escreve checkpoint — qualquer interrupção a partir daqui é detectável
echo "started" > "$CHECKPOINT_FILE"

# ── Limpa backups corrompidos de runs anteriores ──────────────────────────────
section "Backup"

for old_backup in "$HOME"/.claude-backup-*.tar.gz; do
  [[ -f "$old_backup" ]] || continue
  if ! tar -tzf "$old_backup" &>/dev/null; then
    rm -f "$old_backup"
  fi
done

BACKUP_FILE="$HOME/.claude-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
BACKUP_OK=false

echo "backup_start" > "$CHECKPOINT_FILE"

if [[ -d "$HOME/.claude" ]]; then
  info "Previous setup found — backing up..."
  if tar -czf "$BACKUP_FILE" -C "$HOME" .claude 2>/dev/null \
     && tar -tzf "$BACKUP_FILE" &>/dev/null; then
    BACKUP_OK=true
    ok "Backup verified: $(basename "$BACKUP_FILE")"
  else
    rm -f "$BACKUP_FILE"
    warn "Backup failed — continuing without backup."
  fi
else
  info "No previous setup — clean install."
fi

# ── Estrutura de diretórios ───────────────────────────────────────────────────
section "Creating folder structure"

echo "dirs" > "$CHECKPOINT_FILE"

DIRS=(
  "$HOME/.claude"
  "$HOME/.claude/skills"
  "$HOME/.claude/hooks"
  "$HOME/.claude/hooks/pre-tool"
  "$HOME/.claude/hooks/post-tool"
  "$HOME/.claude/hooks/stop"
  "$HOME/.claude/projects"
  "$HOME/claude"
  "$HOME/claude/projetos/01-ideias"
  "$HOME/claude/projetos/02-prospeccao"
  "$HOME/claude/projetos/03-em-andamento"
  "$HOME/claude/projetos/04-pausado"
  "$HOME/claude/projetos/05-concluido"
  "$HOME/claude/projetos/06-abandonado"
  "$HOME/claude/chats"
  "$HOME/claude/chats/.history"
)

for dir in "${DIRS[@]}"; do
  mkdir -p "$dir"
done
ok "Structure created (${#DIRS[@]} folders)"

# ── CLAUDE.md ─────────────────────────────────────────────────────────────────
section "Installing CLAUDE.md"

echo "claude_md" > "$CHECKPOINT_FILE"

if [[ -f "$SCRIPT_DIR/config/CLAUDE.md" ]]; then
  if [[ -f "$HOME/.claude/CLAUDE.md" ]] && [[ -s "$HOME/.claude/CLAUDE.md" ]]; then
    write_atomic "$HOME/.claude/CLAUDE.md.example" < "$SCRIPT_DIR/config/CLAUDE.md"
    warn "CLAUDE.md already exists — template saved to ~/.claude/CLAUDE.md.example"
    warn "Review and merge manually if needed."
  else
    write_atomic "$HOME/.claude/CLAUDE.md" < "$SCRIPT_DIR/config/CLAUDE.md"
    ok "CLAUDE.md installed"
  fi
fi

# ── Skills ────────────────────────────────────────────────────────────────────
section "Installing skills"

echo "skills" > "$CHECKPOINT_FILE"

SKILLS_INSTALLED=0


# Guarda (nunca apaga) o que sai de ~/.claude/skills numa pasta única desta instalação
SKILLS_ANTIGAS=""; GUARDADO=""
# (chamar direto, nunca dentro de $( ): a pasta é criada uma vez e vale para a instalação toda)
guardar_antiga() {  # guardar_antiga <caminho> <nome dentro da pasta de antigas> → GUARDADO
  local dest n=2
  if [[ -z "$SKILLS_ANTIGAS" ]]; then
    local base="$HOME/.claude/skills-antigas-setup-$(date +%Y%m%d-%H%M%S)"
    SKILLS_ANTIGAS="$base"
    while [[ -e "$SKILLS_ANTIGAS" || -L "$SKILLS_ANTIGAS" ]]; do SKILLS_ANTIGAS="$base-$n"; n=$((n+1)); done
    mkdir -p "$SKILLS_ANTIGAS"
  fi
  dest="$SKILLS_ANTIGAS/$2"; n=2
  while [[ -e "$dest" || -L "$dest" ]]; do dest="$SKILLS_ANTIGAS/$2-$n"; n=$((n+1)); done
  mkdir -p "$(dirname "$dest")"
  mv "$1" "$dest" && GUARDADO="${dest#$HOME/}"
}

# Deixa a pasta com um só arquivo de skill, chamado SKILL.md, sem mexer no que é do usuário:
#  • renomeação interrompida (.SKILL.md.renomeando): termina; se já há SKILL.md, guarda;
#  • skill.md e SKILL.md juntos: ver acao_dois_nomes;
#  • só skill.md: do pacote (ou vazio) vira SKILL.md em dois passos (o Mac não diferencia
#    maiúscula); do usuário não é mexido.
avisar_editada() {  # avisar_editada <pasta> <arquivo>
  rodape_no_meio "$2" && warn "Skill '$(basename "$1")' looks like it came from this package and was edited after the footer — not migrated. To migrate it, delete what comes after the footer line in ~/${2#$HOME/} and run the installer again."
  return 0
}

dois_nomes() {  # dois_nomes <pasta> <pasta do pacote: sim|nao> <outro nome>
  local d="$1" rel="${1#$HOME/}" sub="${1#$HOME/.claude/skills/}"
  case "$(acao_dois_nomes "$d" "$2" "$3")" in
    guardar)
      guardar_antiga "$d/$3" "$sub/$3" \
        && warn "Old ~/$rel/$3 (from this package) moved to ~/$GUARDADO — the folder keeps SKILL.md." ;;
    renomear)
      guardar_antiga "$d/SKILL.md" "$sub/SKILL.md.vazio" \
        && mv "$d/$3" "$d/.SKILL.md.renomeando" && mv "$d/.SKILL.md.renomeando" "$d/SKILL.md" \
        && warn "Empty ~/$rel/SKILL.md moved to ~/$GUARDADO; ~/$rel/$3 is now SKILL.md." ;;
    *)
      warn "~/$rel/$3 and ~/$rel/SKILL.md both exist — kept as is. Claude Code reads SKILL.md."
      avisar_editada "$d" "$d/$3" ;;
  esac
}

para_SKILL() {
  local d="$1" rel="${1#$HOME/}" f outro
  if [[ -f "$d/.SKILL.md.renomeando" ]]; then
    if arquivo_skill "$d" >/dev/null; then
      guardar_antiga "$d/.SKILL.md.renomeando" "${d#$HOME/.claude/skills/}/skill.md.interrompido" \
        && warn "Interrupted rename in ~/$rel: that copy was kept at ~/$GUARDADO"
    else
      mv "$d/.SKILL.md.renomeando" "$d/SKILL.md"
    fi
  fi
  if outro="$(nome_sobrando "$d")"; then
    dois_nomes "$d" "${2:-sim}" "$outro"
    return 0
  fi
  f="$(arquivo_skill "$d")" || return 0
  [[ "$(basename "$f")" == "SKILL.md" ]] && return 0
  if do_pacote "$f" || [[ ! -s "$f" ]]; then
    mv "$f" "$d/.SKILL.md.renomeando" && mv "$d/.SKILL.md.renomeando" "$d/SKILL.md"
  else
    avisar_editada "$d" "$f"
  fi
}

# /review, /debug e /context das versões antigas tinham nomes de comandos do Claude Code.
# As do pacote saem de ~/.claude/skills (guardadas, nunca apagadas); as do usuário ficam.
for velho in review debug context; do
  d="$HOME/.claude/skills/$velho"
  [[ -d "$d" && ! -L "$d" ]] || continue
  f="$(arquivo_skill "$d")" || continue
  if do_pacote "$f"; then
    guardar_antiga "$d" "$velho" && warn "Old skill /$velho moved to ~/$GUARDADO"
  elif rodape_no_meio "$f"; then
    avisar_editada "$d" "$f"
  elif [[ "$velho" == review ]]; then
    warn "Skill 'review' is yours (not from this package) — kept. Note: it may conflict with Claude Code's own /review."
  else
    warn "Skill '$velho' is yours (not from this package) — kept. Note: it replaces the built-in /$velho command."
  fi
done
# Fora das 11 pastas do pacote: só sai um skill.md reconhecido como do pacote quando já há
# um SKILL.md com conteúdo na mesma pasta. Nada mais é movido, renomeado ou trocado.
for d in "$HOME/.claude/skills"/*/; do
  d="${d%/}"
  [[ -d "$d" && ! -L "$d" ]] || continue
  [[ -d "$SCRIPT_DIR/skills/$(basename "$d")" ]] && continue
  outro="$(nome_sobrando "$d")" || continue
  dois_nomes "$d" nao "$outro"
done

if [[ -n "$SKILLS_ANTIGAS" ]]; then
  info "New names: /revisar-codigo (was /review), /depurar (was /debug), /contexto-projeto (was /context)."
fi

if [[ -d "$SCRIPT_DIR/skills" ]]; then
  for skill_dir in "$SCRIPT_DIR/skills"/*/; do
    [[ -d "$skill_dir" ]] || continue
    skill_name="$(basename "$skill_dir")"
    dest="$HOME/.claude/skills/$skill_name"
    mkdir -p "$dest"

    para_SKILL "$dest"
    existing="$(arquivo_skill "$dest")" || existing=""
    if [[ -n "$existing" ]] && { [[ -s "$existing" ]] || nome_sobrando "$dest" >/dev/null; }; then
      mkdir -p "$dest/.example"
      para_SKILL "$dest/.example"
      cp -r "${skill_dir}." "$dest/.example/"
      warn "Skill '$skill_name' already exists — reference saved to .example/"
    else
      cp -r "${skill_dir}." "$dest/"
      ok "Skill: $skill_name"
    fi
    SKILLS_INSTALLED=$(( SKILLS_INSTALLED + 1 ))
  done
fi

[[ $SKILLS_INSTALLED -eq 0 ]] && warn "No skills found in package"

# ── settings.json ─────────────────────────────────────────────────────────────
section "Settings"

echo "settings" > "$CHECKPOINT_FILE"

SETTINGS_FILE="$HOME/.claude/settings.json"
SETTINGS_SRC="$SCRIPT_DIR/config/settings.json"

if [[ -f "$SETTINGS_FILE" ]]; then
  if is_valid_json "$SETTINGS_FILE"; then
    ok "settings.json already exists and is valid — kept"
  else
    warn "settings.json corrupted — saving a copy and recreating..."
    cp -p "$SETTINGS_FILE" "$SETTINGS_FILE.corrompido-$(date +%Y%m%d-%H%M%S)"
    warn "Copy kept: ~/.claude/$(basename "$SETTINGS_FILE").corrompido-*"
    if [[ -f "$SETTINGS_SRC" ]] && is_valid_json "$SETTINGS_SRC"; then
      write_atomic "$SETTINGS_FILE" < "$SETTINGS_SRC"
    else
      write_atomic "$SETTINGS_FILE" << 'SETTINGS'
{
  "theme": "dark"
}
SETTINGS
    fi
    ok "settings.json recreated"
  fi
else
  if [[ -f "$SETTINGS_SRC" ]] && is_valid_json "$SETTINGS_SRC"; then
    write_atomic "$SETTINGS_FILE" < "$SETTINGS_SRC"
  else
    write_atomic "$SETTINGS_FILE" << 'SETTINGS'
{
  "theme": "dark"
}
SETTINGS
  fi
  ok "settings.json created"
fi

# ── Notificação ───────────────────────────────────────────────────────────────
# Receita oficial (hook Notification), com matcher restrito a pedido de
# permissão e espera: avisa só quando o Claude Code precisa de você.
section "Notification"

echo "notification" > "$CHECKPOINT_FILE"

if [[ -f "$HOME/.claude/hooks/notify-done.sh" ]]; then
  warn "~/.claude/hooks/notify-done.sh is obsolete (it never ran) — kept, you can delete it."
fi

NOTIF_STATUS="not installed"
NOTIF_CMD=""
if [[ "$OS" == "Darwin" ]]; then
  NOTIF_CMD="osascript -e 'display notification \"Claude Code precisa de você\" with title \"Claude Code\"'"
elif command -v notify-send &>/dev/null; then
  NOTIF_CMD="notify-send 'Claude Code' 'Claude Code precisa de você'"
else
  warn "notify-send not found — notification skipped (Debian/Ubuntu: sudo apt install libnotify-bin, then run again)."
fi

if [[ -n "$NOTIF_CMD" ]]; then
  if ! command -v python3 &>/dev/null; then
    warn "python3 not found — settings.json was not changed. To get notified, add this to ~/.claude/settings.json:"
    printf '  "hooks": { "Notification": [ { "matcher": "permission_prompt|idle_prompt", "hooks": [ { "type": "command", "command": %s } ] } ] }\n' \
      "\"$(printf '%s' "$NOTIF_CMD" | sed 's/\\/\\\\/g; s/"/\\"/g')\""
  else
    _notif_stamp="$(date +%Y%m%d-%H%M%S)"
    _notif_out="$(python3 - "$SETTINGS_FILE" "$NOTIF_CMD" "$_notif_stamp" <<'PY'
import json, os, shutil, sys, tempfile
caminho, cmd, stamp = sys.argv[1:4]
path = os.path.realpath(caminho)  # settings.json que é atalho continua atalho
with open(path, encoding="utf-8") as f:
    data = json.load(f)
if not isinstance(data, dict):
    print("formato"); sys.exit(0)
hooks = data.get("hooks", {})
if not isinstance(hooks, dict) or not isinstance(hooks.get("Notification", []), list):
    print("formato"); sys.exit(0)
# Qualquer hook Notification que já exista: não acrescenta outro
existentes = [h for g in hooks.get("Notification", []) if isinstance(g, dict)
              for h in (g.get("hooks") or []) if isinstance(h, dict)]
if any(h.get("command") == cmd for h in existentes):
    print("igual"); sys.exit(0)
if existentes:
    print("outra"); sys.exit(0)
# A cópia fica sempre em ~/.claude (onde o backup sem senhas a reconhece), mesmo
# quando o settings.json é atalho para outro lugar
shutil.copy2(path, f"{caminho}.antes-setup-{stamp}")
data.setdefault("hooks", {}).setdefault("Notification", []).append(
    {"matcher": "permission_prompt|idle_prompt", "hooks": [{"type": "command", "command": cmd}]})
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".settings.", suffix=".tmp")
with os.fdopen(fd, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
with open(tmp, encoding="utf-8") as f:
    json.load(f)
os.chmod(tmp, os.stat(path).st_mode & 0o777)
os.replace(tmp, path)
print("ok")
PY
)" || _notif_out="erro"
    case "$_notif_out" in
      ok)      NOTIF_STATUS="installed"; ok "Notification hook added to settings.json (copy of the previous file: ~/.claude/settings.json.antes-setup-$_notif_stamp)" ;;
      igual)   NOTIF_STATUS="installed"; ok "Notification hook already registered — kept" ;;
      outra)   NOTIF_STATUS="yours";     ok "You already have a notification hook — kept, nothing added" ;;
      formato) warn "settings.json has an unexpected \"hooks\" format — not changed. Notification skipped." ;;
      *)       warn "Could not update settings.json — not changed. Notification skipped." ;;
    esac
  fi
fi

# ── Finalização ───────────────────────────────────────────────────────────────
rm -f "$CHECKPOINT_FILE"

section "Done"

BACKUP_MSG=""
NOTIF_TIP=""
if [[ "$OS" == "Darwin" && "$NOTIF_STATUS" == "installed" ]]; then
  NOTIF_TIP="
${BOLD}No notification on Mac?${RESET} Run ${BLUE}osascript -e 'display notification \"teste\"'${RESET} once,
  then System Settings > Notifications > Script Editor > Allow Notifications.
"
fi
$BACKUP_OK && BACKUP_MSG="\n  • Backup: $(basename "$BACKUP_FILE")"

echo -e "
${GREEN}${BOLD}✓ Claude Code Setup installed successfully!${RESET}

${BOLD}What was installed:${RESET}
  • Full ~/.claude/ and ~/claude/ structure
  • CLAUDE.md — persistent instructions for Claude
  • $SKILLS_INSTALLED skill(s) installed
  • Notification when Claude needs you: $NOTIF_STATUS
  • settings.json
${BACKUP_MSG}
${NOTIF_TIP}
${PATH_TIP}
${BOLD}Next steps:${RESET}
  1. Open Claude Code:    ${BLUE}claude${RESET}
  2. Test:                ${BLUE}/daily${RESET}  ${BLUE}/revisar-codigo${RESET}  ${BLUE}/standup${RESET}
  3. If something breaks: ${BLUE}bash repair.sh${RESET}

${BOLD}by Tadeu Rosa — CC BY-NC-ND 4.0${RESET}
  github.com/tadeurosa-ai/claude-code-setup
"
