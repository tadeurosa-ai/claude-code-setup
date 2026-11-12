#!/usr/bin/env bash
# lib/skills-comum.sh — funções das skills usadas pelo install.sh e pelo repair.sh
# (um lugar só: o que muda aqui vale para os dois). Não é para rodar sozinho.
# by Tadeu Rosa · MIT (arquivo LICENSE)

# Nomes reais (como estão gravados no disco) dos arquivos de skill da pasta: SKILL.md
# e/ou o skill.md antigo. Em ordem fixa, que não depende do idioma do sistema.
nomes_skill() {
  local f
  for f in "$1"/*; do
    [[ -f "$f" ]] || continue
    case "$(basename "$f" | LC_ALL=C tr '[:upper:]' '[:lower:]')" in
      skill.md) basename "$f" ;;
    esac
  done | LC_ALL=C sort
}

# O arquivo que vale: SKILL.md com esse nome exato, se existir; senão o antigo
arquivo_skill() {
  local n
  n="$(nomes_skill "$1")"
  [[ -n "$n" ]] || return 1
  if printf '%s\n' "$n" | grep -qx 'SKILL.md'; then
    printf '%s/SKILL.md' "$1"
  else
    printf '%s/%s' "$1" "$(printf '%s\n' "$n" | head -1)"
  fi
}

# O OUTRO nome, quando a pasta tem os dois (só acontece em disco que diferencia maiúscula)
nome_sobrando() {
  local n
  n="$(nomes_skill "$1")"
  printf '%s\n' "$n" | grep -qx 'SKILL.md' || return 1
  n="$(printf '%s\n' "$n" | grep -vx 'SKILL.md' | grep -v '^$' | head -1)"
  [[ -n "$n" ]] || return 1
  printf '%s' "$n"
}

# Skill instalada por este pacote: marca no frontmatter, ou um dos 3 rodapés — o PRO e o Lite das
# versões antigas e o atual — e o rodapé só conta quando é a última linha COM TEXTO do arquivo (PRO
# pelo trecho; Lite e atual pelo texto exato). Rodapé citado no meio do texto não marca nada.
do_pacote() {
  local ult
  grep -q '^  origem: claude-code-setup$' "$1" 2>/dev/null && return 0
  ult="$(awk 'NF { l = $0 } END { print l }' "$1" 2>/dev/null)" || return 1   # última linha COM TEXTO
  case "$ult" in *'Claude Code Setup PRO — by Tadeu Rosa'*) return 0 ;; esac
  [[ "$ult" == '*Claude Code Setup Lite — by Tadeu Rosa · CC BY-NC-ND 4.0*' ||
     "$ult" == '*Claude Code Setup — by Tadeu Rosa · CC BY 4.0*' ]]
}

# Rodapé do pacote como linha inteira, mas que NÃO é a última linha com texto: parece skill
# do pacote editada depois do rodapé. O instalador não mexe; só avisa (o repair.sh também).
rodape_no_meio() {
  do_pacote "$1" && return 1
  LC_ALL=C grep -qxF -e '*Claude Code Setup PRO — by Tadeu Rosa · CC BY-NC-ND 4.0*' \
    -e '*Claude Code Setup Lite — by Tadeu Rosa · CC BY-NC-ND 4.0*' \
    -e '*Claude Code Setup — by Tadeu Rosa · CC BY 4.0*' "$1" 2>/dev/null
}

# Pasta com skill.md e SKILL.md juntos (só em disco que diferencia maiúscula).
# Nunca mexe em arquivo do usuário:
#  • skill.md do pacote + SKILL.md com conteúdo → guardar o skill.md;
#  • skill.md do pacote com conteúdo + SKILL.md vazio, numa das 11 pastas do pacote →
#    renomear (o vazio é guardado e o skill.md vira SKILL.md: o que estava nele continua em uso);
#  • qualquer outro caso → manter (nada muda).
acao_dois_nomes() {  # acao_dois_nomes <pasta> <pasta do pacote: sim|nao> <outro nome>
  if do_pacote "$1/$3"; then
    if [[ -s "$1/SKILL.md" ]]; then echo guardar; return 0; fi
    if [[ "$2" == sim && -s "$1/$3" ]]; then echo renomear; return 0; fi
  fi
  echo manter
}
