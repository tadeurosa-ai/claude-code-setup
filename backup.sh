#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Claude Code Backup — by Tadeu Rosa
# Versão: 1.2.0
# Licença: CC BY-NC-ND 4.0 — uso pessoal permitido, redistribuição proibida
# ─────────────────────────────────────────────────────────────────────────────
# O QUE ESTE SCRIPT FAZ:
#   Faz backup APENAS dos arquivos do Claude Code (~/.claude/ e ~/claude/).
#   Documentos, fotos, vídeos e demais arquivos NÃO são incluídos.
#
#   Destino na NUVEM (iCloud, Google Drive, OneDrive, Dropbox):
#     • de ~/.claude/ só vão as configurações (lista fixa); ~/claude/ não vai;
#     • login, histórico e textos das conversas, .env, chaves e tokens ficam;
#     • o settings.json vai com o "env" vazio e tokens trocados por marcador.
#   Destino LOCAL (pendrive, disco externo, pasta local):
#     • vai tudo; pergunta se inclui login, senhas (.env) e chaves.
#   O snapshot leva a lista do que ficou de fora (só nomes), para o
#   restore.sh trazer de volta da pasta anterior nesta mesma máquina.
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
║  Na nuvem: só configurações. Projetos, login, histórico,     ║
║  .env e chaves NÃO vão.                                      ║
║                                                              ║
║  Para backup completo da máquina use:                        ║
║    • Mac:     Time Machine                                   ║
║    • Windows: Backup e Restauração (Painel de Controle)     ║
║    • Nuvem:   iCloud / Google Drive / OneDrive / Dropbox    ║
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
  warn "Destino na nuvem. Vão só as configurações do Claude Code."
  warn "Ficam na máquina: os projetos (~/claude), login, histórico e textos das conversas, senhas (.env) e chaves."
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
  echo -e "${BOLD}Login do Claude Code, senhas de projetos (.env), chaves e cópias de configuração.${RESET}"
  echo -e "  Inclua só se o destino for um pendrive ou disco que só você usa."
  echo -e "  Se responder não, ${BOLD}vão mesmo assim${RESET}: o histórico das conversas (pode ter o que você colou)"
  echo -e "  e outros arquivos com senha dentro dos projetos, como secrets.toml e token.json."
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

command -v python3 &>/dev/null || \
  error "Precisa do python3 para separar o que é senha do que é configuração.\n  Mac: xcode-select --install   ·   Linux: sudo apt install python3"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
SNAPSHOT_NAME="claude-code-snapshot-${TIMESTAMP}.tar.gz"
SNAPSHOT_PATH="$DEST_PATH/$SNAPSHOT_NAME"

# Pasta de trabalho: uma "raiz" montada item a item. Pastas viram atalhos para
# as pastas reais (o tar lê através deles); arquivos são copiados depois dos
# filtros; o settings.json entra já limpo. Nada nas suas pastas é alterado.
TMP_WORK="$(mktemp -d)"
trap 'rm -rf "$TMP_WORK"' EXIT
RAIZ="$TMP_WORK/raiz"
TAR_LOG="$TMP_WORK/tar.log"
mkdir -p "$RAIZ"

SEG_FORA=0; $DEST_IS_CLOUD && SEG_FORA=1; $INCLUDE_SECRETS || SEG_FORA=1
NUVEM=0; $DEST_IS_CLOUD && NUVEM=1
SEM_CHATS=0; $EXCLUDE_CHATS && SEM_CHATS=1

info "Separando o que entra..."
if ! python3 - "$HOME" "$RAIZ" "$TMP_WORK" "$NUVEM" "$SEG_FORA" "$SEM_CHATS" "$SNAPSHOT_PATH" <<'PY'
import fnmatch, json, os, re, shutil, stat, sys

HOME, RAIZ, WORK = sys.argv[1:4]
NUVEM, SEG_FORA, SEM_CHATS = (a == "1" for a in sys.argv[4:7])
MARCADOR = "<<removido-pelo-backup>>"
PEDACO = 1024 * 1024        # leitura do conteúdo em pedaços de 1 MiB…
SOBRA = 64 * 1024           # …que se sobrepõem 64 KiB (token cortado na emenda é achado)

