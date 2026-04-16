#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Claude Code Setup — by Tadeu Rosa
# Versão: 1.0.0-lite
# Licença: CC BY-NC-ND 4.0 — uso pessoal permitido, redistribuição proibida
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Cores ─────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Helpers ───────────────────────────────────────────────────────────────────
info()    { echo -e "${BLUE}▸${RESET} $*"; }
ok()      { echo -e "${GREEN}✓${RESET} $*"; }
warn()    { echo -e "${YELLOW}⚠${RESET} $*"; }
error()   { echo -e "${RED}✗${RESET} $*"; exit 1; }
section() { echo -e "\n${BOLD}── $* ──────────────────────────────────────────${RESET}"; }
progress() {
  local label="$1" step="$2" total="$3"
  local filled=$(( step * 30 / total ))
  local bar=""
  for ((i=0; i<30; i++)); do
    [[ $i -lt $filled ]] && bar+="█" || bar+="░"
  done
  printf "\r${BLUE}[%s]${RESET} %s (%d/%d)" "$bar" "$label" "$step" "$total"
}

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
         CODE SETUP LITE — by Tadeu Rosa
BANNER
echo -e "${RESET}"
echo -e "  Instalando seu ambiente profissional de Claude Code...\n"

# ── Verificações de pré-requisito ─────────────────────────────────────────────
section "Verificando sistema"

# macOS ou Linux
OS="$(uname -s)"
[[ "$OS" == "Darwin" || "$OS" == "Linux" ]] || error "Sistema não suportado: $OS"
ok "Sistema: $OS"

# Claude Code instalado
if ! command -v claude &>/dev/null; then
  warn "Claude Code não encontrado."
  echo -e "  → Instale em: ${BLUE}https://claude.ai/code${RESET}"
  echo -e "  → Após instalar, rode este script novamente."
  exit 1
fi
CLAUDE_VERSION="$(claude --version 2>/dev/null | head -1)"
ok "Claude Code: $CLAUDE_VERSION"

# Git
command -v git &>/dev/null || error "Git não encontrado. Instale com: brew install git"
ok "Git: $(git --version)"

# ── Backup do setup anterior ──────────────────────────────────────────────────
section "Backup"

BACKUP_DIR="$HOME/.claude-backup-$(date +%Y%m%d-%H%M%S)"

if [[ -d "$HOME/.claude" ]]; then
  info "Setup anterior encontrado. Fazendo backup..."
  cp -rL "$HOME/.claude" "$BACKUP_DIR" 2>/dev/null || rsync -a --ignore-errors "$HOME/.claude/" "$BACKUP_DIR/" 2>/dev/null || true
  ok "Backup salvo em: $BACKUP_DIR"
else
  info "Nenhum setup anterior — instalação limpa."
fi

# ── Criando estrutura de diretórios ───────────────────────────────────────────
section "Criando estrutura"

TOTAL_STEPS=7
STEP=0

DIRS=(
  "$HOME/.claude"
  "$HOME/.claude/skills"
  "$HOME/.claude/hooks"
  "$HOME/.claude/projects"
  "$HOME/claude"
  "$HOME/claude/projetos"
  "$HOME/claude/chats"
)

for dir in "${DIRS[@]}"; do
  progress "Criando pastas" "$((++STEP))" "$TOTAL_STEPS"
  mkdir -p "$dir"
done
echo ""
ok "Estrutura criada"

# ── Instalando CLAUDE.md base ─────────────────────────────────────────────────
section "Configurando Claude"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "$SCRIPT_DIR/config/CLAUDE.md" ]]; then
  if [[ -f "$HOME/.claude/CLAUDE.md" ]]; then
    warn "CLAUDE.md já existe — salvo como CLAUDE.md.example (não sobrescrito)"
    cp "$SCRIPT_DIR/config/CLAUDE.md" "$HOME/.claude/CLAUDE.md.example"
  else
    cp "$SCRIPT_DIR/config/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
    ok "CLAUDE.md instalado"
  fi
else
  warn "config/CLAUDE.md não encontrado — pulando"
fi

# ── Instalando skills ─────────────────────────────────────────────────────────
section "Instalando skills"

SKILLS_INSTALLED=0
if [[ -d "$SCRIPT_DIR/skills" ]]; then
  for skill_dir in "$SCRIPT_DIR/skills"/*/; do
    skill_name="$(basename "$skill_dir")"
    dest="$HOME/.claude/skills/$skill_name"
    mkdir -p "$dest"
    cp -r "$skill_dir"* "$dest/" 2>/dev/null || true
    ok "Skill: $skill_name"
    ((SKILLS_INSTALLED++))
  done
fi

[[ $SKILLS_INSTALLED -eq 0 ]] && warn "Nenhuma skill encontrada"

# ── Instalando settings.json base ─────────────────────────────────────────────
section "Configurações"

SETTINGS_FILE="$HOME/.claude/settings.json"

if [[ ! -f "$SETTINGS_FILE" ]]; then
  cat > "$SETTINGS_FILE" << 'SETTINGS'
{
  "theme": "dark",
  "notifications": true,
  "autoSave": true
}
SETTINGS
  ok "settings.json criado"
else
  ok "settings.json já existe — mantido"
fi

# ── Finalização ───────────────────────────────────────────────────────────────
section "Concluído"

echo -e "
${GREEN}${BOLD}✓ Setup lite instalado com sucesso!${RESET}

${BOLD}O que foi instalado:${RESET}
  • Estrutura ~/.claude/ e ~/claude/
  • CLAUDE.md base configurado
  • $SKILLS_INSTALLED skill(s) instalada(s)
  • settings.json padrão

${BOLD}Próximos passos:${RESET}
  1. Abra o Claude Code: ${BLUE}claude${RESET}
  2. Teste com: ${BLUE}/help${RESET}

${YELLOW}${BOLD}Quer o setup completo?${RESET}
  → Skills avançadas, hooks, memória, RTK e suporte
  → ${BLUE}https://tadeurosa.gumroad.com/l/claude-code-setup-pro${RESET}

${BOLD}by Tadeu Rosa — CC BY-NC-ND 4.0${RESET}
"
