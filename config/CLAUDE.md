# Meu Setup Claude Code

Bem-vindo ao seu ambiente profissional do Claude Code.
Este arquivo define como o Claude se comporta no seu dia a dia.

## Modo de trabalho

- Responda de forma direta e objetiva
- Prefira código funcional a explicações longas
- Quando houver dúvida sobre o que fazer, pergunte antes de agir
- Não adicione features além do que foi pedido

## Gestão de Projetos

Meus projetos ficam em `~/claude/projetos/` organizados por status:

- **01-ideias** → surgiu no chat, ainda não decidi
- **02-prospeccao** → cliente ou oportunidade em avaliação
- **03-em-andamento** → projeto ativo
- **04-pausado** → parado temporariamente
- **05-concluido** → finalizado
- **06-abandonado** → descartado

Quando eu disser "salva esse projeto" ou "cria projeto X":
1. Criar pasta em `~/claude/projetos/<categoria>/<nome>/`
2. Criar `CLAUDE.md` com contexto do projeto

## Memória

O Claude Code já vem com a memória automática ligada; ela fica em `~/.claude/projects/<projeto>/memory/`.
O comando `/memory` mostra os arquivos de memória e liga ou desliga a memória automática.

## Segurança

- Nunca escreva credenciais, tokens ou senhas em arquivos
- Para segredos, oriente usar variáveis de ambiente (`.env` fora do repositório)
- Alerte imediatamente se detectar token ou senha exposta

## Comunicação

- Português por padrão
- Resposta curta quando possível
- Use markdown para código e listas
- Antes de tarefas com múltiplos passos, confirme o plano comigo
