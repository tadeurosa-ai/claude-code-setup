#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Claude Code Setup — by Tadeu Rosa
# Versão: 1.1.0-lite
# Licença: CC BY-NC-ND 4.0 — uso pessoal permitido, redistribuição proibida
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

REPO_URL="https://github.com/tadeurosa-ai/claude-code-setup"
CHECKPOINT_FILE=""   # definido após HOME estar disponível

# ── Bootstrap: detecta execução via curl | bash ───────────────────────────────
_SELF="${BASH_SOURCE[0]:-}"
if [[ -z "$_SELF" || "$_SELF" == "/dev/stdin" || "$_SELF" == "bash" ]]; then
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  echo "▸ Baixando repositório..."
  if command -v git &>/dev/null; then
    git clone --depth=1 --quiet "$REPO_URL" "$TMP/repo"
  elif command -v curl &>/dev/null; then
    curl -fsSL "$REPO_URL/archive/refs/heads/main.tar.gz" | tar -xz -C "$TMP"
    mv "$TMP/claude-code-setup-main" "$TMP/repo"
  else
    echo "✗ Precisa de git ou curl instalado para continuar." >&2; exit 1
  fi
  exec bash "$TMP/repo/install.sh"
fi

# ── Cores ─────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${BLUE}▸${RESET} $*"; }
ok()      { echo -e "${GREEN}✓${RESET} $*"; }
warn()    { echo -e "${YELLOW}⚠${RESET} $*"; }
error()   { echo -e "${RED}✗${RESET} $*" >&2; exit 1; }
section() { echo -e "\n${BOLD}── $* ──────────────────────────────────────────${RESET}"; }

progress() {
  local label="$1" step="$2" total="$3"
  local filled=$(( step * 30 / total )) bar="" i
  for ((i=0; i<30; i++)); do [[ $i -lt $filled ]] && bar+="█" || bar+="░"; done
  printf "\r${BLUE}[%s]${RESET} %s (%d/%d)" "$bar" "$label" "$step" "$total"
}

# Escrita atômica: mktemp + mv (rename syscall — garantido pelo kernel)
# Nunca deixa arquivo parcial no destino, mesmo com queda de luz.
write_atomic() {
  local target="$1"
  local tmp
  tmp="$(mktemp "${target}.XXXXXX")"
  cat > "$tmp"
  mv "$tmp" "$target"
}

# Valida JSON sem dependência de jq
is_valid_json() {
  python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$1" 2>/dev/null
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

CHECKPOINT_FILE="$HOME/.claude-install-checkpoint"

# Escreve checkpoint imediatamente — qualquer interrupção a partir daqui é detectável
echo "started" > "$CHECKPOINT_FILE"

# ── Detecta instalação anterior interrompida ──────────────────────────────────
if [[ -f "$CHECKPOINT_FILE" ]] && [[ "$(cat "$CHECKPOINT_FILE")" != "started" ]]; then
  LAST_STAGE="$(cat "$CHECKPOINT_FILE" 2>/dev/null || echo 'desconhecido')"
  warn "Instalação anterior interrompida detectada (última etapa: ${BOLD}$LAST_STAGE${RESET}${YELLOW})"
  warn "Execute ${BOLD}bash repair.sh${RESET}${YELLOW} para diagnóstico completo."
  echo ""
  info "Continuando instalação do ponto de falha..."
fi

# ── Limpa backups corrompidos de runs anteriores ──────────────────────────────
section "Backup"

for old_backup in "$HOME"/.claude-backup-*.tar.gz; do
  [[ -f "$old_backup" ]] || continue
  if ! tar -tzf "$old_backup" &>/dev/null; then
    warn "Backup corrompido encontrado (provavelmente queda de luz): $(basename "$old_backup")"
    rm -f "$old_backup"
    warn "Removido. Um novo backup válido será criado agora."
  fi
done

BACKUP_FILE="$HOME/.claude-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
BACKUP_OK=false

echo "backup_start" > "$CHECKPOINT_FILE"

if [[ -d "$HOME/.claude" ]]; then
  info "Setup anterior encontrado. Fazendo backup..."
  if tar -czf "$BACKUP_FILE" -C "$HOME" .claude 2>/dev/null; then
    # Verifica integridade imediatamente — queda de luz durante tar deixa gz corrompido
    if tar -tzf "$BACKUP_FILE" &>/dev/null; then
      BACKUP_OK=true
      ok "Backup verificado: $BACKUP_FILE"
    else
      warn "Backup escrito mas corrompido (verifique espaço em disco)"
      rm -f "$BACKUP_FILE"
    fi
  else
    warn "Backup falhou — continuando sem backup. Verifique espaço e permissões em $HOME"
  fi
else
  info "Nenhum setup anterior — instalação limpa."
fi

# ── Criando estrutura de diretórios ───────────────────────────────────────────
section "Criando estrutura"

echo "dirs" > "$CHECKPOINT_FILE"

DIRS=(
  "$HOME/.claude"
  "$HOME/.claude/skills"
  "$HOME/.claude/hooks"
  "$HOME/.claude/projects"
  "$HOME/claude"
  "$HOME/claude/projetos"
  "$HOME/claude/chats"
)

TOTAL_STEPS="${#DIRS[@]}"; STEP=0
for dir in "${DIRS[@]}"; do
  progress "Criando pastas" "$((++STEP))" "$TOTAL_STEPS"
  mkdir -p "$dir"
done
echo ""; ok "Estrutura criada"

# ── Instalando CLAUDE.md base ─────────────────────────────────────────────────
section "Configurando Claude"

echo "claude_md" > "$CHECKPOINT_FILE"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "$SCRIPT_DIR/config/CLAUDE.md" ]]; then
  if [[ -f "$HOME/.claude/CLAUDE.md" ]]; then
    # Atômico: nunca deixa .example parcial
    write_atomic "$HOME/.claude/CLAUDE.md.example" < "$SCRIPT_DIR/config/CLAUDE.md"
    warn "CLAUDE.md já existe — template salvo atomicamente em ~/.claude/CLAUDE.md.example"
  else
    write_atomic "$HOME/.claude/CLAUDE.md" < "$SCRIPT_DIR/config/CLAUDE.md"
    ok "CLAUDE.md instalado"
  fi
