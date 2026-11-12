---
name: backlog
description: "Captura ideias e tarefas sem sair do fluxo."
metadata:
  origem: claude-code-setup
---
# /backlog — Salvar no Backlog

Captura ideias e tarefas sem sair do fluxo.

## O que faz

Salva o item no arquivo `~/claude/projetos/backlog.md` com data, contexto e prioridade sugerida.

## Uso

```
/backlog adicionar autenticação com Google
/backlog fix: botão não funciona no mobile
/backlog ideia: integrar com Notion
/backlog urgent: cliente pediu relatório PDF
```

## Prefixos reconhecidos

| Prefixo | Prioridade | Quando usar |
|---------|-----------|-------------|
| `urgent:` | 🔴 Alta | Cliente pediu, bloqueia algo |
| `fix:` | 🟠 Média | Bug conhecido, não crítico |
| `feat:` | 🟡 Normal | Nova funcionalidade |
| `ideia:` | 🟢 Baixa | Para avaliar depois |

## Formato salvo

```markdown
- [ ] 🔴 [2026-04-17] urgent: cliente pediu relatório PDF
- [ ] 🟡 [2026-04-17] adicionar autenticação com Google
```

## Dica

Use `/daily` para revisar o backlog e decidir o que entra no dia. O par `/backlog` + `/daily` é a base de um sistema simples de gestão pessoal.

---
*Claude Code Setup — by Tadeu Rosa · CC BY 4.0*