lista = open(os.path.join(WORK, "lista"), "wb")
regras = open(os.path.join(WORK, "regras"), "wb")
fatal, fora_topo, fora_nomes, atalhos_info, atalhos_fora, refs_fora = [], [], [], [], [], []
atalhos_copia, modos, settings_msgs = [], [], []
sumidos = [0]
adicionados = set()          # caminhos relativos que entraram na lista
raizes_reais = []            # pastas reais que entraram (para saber se um atalho aponta para dentro)
arquivos_reais = set()       # arquivos reais que entraram
cand_atalhos = []            # atalhos internos, avaliados no fim

def add(rel):
    lista.write(os.fsencode(rel) + b"\0")
    adicionados.add(rel)

def regra(tipo, rel):
    regras.write(os.fsencode(tipo + "\t" + rel) + b"\0")

def guardar_modo(rel, p):
    try:
        modos.append(f"{rel}|{stat.S_IMODE(os.stat(p).st_mode):o}")
    except OSError:
        pass

# ── Tokens (D11): formato inteiro, nunca no meio de palavra ──
TOKEN_RES = [re.compile(p) for p in (
    r"(?<![A-Za-z0-9])sk-[A-Za-z0-9_-]{20,}",
    r"(?<![A-Za-z0-9])gh[po]_[A-Za-z0-9]{36}(?![A-Za-z0-9])",
    r"(?<![A-Za-z0-9])github_pat_[A-Za-z0-9_]{40,}",
    r"(?<![A-Za-z0-9])xox[abpr]-[A-Za-z0-9-]{20,}",
    r"(?<![A-Za-z0-9])AKIA[A-Z0-9]{16}(?![A-Z0-9])",
    r"(?<![A-Za-z0-9])AIza[A-Za-z0-9_-]{35}(?![A-Za-z0-9_-])",
    r"(?<![A-Za-z0-9])glpat-[A-Za-z0-9_-]{20,}",
)]
RE_CONTEXTO = re.compile(r"(?i)(?:bearer |token=|key=|--token |authorization: )([A-Za-z0-9_+/=%-]{20,})")
RE_LONGO = re.compile(r"(?<![A-Za-z0-9_-])[A-Za-z0-9_-]{32,}(?![A-Za-z0-9_-])")

def trechos_token(s):
    sp = []
    for r in TOKEN_RES:
        sp += [(m.start(), m.end()) for m in r.finditer(s)]
    for m in RE_CONTEXTO.finditer(s):
        v = m.group(1)
        if re.search(r"[0-9]", v) and re.search(r"[A-Z]", v) and re.search(r"[a-z]", v):
            sp.append((m.start(1), m.end(1)))
    sp.sort()
    juntos = []
    for a, b in sp:
        if juntos and a <= juntos[-1][1]:
            juntos[-1] = (juntos[-1][0], max(b, juntos[-1][1]))
        else:
            juntos.append((a, b))
    return juntos

# ── Chaves (D8) ──
CHAVE_EXT = (".pem", ".key", ".p12", ".pfx", ".jks", ".keystore")
CHAVE_PREF = ("id_rsa", "id_ed25519", "id_ecdsa", "id_dsa")
RE_PRIVADA = re.compile(rb"(?m)^-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----")
COPIAS_CONFIG = ("settings*.json.*", ".settings*.json*", ".mcp.json", "*.mcp.json*", "claude-json.backup*")

class NaoLeu(Exception):
    pass

def janelas(p):
    """Conteúdo do arquivo em pedaços sobrepostos, sem limite de tamanho.
    Binário (byte zero nos primeiros 8 KiB): nada. Erro de leitura no meio: NaoLeu (falha fechada)."""
    with open(p, "rb") as f:
        resto = b""
        primeiro = True
        while True:
            try:
                bloco = f.read(PEDACO)
            except OSError as e:
                raise NaoLeu(e.strerror)
            if primeiro:
                primeiro = False
                if b"\0" in bloco[:8192]:
                    return
            if not bloco:
                return
            yield resto + bloco
            resto = (resto + bloco)[-SOBRA:]

