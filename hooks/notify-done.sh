#!/usr/bin/env bash
# notify-done.sh — Notificação macOS quando Claude termina uma tarefa longa
# Instalado pelo Claude Code Setup PRO — by Tadeu Rosa · CC BY-NC-ND 4.0

# Só roda no macOS
[[ "$(uname -s)" == "Darwin" ]] || exit 0

# Lê o resultado do hook (passado via stdin como JSON)
input="$(cat)"

# Extrai duração e tipo de evento
duration="$(echo "$input" | python3 -c "
import json,sys
d = json.load(sys.stdin)
print(d.get('duration_ms', 0) // 1000)
" 2>/dev/null || echo 0)"

# Só notifica se a tarefa demorou mais de 10 segundos
[[ "$duration" -lt 10 ]] && exit 0

osascript -e "display notification \"Tarefa concluída em ${duration}s\" with title \"Claude Code\" sound name \"Glass\"" 2>/dev/null || true
