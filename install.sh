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
clear
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

# ── Detecta OS ────────────────────────────────────────────────────────────────
section "System check"

OS="$(uname -s)"
[[ "$OS" == "Darwin" || "$OS" == "Linux" ]] || \
  { echo -e "${YELLOW}⚠ Windows detected — use Git Bash to run this script.${RESET}"; exit 1; }
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

if ! command -v claude &>/dev/null; then
  warn "Claude Code CLI not found — installing automatically..."
  echo ""

  _claude_ok=false

  if command -v npm &>/dev/null; then
    info "Installing via npm..."
    npm install -g @anthropic-ai/claude-code 2>/dev/null && _claude_ok=true
  elif command -v brew &>/dev/null; then
    info "Installing Node.js via Homebrew (may take 1-2 min)..."
    brew install node --quiet 2>/dev/null || true
    command -v npm &>/dev/null && \
      npm install -g @anthropic-ai/claude-code 2>/dev/null && _claude_ok=true
  else
    info "Installing nvm + Node.js (no sudo, ~2-3 min)..."
    export NVM_DIR="$HOME/.nvm"
    if curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh 2>/dev/null | bash 2>/dev/null; then
      [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
      if command -v nvm &>/dev/null 2>&1 || type nvm &>/dev/null 2>&1; then
        nvm install --lts 2>/dev/null && \
          npm install -g @anthropic-ai/claude-code 2>/dev/null && _claude_ok=true
      fi
    fi
  fi

  if ! $_claude_ok; then
    echo ""
    echo -e "${RED}✗ Could not install automatically.${RESET}" >&2
    echo ""
    echo -e "  Install manually and run this script again:"
    echo -e "  1. Go to ${BLUE}https://nodejs.org${RESET} and install Node.js"
    echo -e "  2. Run: ${BLUE}npm install -g @anthropic-ai/claude-code${RESET}"
    echo -e "  3. Run this script again"
    exit 1
  fi

  _NPM_BIN="$(npm prefix -g 2>/dev/null)/bin"
  [[ -d "$_NPM_BIN" ]] && export PATH="$_NPM_BIN:$PATH"
  [[ -s "$HOME/.nvm/nvm.sh" ]] && . "$HOME/.nvm/nvm.sh"

  if ! command -v claude &>/dev/null; then
    warn "Claude Code installed. Open a new terminal and run this script again."
    exit 0
  fi
fi
ok "Claude Code: $(claude --version 2>/dev/null | head -1 || echo 'ok')"

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
  "$HOME/.claude/memory"
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

if [[ -d "$SCRIPT_DIR/skills" ]]; then
  for skill_dir in "$SCRIPT_DIR/skills"/*/; do
    [[ -d "$skill_dir" ]] || continue
    skill_name="$(basename "$skill_dir")"
    dest="$HOME/.claude/skills/$skill_name"
    mkdir -p "$dest"

    existing="$dest/skill.md"
    if [[ -f "$existing" ]] && [[ -s "$existing" ]]; then
      mkdir -p "$dest/.example"
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

# ── Sistema de memória ────────────────────────────────────────────────────────
section "Memory system"

echo "memory" > "$CHECKPOINT_FILE"

MEMORY_DIR="$HOME/.claude/memory"

if [[ ! -f "$MEMORY_DIR/MEMORY.md" ]]; then
  write_atomic "$MEMORY_DIR/MEMORY.md" << 'MEMINDEX'
# MEMORY INDEX

<!-- Each line is a pointer to a memory file -->
<!-- Format: - [Title](file.md) — short description -->
MEMINDEX
  ok "Memory system initialized"
else
  ok "Memory system already exists — kept"
fi

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
  • Persistent memory system
  • settings.json
${BACKUP_MSG}
${NOTIF_TIP}
${BOLD}Next steps:${RESET}
  1. Open Claude Code:    ${BLUE}claude${RESET}
  2. Test:                ${BLUE}/daily${RESET}  ${BLUE}/review${RESET}  ${BLUE}/standup${RESET}
  3. If something breaks: ${BLUE}bash repair.sh${RESET}

${BOLD}by Tadeu Rosa — CC BY-NC-ND 4.0${RESET}
  github.com/tadeurosa-ai/claude-code-setup
"