def segredo_no_conteudo(p):
    for j in janelas(p):
        if RE_PRIVADA.search(j):
            return "chave privada no conteúdo"
        if NUVEM and trechos_token(j.decode("utf-8", "replace")):
            return "token no conteúdo"
    return None

def inofensivo(p, nome_min):
    if nome_min.endswith(".key"):
        with open(p, "rb") as f:
            return f.read(4) == b"PK\x03\x04"          # Keynote (zip)
    if nome_min.endswith(".pem"):
        cert = False
        for j in janelas(p):
            if b"PRIVATE KEY" in j:
                return False
            cert = cert or b"-----BEGIN CERTIFICATE-----" in j
        return cert
    return False

def motivo_fora(p, nome, topo_claude):
    if nome.startswith("claude-code-snapshot-") and nome.endswith(".tar.gz"):
        return "pular"
    if SEG_FORA:
        if nome == ".credentials.json":
            return "login"
        if nome == ".env" or (nome.startswith(".env.") and nome != ".env.example"):
            return "senha (.env)"
        nm = nome.lower()
        if nm.endswith(CHAVE_EXT) or nome.startswith(CHAVE_PREF):
            if not inofensivo(p, nm):
                return "chave"
        if topo_claude and not NUVEM and any(fnmatch.fnmatchcase(nome, g) for g in COPIAS_CONFIG):
            return "cópia de configuração"
    if NUVEM and nome in ("token.json", "credentials.json", "secrets.toml"):
        return "arquivo de senha"
    if SEG_FORA:
        return segredo_no_conteudo(p)
    return None

REAL_HOME = os.path.realpath(HOME)

def dentro(t, base):
    return t == base or t.startswith(base + os.sep)

def atalho_interno(rel, p):
    add(rel)  # o tar grava o atalho como atalho
    cand_atalhos.append((rel, p))

def poda(rel, nome):
    if NUVEM and nome == ".git":
        return True
    if NUVEM and rel == ".claude/skills/.trash":
        return True
    if SEM_CHATS and rel == "claude/chats":
        return True
    return False

EXCLUIR_REAIS = set()

def arquivo(rel, p, nome, topo_claude=False, destino=None):
    """Filtra e acrescenta um arquivo. destino: copiar para a RAIZ (senão é lido pelo atalho)."""
    if EXCLUIR_REAIS and os.path.realpath(p) in EXCLUIR_REAIS:
        regra("arquivo", rel)
        fora_nomes.append(f"settings original (foi a cópia limpa em .claude/): {rel}")
        return
    try:
        st = os.lstat(p)
        if not stat.S_ISREG(st.st_mode):
            return
        m = motivo_fora(p, nome, topo_claude)
    except FileNotFoundError:
        sumidos[0] += 1
        return
    except NaoLeu as e:
        m = f"não deu para conferir o conteúdo inteiro ({e})"
    except PermissionError as e:
        fatal.append(f"{rel}: {e.strerror}")
        return
    except OSError as e:
        m = f"não deu para conferir o conteúdo inteiro ({e.strerror})"
    if m == "pular":
        regra("arquivo", rel)   # backup antigo guardado aqui: o restore traz de volta da .anterior
        return
    if m:
        regra("arquivo", rel)
        fora_nomes.append(f"{m}: {rel}")
        return
    if destino:
        os.makedirs(os.path.dirname(destino), exist_ok=True)
        shutil.copy2(p, destino)
    arquivos_reais.add(os.path.realpath(p))
    add(rel)

