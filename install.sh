#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Claude Code Setup — by Tadeu Rosa
# Versão: 1.0.0-lite
# Licença: CC BY-NC-ND 4.0 — uso pessoal permitido, redistribuição proibida
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

REPO_URL="https://github.com/tadeurosa-ai/claude-code-setup"
REPO_RAW="https://raw.githubusercontent.com/tadeurosa-ai/claude-code-setup/main"

# ── Bootstrap: detecta execução via curl | bash ───────────────────────────────
# Quando piped, BASH_SOURCE[0] é vazio ou /dev/stdin — sem acesso aos arquivos
# do repo. Resolve clonando para um tmpdir e re-executando de lá.
_SELF="${BASH_SOURCE[0]:-}"
if [[ -z "$_SELF" || "$_SELF" == "/dev/stdin" || "$_SELF" == "bash" ]]; then
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT

  echo "▸ Baixando repositório..."
  if command -v git &>/dev/null; then
    git clone --depth=1 --quiet "$REPO_URL" "$TMP/repo"
  elif command -v curl &>/dev/null; then
    curl -fsSL "$REPO_URL/archive/refs/heads/main.tar.gz" \
      | tar -xz -C "$TMP"
    mv "$TMP/claude-code-setup-main" "$TMP/repo"
  else
    echo "✗ Precisa de git ou curl instalado para continuar." >&2
    exit 1
  fi

  exec bash "$TMP/repo/install.sh"
fi

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
error()   { echo -e "${RED}✗${RESET} $*" >&2; exit 1; }
section() { echo -e "\n${BOLD}── $* ──────────────────────────────────────────${RESET}"; }

progress() {
  local label="$1" step="$2" total="$3"
  local filled=$(( step * 30 / total ))
  local bar="" i
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

OS="$(uname -s)"
[[ "$OS" == "Darwin" || "$OS" == "Linux" ]] || error "Sistema não suportado: $OS"
ok "Sistema: $OS"

if ! command -v claude &>/dev/null; then
  warn "Claude Code não encontrado."
  echo -e "  → Instale em: ${BLUE}https://claude.ai/code${RESET}"
  echo -e "  → Após instalar, rode este script novamente."
  exit 1
fi
CLAUDE_VERSION="$(claude --version 2>/dev/null | head -1 || echo 'versão desconhecida')"
ok "Claude Code: $CLAUDE_VERSION"

# ── Backup do setup anterior ──────────────────────────────────────────────────
section "Backup"

BACKUP_FILE="$HOME/.claude-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
BACKUP_OK=false

if [[ -d "$HOME/.claude" ]]; then
  info "Setup anterior encontrado. Fazendo backup..."
  if tar -czf "$BACKUP_FILE" -C "$HOME" .claude 2>/dev/null; then
    BACKUP_OK=true
    ok "Backup salvo em: $BACKUP_FILE"
  else
    warn "Backup falhou — continuando sem backup. Verifique permissões em $HOME"
  fi
else
  info "Nenhum setup anterior — instalação limpa."
fi

# ── Criando estrutura de diretórios ───────────────────────────────────────────
section "Criando estrutura"

DIRS=(
  "$HOME/.claude"
  "$HOME/.claude/skills"
  "$HOME/.claude/hooks"
  "$HOME/.claude/projects"
  "$HOME/claude"
  "$HOME/claude/projetos"
  "$HOME/claude/chats"
)

TOTAL_STEPS="${#DIRS[@]}"
STEP=0

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
    cp "$SCRIPT_DIR/config/CLAUDE.md" "$HOME/.claude/CLAUDE.md.example"
    warn "CLAUDE.md já existe — template salvo em ~/.claude/CLAUDE.md.example"
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
  shopt -s nullglob
  skill_dirs=("$SCRIPT_DIR/skills"/*/  )
  shopt -u nullglob

  for skill_dir in "${skill_dirs[@]}"; do
    [[ -d "$skill_dir" ]] || continue
    skill_name="$(basename "$skill_dir")"
    dest="$HOME/.claude/skills/$skill_name"
    mkdir -p "$dest"
    if [[ -f "$dest/skill.md" ]]; then
      cp -r "${skill_dir}." "$dest/.example/"
      warn "Skill '$skill_name' já existe — arquivos de referência em $dest/.example/"
    else
      cp -r "${skill_dir}." "$dest/"
      ok "Skill: $skill_name"
    fi
    SKILLS_INSTALLED=$(( SKILLS_INSTALLED + 1 ))
  done
fi

[[ $SKILLS_INSTALLED -eq 0 ]] && warn "Nenhuma skill encontrada"

# ── Instalando settings.json base ─────────────────────────────────────────────
section "Configurações"

SETTINGS_FILE="$HOME/.claude/settings.json"

if [[ ! -f "$SETTINGS_FILE" ]]; then
  cat > "$SETTINGS_FILE" << 'SETTINGS'
{
  "theme": "dark"
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
  • settings.json

${BOLD}Próximos passos:${RESET}
  1. Abra o Claude Code: ${BLUE}claude${RESET}
  2. Teste com: ${BLUE}/help${RESET}

${YELLOW}${BOLD}Quer o setup completo?${RESET}
  → Skills avançadas, hooks, memória, RTK e suporte
  → ${BLUE}https://tadeurosa.gumroad.com/l/claude-code-setup-pro${RESET}

${BOLD}by Tadeu Rosa — CC BY-NC-ND 4.0${RESET}
"
