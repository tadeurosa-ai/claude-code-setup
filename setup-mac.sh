#!/usr/bin/env bash
# Setup completo do ambiente Claude Code em Mac novo
# Execução: bash <(curl -fsSL https://raw.githubusercontent.com/tadeurosa-ai/claude-config/main/bin/setup-mac.sh)

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${BLUE}▸${RESET} $*"; }
ok()      { echo -e "${GREEN}✓${RESET} $*"; }
warn()    { echo -e "${YELLOW}⚠${RESET} $*"; }
error()   { echo -e "${RED}✗${RESET} $*" >&2; exit 1; }
section() { echo -e "\n${BOLD}── $* ──────────────────────────────────────────${RESET}"; }

clear
echo -e "${BOLD}"
cat << 'BANNER'
  ██████╗██╗      █████╗ ██╗   ██╗██████╗ ███████╗
 ██╔════╝██║     ██╔══██╗██║   ██║██╔══██╗██╔════╝
 ██║     ██║     ███████║██║   ██║██║  ██║█████╗
 ██║     ██║     ██╔══██║██║   ██║██║  ██║██╔══╝
 ╚██████╗███████╗██║  ██║╚██████╔╝██████╔╝███████╗
  ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝
         MAC SETUP — by Tadeu Rosa
BANNER
echo -e "${RESET}"

# ── 1. Homebrew ───────────────────────────────────────────────────────────────
section "Homebrew"
if ! command -v brew &>/dev/null; then
  info "Instalando Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  ok "Homebrew já instalado"
fi

# ── 2. Ferramentas ────────────────────────────────────────────────────────────
section "Ferramentas"
info "Instalando pacotes..."
brew install gh shellcheck yt-dlp poppler ffmpeg uv rtk node
brew install --cask gcloud-cli
ok "Ferramentas instaladas"

# ── 3. GitHub auth ────────────────────────────────────────────────────────────
section "GitHub"
if ! gh auth status &>/dev/null; then
  info "Autenticando no GitHub (abrirá o browser)..."
  gh auth login
else
  ok "GitHub já autenticado"
fi

# ── 4. Repos — ordem obrigatória ──────────────────────────────────────────────
section "Clonando repos"

if [[ -d "$HOME/claude" ]]; then
  warn "~/claude já existe — pulando clone do workspace"
else
  info "Clonando workspace..."
  git clone --recurse-submodules https://github.com/tadeurosa-ai/claude-workspace.git ~/claude
  ok "claude-workspace clonado"
fi

if [[ -d "$HOME/claude/skills" ]]; then
  warn "~/claude/skills já existe — pulando clone das skills"
else
  info "Clonando skills..."
  git clone https://github.com/tadeurosa-ai/claude-skills.git ~/claude/skills
  ok "claude-skills clonado"
fi

if [[ -d "$HOME/.claude" ]]; then
  warn "~/.claude já existe — pulando clone do config"
else
  info "Clonando config..."
  git clone https://github.com/tadeurosa-ai/claude-config.git ~/.claude
  ok "claude-config clonado"
fi

# ── 5. LaunchAgent ────────────────────────────────────────────────────────────
section "Atualização automática semanal"

PLIST_SRC="$HOME/.claude/bin/brew-upgrade-tools.plist"
PLIST_DST="$HOME/Library/LaunchAgents/com.tadeurosa.brew-upgrade-tools.plist"

if [[ ! -f "$PLIST_SRC" ]]; then
  info "Gerando plist..."
  cat > "$PLIST_SRC" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.tadeurosa.brew-upgrade-tools</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>/Users/$(whoami)/.claude/bin/brew-upgrade-tools.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Weekday</key>
        <integer>1</integer>
        <key>Hour</key>
        <integer>9</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>/Users/$(whoami)/.claude/logs/brew-upgrade.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/$(whoami)/.claude/logs/brew-upgrade.log</string>
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
PLIST
fi

mkdir -p ~/Library/LaunchAgents
cp "$PLIST_SRC" "$PLIST_DST"
launchctl load "$PLIST_DST" 2>/dev/null || true
ok "LaunchAgent ativado"

# ── Instalar Claude Code ──────────────────────────────────────────────────────
section "Claude Code"
if ! command -v claude &>/dev/null; then
  info "Instalando Claude Code..."
  npm install -g @anthropic-ai/claude-code
  ok "Claude Code instalado"
else
  ok "Claude Code já instalado"
fi

# ── Resumo ────────────────────────────────────────────────────────────────────
section "Concluído"
echo -e "
${GREEN}${BOLD}✓ Setup completo!${RESET}

${BOLD}Passos manuais restantes:${RESET}
  1. Copiar ${YELLOW}~/.env${RESET} via AirDrop/USB (API keys)
  2. Copiar ${YELLOW}~/.claude/channels/telegram/.env${RESET} via AirDrop/USB (token do bot)
  3. Re-autenticar Slack MCP: abra o Claude Code e siga o prompt OAuth
  4. ${BLUE}gcloud auth login${RESET} (Google Cloud)

${BOLD}Verificar:${RESET}
  claude --version && rtk --version && gh auth status
"