def percorrer(rel_raiz, real_raiz):
    """Tudo ABAIXO de real_raiz (a pasta em si não entra na lista)."""
    raizes_reais.append(os.path.realpath(real_raiz))
    def erro(e):
        if isinstance(e, FileNotFoundError):
            sumidos[0] += 1
        else:
            fatal.append(f"{e.filename}: {e.strerror}")
    for dirpath, dirnames, filenames in os.walk(real_raiz, onerror=erro):
        rel_dir = rel_raiz + dirpath[len(real_raiz):]
        manter = []
        for d in sorted(dirnames):
            p, r = os.path.join(dirpath, d), rel_dir + "/" + d
            if os.path.islink(p):
                atalho_interno(r, p)
            elif poda(r, d):
                regra("pasta", r)
                fora_nomes.append(("histórico do git" if d == ".git" else "pasta fora") + f": {r}")
            else:
                add(r)
                manter.append(d)
        dirnames[:] = manter
        for f in sorted(filenames):
            p, r = os.path.join(dirpath, f), rel_dir + "/" + f
            if os.path.islink(p):
                atalho_interno(r, p)
            else:
                arquivo(r, p, f)

def incluir_pasta(rel, p):
    try:
        vazia = not os.listdir(p)
    except OSError as e:
        fatal.append(f"{rel}: {e.strerror}")
        return
    guardar_modo(rel, p)
    if vazia:
        os.makedirs(os.path.join(RAIZ, rel), exist_ok=True)
        os.chmod(os.path.join(RAIZ, rel), stat.S_IMODE(os.stat(p).st_mode))
        raizes_reais.append(os.path.realpath(p))
        add(rel)
    else:
        os.symlink(p, os.path.join(RAIZ, rel))
        percorrer(rel, p)

