---
name: contexto-projeto
description: "Salva o estado atual do projeto para retomar em uma nova sessão sem perder o fio."
metadata:
  origem: claude-code-setup
---
# /contexto-projeto — Captura de Contexto do Projeto

Salva o estado atual do projeto para retomar em uma nova sessão sem perder o fio.

## O que faz

Gera e salva um arquivo de contexto com:
- Objetivo do projeto
- Estado atual (o que está feito, o que está em aberto)
- Decisões técnicas tomadas (e por quê)
- Próximos passos concretos
- Arquivos e pontos de atenção

## Uso

```
/contexto-projeto              ← salva contexto do projeto atual
/contexto-projeto carregar     ← carrega o contexto salvo na sessão atual
/contexto-projeto mostrar      ← exibe o contexto sem salvar
```

## Onde é salvo

`~/claude/projetos/[projeto]/context.md`

## Formato

```
# Contexto — [projeto] — [data]

## Objetivo
[O que estamos construindo e para quem]

## Estado atual
- ✅ Feito: [lista]
- 🔄 Em andamento: [lista]
- ⏳ Pendente: [lista]

## Decisões técnicas
- [decisão]: [motivo]

## Próximos passos
1. [próximo passo concreto]
2. [próximo passo]

## Atenção
- [arquivo ou detalhe crítico para não esquecer]
```

## Dica

Use `/contexto-projeto` no final de cada sessão longa. Na próxima sessão, comece com `/contexto-projeto carregar` — o Claude retoma exatamente de onde parou.

---
*Claude Code Setup — by Tadeu Rosa · CC BY 4.0*
