# /daily — Resumo do Dia

Gera um resumo estruturado do dia de trabalho.

## O que faz

1. Lista projetos com atividade recente (últimas 24h)
2. Mostra tarefas abertas por projeto
3. Compara com o planejado ontem (se houver contexto)
4. Sugere próximos passos baseado no contexto

## Uso

```
/daily
/daily manhã     ← planejamento do dia (começo)
/daily tarde     ← revisão e ajuste de prioridades
/daily fim       ← fechamento e handoff para amanhã
```

## Saída esperada

```
## Daily — [data]

### Projetos ativos
- [projeto]: [status atual]

### Tarefas abertas
- [ ] item 1
- [ ] item 2

### Concluído hoje
- [x] item concluído

### Próximos passos
1. ...
```

## Dica PRO

Use `/daily fim` antes de fechar o computador — o Claude gera o contexto do dia para você não perder o fio amanhã.

---
*Claude Code Setup PRO — by Tadeu Rosa · CC BY-NC-ND 4.0*