# ── settings.json / settings.local.json sem segredos (D11) ──
def limpar_settings(rel, p):
    try:
        with open(p, encoding="utf-8") as f:
            d = json.load(f)
    except (OSError, ValueError):
        regra("arquivo", rel)
        fora_nomes.append(f"não é JSON válido, ficou fora: {rel}")
        return
    trocados, longos = [], []
    def so_avisar(o, cam):
        if isinstance(o, dict):
            for k, v in o.items():
                so_avisar(v, f"{cam}.{k}")
        elif isinstance(o, list):
            for i, v in enumerate(o):
                so_avisar(v, f"{cam}[{i}]")
        elif isinstance(o, str) and RE_LONGO.search(o):
            longos.append(cam)
    def limpar(o, cam):
        if isinstance(o, dict):
            for k in list(o):
                c = f"{cam}.{k}" if cam else k
                if not cam and k == "env" and isinstance(o[k], dict):
                    o[k] = {kk: "" for kk in o[k]}
                elif (not cam and k in ("permissions", "enabledPlugins")) or k == "matcher":
                    so_avisar(o[k], c)
                else:
                    o[k] = limpar(o[k], c)
            return o
        if isinstance(o, list):
            return [limpar(v, f"{cam}[{i}]") for i, v in enumerate(o)]
        if isinstance(o, str):
            sp = trechos_token(o)
            if sp:
                partes, ult = [], 0
                for a, b in sp:
                    partes += [o[ult:a], MARCADOR]
                    ult = b
                o = "".join(partes) + o[ult:]
                trocados.append(cam)
            if RE_LONGO.search(o.replace(MARCADOR, "")):
                longos.append(cam)
        return o
    if isinstance(d, dict):
        d = limpar(d, "")
    destino = os.path.join(RAIZ, rel)
    fd = os.open(destino, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(d, f, indent=2, ensure_ascii=False)
        f.write("\n")
    os.chmod(destino, stat.S_IMODE(os.stat(p).st_mode))   # mesma permissão do original
    arquivos_reais.add(os.path.realpath(p))
    add(rel)
    settings_msgs.append(f"{rel}: valores do bloco env apagados")
    for c in trocados:
        settings_msgs.append(f"{rel}: token trocado pelo marcador em {c}")
    for c in longos:
        settings_msgs.append(f"{rel}: sequência longa mantida (confira se não é senha) em {c}")

# ── Arquivos que o settings.json usa (só nuvem, D6 revista em 11/11) ──
# Só vai o que é script (pela extensão do arquivo de verdade) e não aparece
# depois de ">"/">>" (arquivo que o hook grava). O resto é listado na tela.
PASTAS_NUVEM = {"skills", "hooks", "commands", "agents", "rules", "output-styles",
                "workflows", "agent-memory", "memory", "themes"}
ARQUIVOS_NUVEM = {"CLAUDE.md", "keybindings.json", "settings.json"}
EXT_SCRIPT = (".sh", ".bash", ".zsh", ".fish", ".py", ".js", ".mjs", ".cjs", ".ts", ".rb", ".pl")

def citados():
    p = os.path.join(HOME, ".claude", "settings.json")
    try:
        with open(p, encoding="utf-8") as f:
            d = json.load(f)
    except (OSError, ValueError):
        return set(), []
    textos = []
    sl = d.get("statusLine") if isinstance(d, dict) else None
    if isinstance(sl, dict) and isinstance(sl.get("command"), str):
        textos.append(sl["command"])
    hooks = d.get("hooks") if isinstance(d, dict) else None
    if isinstance(hooks, dict):
        for grupos in hooks.values():
            for g in grupos if isinstance(grupos, list) else []:
                for h in (g.get("hooks") or []) if isinstance(g, dict) else []:
                    if isinstance(h, dict) and isinstance(h.get("command"), str):
                        textos.append(h["command"])
    rx = re.compile(r"(?:~|\$HOME|\$\{HOME\}|" + re.escape(HOME) + r")/\.claude/([^\s'\"`;|&<>()]+)")
    aceitos, recusados = set(), {}
    for t in textos:
        for m in rx.finditer(t):
            r = os.path.normpath(m.group(1))
            if r.startswith("..") or r.split("/")[0] in PASTAS_NUVEM or r in ARQUIVOS_NUVEM:
                continue   # vai (ou não) pelas regras da pasta
            real = os.path.realpath(os.path.join(HOME, ".claude", r))
            if not os.path.isfile(real):
                continue
            if t[:m.start()].rstrip().endswith(">"):
                recusados[r] = "o hook grava nele"
            elif not real.lower().endswith(EXT_SCRIPT):
                recusados.setdefault(r, "não é script")
            else:
                aceitos.add(r)
    for r in list(recusados):
        aceitos.discard(r)
    return aceitos, sorted(recusados.items())

# ── ~/.claude, item a item ──
base = os.path.join(HOME, ".claude")
refs, refs_recusados = set(), []
if os.path.isdir(base):
    os.makedirs(os.path.join(RAIZ, ".claude"))
    guardar_modo(".claude", base)
    if NUVEM:
        refs, refs_recusados = citados()
    # settings que é atalho: o original (onde estiver) nunca vai cru; vai a cópia limpa
    if SEG_FORA:
        for nm in ("settings.json", "settings.local.json"):
            p = os.path.join(base, nm)
            if os.path.islink(p) and os.path.isfile(os.path.realpath(p)):
                EXCLUIR_REAIS.add(os.path.realpath(p))
    for nome in sorted(os.listdir(base)):
        p, r = os.path.join(base, nome), ".claude/" + nome
        # Atalho no primeiro nível (ex.: skills -> ~/claude/skills)
        if os.path.islink(p):
            alvo = os.path.realpath(p)
            if not os.path.exists(alvo):
                os.symlink(os.readlink(p), os.path.join(RAIZ, r))
                add(r)
                atalhos_fora.append(r + " -> " + os.readlink(p))
                continue
            rel_alvo = os.path.relpath(alvo, REAL_HOME) if dentro(alvo, REAL_HOME) else None
            permitido = (not NUVEM) or nome in PASTAS_NUVEM or nome in ARQUIVOS_NUVEM or nome in refs
            eh_settings = SEG_FORA and nome in ("settings.json", "settings.local.json") and os.path.isfile(alvo)
            if rel_alvo is None:
                if permitido:
                    atalhos_copia.append(r)
                    fora_nomes.append(f"atalho para fora da pasta pessoal, foi o conteúdo (volta como pasta comum): {r}")
            else:
                atalhos_info.append(f"{r}|{rel_alvo}")
                vai_junto = (not NUVEM and not eh_settings and (rel_alvo == "claude" or rel_alvo.startswith("claude/"))
                             and not (SEM_CHATS and (rel_alvo == "claude/chats" or rel_alvo.startswith("claude/chats/"))))
                if vai_junto or not permitido:
                    if not permitido:
                        fora_topo.append(nome + " (atalho)")
                    continue
            if not permitido:
                fora_topo.append(nome)
                regra("pasta" if os.path.isdir(alvo) else "arquivo", r)
            elif os.path.isdir(alvo):
                incluir_pasta(r, alvo)
            elif eh_settings and (not NUVEM or nome == "settings.json"):
                limpar_settings(r, alvo)
            else:
                arquivo(r, alvo, nome, True, os.path.join(RAIZ, r))
            continue
        if os.path.isdir(p):
            if NUVEM and nome == "projects":
                regra("resto", r)
                fora_topo.append("projects (só a memória de cada projeto foi)")
                guardar_modo(r, p)
                for proj in sorted(os.listdir(p)):
                    m = os.path.join(p, proj, "memory")
                    if os.path.isdir(m) and not os.path.islink(m):
                        rm = f"{r}/{proj}/memory"
                        os.makedirs(os.path.join(RAIZ, r, proj), exist_ok=True)
                        guardar_modo(f"{r}/{proj}", os.path.join(p, proj))
                        incluir_pasta(rm, m)
                continue
            if NUVEM and nome not in PASTAS_NUVEM:
                dentro_dela = sorted(x for x in refs if x.startswith(nome + "/"))
                if dentro_dela:
                    regra("resto", r)
                    fora_topo.append(nome + " (só os arquivos que o settings.json usa foram)")
                    for x in dentro_dela:
                        arquivo(".claude/" + x, os.path.join(base, x), os.path.basename(x),
                                False, os.path.join(RAIZ, ".claude", x))
                else:
                    regra("pasta", r)
                    fora_topo.append(nome)
                continue
            if not NUVEM and SEG_FORA and nome == "backups":
                regra("pasta", r)
                fora_nomes.append(f"cópia de configuração: {r}")
                continue
            incluir_pasta(r, p)
        elif os.path.isfile(p):
            if SEG_FORA and nome in ("settings.json", "settings.local.json") and (not NUVEM or nome == "settings.json"):
                limpar_settings(r, p)
                continue
            if NUVEM and nome not in ARQUIVOS_NUVEM and nome not in refs:
                regra("arquivo", r)
                fora_topo.append(nome)
                continue
            arquivo(r, p, nome, True, os.path.join(RAIZ, r))

# ── ~/claude (projetos): só no backup local ──
base = os.path.join(HOME, "claude")
if not NUVEM and os.path.isdir(base):
    os.symlink(base, os.path.join(RAIZ, "claude"))
    guardar_modo("claude", base)
    percorrer("claude", base)

# O snapshot que está sendo criado agora, se o destino fica dentro das pastas do
# backup: ganha regra para o restore trazê-lo de volta da .anterior
SNAP = sys.argv[7]
real_snap = os.path.join(os.path.realpath(os.path.dirname(SNAP)), os.path.basename(SNAP))
for raiz_rel in (".claude", "claude"):
    raiz = os.path.realpath(os.path.join(HOME, raiz_rel))
    if dentro(real_snap, raiz) and real_snap != raiz:
        regra("arquivo", raiz_rel + "/" + os.path.relpath(real_snap, raiz))

# Arquivos citados no settings.json que não foram: recusados pela regra ou retirados por segurança
if NUVEM:
    for x, motivo in refs_recusados:
        refs_fora.append(f".claude/{x} ({motivo})")
    for x in sorted(refs):
        if ".claude/" + x not in adicionados:
            refs_fora.append(f".claude/{x} (retirado por segurança ou não encontrado)")

# Atalhos internos que apontam para fora do que foi no backup
for rel, p in cand_atalhos:
    t = os.path.realpath(p)
    if not (t in arquivos_reais or any(dentro(t, r) for r in raizes_reais)):
        try:
            atalhos_fora.append(rel + " -> " + os.readlink(p))
        except OSError:
            atalhos_fora.append(rel)

lista.close(); regras.close()

def gravar(nome, linhas):
    with open(os.path.join(WORK, nome), "w", encoding="utf-8", errors="surrogateescape") as f:
        for l in linhas:
            f.write(l + "\n")

gravar("fatal", fatal)
gravar("fora_topo", fora_topo)
gravar("fora_nomes", fora_nomes)
gravar("atalhos_info", atalhos_info)
gravar("atalhos_copia", atalhos_copia)
gravar("modos", modos)
gravar("atalhos_fora", atalhos_fora)
gravar("refs_fora", refs_fora)
gravar("settings_msgs", settings_msgs)
gravar("sumidos", [str(sumidos[0])])
PY
then
  error "Não consegui separar os arquivos do backup (erro no python3). Nenhum snapshot foi criado."
fi

if [[ -s "$TMP_WORK/fatal" ]]; then
  echo ""
  warn "Não consegui ler estes caminhos (sem permissão ou erro de leitura):"
  sed 's/^/      • /' "$TMP_WORK/fatal" | head -40
  error "Backup interrompido para não sair incompleto. Corrija as permissões e rode de novo. Nenhum snapshot foi criado."
fi

# Informação usada pelo restore.sh (não é restaurada para as pastas)
if $DEST_IS_CLOUD; then DEST_LABEL="nuvem"; else DEST_LABEL="local"; fi
if $INCLUDE_SECRETS && ! $DEST_IS_CLOUD; then SECRETS_LABEL="sim"; else SECRETS_LABEL="nao"; fi
{
  printf 'destino=%s\nsegredos=%s\ndata=%s\nversao=1.2.0\n' "$DEST_LABEL" "$SECRETS_LABEL" "$TIMESTAMP"
  sed 's/^/atalho=/' "$TMP_WORK/atalhos_info"
  sed 's/^/atalho_fora=/' "$TMP_WORK/atalhos_copia"
  sed 's/^/modo=/' "$TMP_WORK/modos"
} > "$RAIZ/claude-code-backup-info.txt"
cp "$TMP_WORK/regras" "$RAIZ/claude-code-backup-excluidos.txt"
printf '%s\0' "claude-code-backup-info.txt" "claude-code-backup-excluidos.txt" >> "$TMP_WORK/lista"

info "Comprimindo arquivos..."

TAR_SUMIDOS=0
if ! LC_ALL=C tar --no-recursion -czf "$SNAPSHOT_PATH" -C "$RAIZ" --null -T "$TMP_WORK/lista" 2>"$TAR_LOG"; then
  # Arquivo que sumiu ou mudou durante a leitura (normal com o Claude Code aberto) não derruba o backup.
  RUINS="$(grep -v -e 'Error exit delayed from previous errors' \
                   -e 'Exiting with failure status due to previous errors' \
                   -e 'No such file or directory' \
                   -e 'file changed as we read it' \
                   -e 'File removed before we read it' \
                   -e 'File shrank by' "$TAR_LOG" || true)"
  if [[ -s "$TAR_LOG" && -z "$RUINS" ]]; then
    TAR_SUMIDOS="$(grep -c -e 'No such file or directory' -e 'file changed as we read it' -e 'File removed before we read it' -e 'File shrank by' "$TAR_LOG" || true)"
  else
    rm -f "$SNAPSHOT_PATH"
    tail -5 "$TAR_LOG" >&2 || true
    error "Falha ao criar snapshot — verifique permissões e espaço em: $DEST_PATH"
  fi
fi

if LC_ALL=C tar -tzf "$SNAPSHOT_PATH" &>/dev/null; then
  FINAL_SIZE="$(du -sh "$SNAPSHOT_PATH" 2>/dev/null | cut -f1 || echo '?')"
  ok "Snapshot criado e verificado: $SNAPSHOT_NAME (${FINAL_SIZE})"
else
  rm -f "$SNAPSHOT_PATH"
  error "Snapshot criado mas corrompido — verifique espaço em disco em: $DEST_PATH"
fi

SUMIDOS=$(( $(cat "$TMP_WORK/sumidos") + TAR_SUMIDOS ))
[[ $SUMIDOS -gt 0 ]] && \
  warn "$SUMIDOS arquivo(s) mudaram ou sumiram durante o backup (normal com o Claude Code aberto)."

# ── O que ficou de fora ──────────────────────────────────────────────────────
mostrar_lista() {  # mostrar_lista <arquivo> <título>
  local n; n="$(wc -l < "$1" | tr -d ' ')"
  [[ "$n" -gt 0 ]] || return 0
  echo ""
  echo -e "${BOLD}$2 ($n):${RESET}"
  head -40 "$1" | sed 's/^/      • /'
  [[ "$n" -gt 40 ]] && echo "      … e mais $(( n - 40 ))"
  return 0
}

section "O que ficou de fora"
if $DEST_IS_CLOUD; then
  echo -e "${BOLD}Os projetos (~/claude) não vão para a nuvem.${RESET} Para levá-los, use pendrive, pasta local ou o GitHub."
  mostrar_lista "$TMP_WORK/fora_topo" "Itens de ~/.claude que ficaram na máquina"
fi
mostrar_lista "$TMP_WORK/fora_nomes" "Arquivos retirados por segurança (só os nomes)"
mostrar_lista "$TMP_WORK/settings_msgs" "Ajustes no settings"
if [[ -s "$TMP_WORK/refs_fora" ]]; then
  mostrar_lista "$TMP_WORK/refs_fora" "O settings.json usa estes arquivos, que não puderam ir"
fi
$DEST_IS_CLOUD && info "Scripts chamados por outros scripts não foram conferidos."
mostrar_lista "$TMP_WORK/atalhos_fora" "Atalhos que apontam para fora do backup (ficam quebrados se o destino não existir)"
[[ -s "$TMP_WORK/fora_nomes" || -s "$TMP_WORK/fora_topo" ]] && \
  info "O restore.sh traz de volta o que ficou de fora quando você restaurar nesta mesma máquina."

# ── Aviso final para destinos em nuvem ───────────────────────────────────────
if $DEST_IS_CLOUD; then
  echo ""
  echo -e "${BOLD}Na nuvem foram só as configurações do Claude Code. Ficaram na sua máquina: os projetos (~/claude), login, histórico e textos das conversas, senhas (.env), chaves e tokens. Pra levar tudo, use pendrive ou pasta local.${RESET}"

  echo ""
  echo -e "${BOLD}${YELLOW}"
  cat << SYNC_WARN
╔══════════════════════════════════════════════════════════════╗
║  ⚠  ESTE BACKUP TEM SÓ AS CONFIGURAÇÕES                      ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Login, histórico e senhas ficaram fora (de propósito).      ║
║  NÃO formate a máquina contando só com este backup:          ║
║  para trocar de máquina, faça também um backup em            ║
║  pendrive ou pasta local (opção 1 do menu).                  ║
║                                                              ║
║  O upload acontece em segundo plano. Confira que subiu:      ║
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
$(if $DEST_IS_CLOUD; then
  echo "  1. Confirme o upload na nuvem"
  echo "  2. Este backup tem só as configurações. Para trocar de máquina,"
  echo "     faça também um backup em pendrive ou pasta local"
  echo "  3. Na máquina nova, instale o Claude Code: ${BLUE}https://claude.ai/code${RESET}"
  echo "  4. Restaure com: ${BLUE}bash restore.sh${RESET}"
else
  echo "  1. Guarde o arquivo em local seguro"
  echo "  2. Formate a máquina"
  echo "  3. Instale o Claude Code: ${BLUE}https://claude.ai/code${RESET}"
  echo "  4. Restaure com: ${BLUE}bash restore.sh${RESET}"
fi)

${BOLD}by Tadeu Rosa — CC BY-NC-ND 4.0${RESET}
"