else
  warn "config/CLAUDE.md não encontrado — pulando"
fi

# ── Instalando skills ─────────────────────────────────────────────────────────
section "Instalando skills"

echo "skills" > "$CHECKPOINT_FILE"

SKILLS_INSTALLED=0

if [[ -d "$SCRIPT_DIR/skills" ]]; then
  shopt -s nullglob
  skill_dirs=("$SCRIPT_DIR/skills"/*/)
  shopt -u nullglob

  for skill_dir in "${skill_dirs[@]}"; do
    [[ -d "$skill_dir" ]] || continue
    skill_name="$(basename "$skill_dir")"
    dest="$HOME/.claude/skills/$skill_name"
    mkdir -p "$dest"

    existing_skill="$dest/skill.md"
    if [[ -f "$existing_skill" ]] && [[ -s "$existing_skill" ]]; then
      # skill existe E tem conteúdo — protege conteúdo customizado do usuário
      mkdir -p "$dest/.example"
      cp -r "${skill_dir}." "$dest/.example/"
      warn "Skill '$skill_name' já existe — referência salva em $dest/.example/"
    else
      # skill ausente OU está vazia/corrompida (ex: queda de luz anterior) — reinstala
      [[ -f "$existing_skill" ]] && [[ ! -s "$existing_skill" ]] && \
        warn "Skill '$skill_name' corrompida (arquivo vazio) — reinstalando..."
      cp -r "${skill_dir}." "$dest/"
      ok "Skill: $skill_name"
    fi
    SKILLS_INSTALLED=$(( SKILLS_INSTALLED + 1 ))
  done
fi

[[ $SKILLS_INSTALLED -eq 0 ]] && warn "Nenhuma skill encontrada"

# ── Instalando settings.json ──────────────────────────────────────────────────
section "Configurações"

echo "settings" > "$CHECKPOINT_FILE"

SETTINGS_FILE="$HOME/.claude/settings.json"

if [[ -f "$SETTINGS_FILE" ]]; then
  if is_valid_json "$SETTINGS_FILE"; then
    ok "settings.json já existe e é válido — mantido"
  else
    warn "settings.json corrompido (provavelmente queda de luz) — recriando..."
    write_atomic "$SETTINGS_FILE" << 'SETTINGS'
{
  "theme": "dark"
}
SETTINGS
    ok "settings.json recriado"
  fi
else
  write_atomic "$SETTINGS_FILE" << 'SETTINGS'
{
  "theme": "dark"
}
SETTINGS
  ok "settings.json criado"
fi

# ── Instalação concluída — remove checkpoint ───────────────────────────────────
rm -f "$CHECKPOINT_FILE"

# ── Finalização ───────────────────────────────────────────────────────────────
section "Concluído"

BACKUP_MSG=""
$BACKUP_OK && BACKUP_MSG="  • Backup verificado: $(basename "$BACKUP_FILE")\n"

echo -e "
${GREEN}${BOLD}✓ Setup lite instalado com sucesso!${RESET}

${BOLD}O que foi instalado:${RESET}
  • Estrutura ~/.claude/ e ~/claude/
  • CLAUDE.md base configurado
  • $SKILLS_INSTALLED skill(s) instalada(s)
  • settings.json
${BACKUP_MSG}
${BOLD}Próximos passos:${RESET}
  1. Abra o Claude Code: ${BLUE}claude${RESET}
  2. Teste com: ${BLUE}/help${RESET}
  3. Se algo parecer errado: ${BLUE}bash repair.sh${RESET}

${YELLOW}${BOLD}Quer o setup completo?${RESET}
  → Skills avançadas, hooks, memória, RTK e suporte
  → ${BLUE}https://tadeurosa.gumroad.com/l/claude-code-setup-pro${RESET}

${BOLD}by Tadeu Rosa — CC BY-NC-ND 4.0${RESET}
"
